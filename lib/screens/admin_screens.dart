import 'package:flutter/material.dart';
import '../models/safepark_models.dart';
import '../services/safepark_store.dart';
import '../utils/theme_constants.dart';

class AdminLoginView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final VoidCallback onBackToDriver;
  final VoidCallback onSuccess;

  const AdminLoginView({
    super.key,
    required this.store,
    required this.pal,
    required this.onBackToDriver,
    required this.onSuccess,
  });

  @override
  State<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<AdminLoginView> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _err = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final e = _emailCtrl.text.trim().toLowerCase();
    final p = _passCtrl.text;
    if (e == 'admin@uni.edu' && p == 'admin123') {
      _emailCtrl.clear();
      _passCtrl.clear();
      setState(() => _err = '');
      widget.onSuccess();
    } else {
      setState(() => _err = 'Wrong email or password. Check the demo access below.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 46, 24, 36),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.pal.priDark, widget.pal.pri])),
            child: Column(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.white, size: 42),
                const SizedBox(height: 8),
                const Text('Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Manage reports and users.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Admin login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('For university staff only.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                const SizedBox(height: 14),
                TextField(controller: _emailCtrl, decoration: InputDecoration(hintText: 'Admin email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 12),
                TextField(controller: _passCtrl, obscureText: true, onSubmitted: (_) => _submit(), decoration: InputDecoration(hintText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)))),
                if (_err.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_err, style: const TextStyle(color: Color(0xFFB5574D), fontSize: 13)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: widget.pal.pri, minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                  onPressed: _submit,
                  child: const Text('Log in as admin'),
                ),
                TextButton(onPressed: widget.onBackToDriver, child: const Text('← Back to driver login')),
                Text('Demo access: admin@uni.edu / admin123', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final VoidCallback onLeave;
  final void Function(String msg) onToast;

  const AdminDashboardView({
    super.key,
    required this.store,
    required this.pal,
    required this.onLeave,
    required this.onToast,
  });

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  late TextEditingController _nameCtrl;
  late TextEditingController _tagCtrl;
  late TextEditingController _bannerCtrl;
  List<String> _hotspots = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.store.appName);
    _tagCtrl = TextEditingController(text: widget.store.tagline);
    _bannerCtrl = TextEditingController(text: widget.store.bannerTitle);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _computeHotspots() {
    final counts = <String, int>{};
    for (final r in widget.store.reports) {
      if (r.loc.trim().isNotEmpty) counts[r.loc.trim()] = (counts[r.loc.trim()] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    setState(() {
      _hotspots = sorted.take(3).map((e) => '${e.key}: ${e.value} report${e.value > 1 ? 's' : ''}').toList();
      if (_hotspots.isEmpty) _hotspots = ['No locations tagged yet.'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final openCount = s.reports.where((r) => r.status == 'open').length;
    final resolvedCount = s.reports.where((r) => r.status == 'resolved').length;
    final blockedUsers = s.reports.where((r) => r.status == 'blocked').map((r) => r.user).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 46, 18, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Edit the app', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('You can change how the app looks. Changes show to drivers right away.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatBox(label: 'Open', value: '$openCount')),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: 'Resolved', value: '$resolvedCount')),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: 'Blocked users', value: '$blockedUsers')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => widget.onToast('CSV prepared (${s.reports.length} rows)'), child: const Text('Export CSV'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: _computeHotspots, child: const Text('Hotspots'))),
            ],
          ),
          if (_hotspots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hotspots', style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final h in _hotspots) Text(h, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('REPORTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ...s.reports.map((r) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${r.car}: ${r.kind}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Text(r.status, style: TextStyle(color: widget.pal.pri, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      Text(r.user, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(r.text),
                      if (r.status == 'open') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: widget.pal.pri),
                                onPressed: () { r.status = 'resolved'; s.persist(); setState(() {}); },
                                child: const Text('Mark resolved'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  for (final x in s.reports) {
                                    if (x.user == r.user) x.status = 'blocked';
                                  }
                                  s.persist();
                                  setState(() {});
                                },
                                child: const Text('Block user'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 16),
          const Text('BRANDING & ACCENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'App name', border: OutlineInputBorder()), onChanged: (v) { s.appName = v.trim().isEmpty ? 'SafePark' : v.trim(); s.persist(); }),
          const SizedBox(height: 10),
          TextField(controller: _tagCtrl, decoration: const InputDecoration(labelText: 'Tagline', border: OutlineInputBorder()), onChanged: (v) { s.tagline = v.trim(); s.persist(); }),
          const SizedBox(height: 10),
          TextField(controller: _bannerCtrl, decoration: const InputDecoration(labelText: 'Banner title', border: OutlineInputBorder()), onChanged: (v) { s.bannerTitle = v.trim(); s.persist(); }),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: List.generate(kPalettes.length, (i) {
              final p = kPalettes[i];
              return GestureDetector(
                onTap: () { s.paletteIndex = i; s.persist(); },
                child: CircleAvatar(radius: 18, backgroundColor: p.pri, child: s.paletteIndex == i ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
              );
            }),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              s.appName = 'SafePark';
              s.tagline = 'Reach the car owner. No phone calls.';
              s.bannerTitle = 'Blocked in? Lights left on?';
              s.paletteIndex = 0;
              s.emergencyContacts = [EmergencyContact(name: 'Police', number: '122'), EmergencyContact(name: 'Ambulance', number: '123')];
              s.nearbyPlaces = ['Gas station', 'Car mechanic', 'Parking', 'Tow truck'];
              s.plans = SafeParkStore.defaultPlans();
              _nameCtrl.text = s.appName;
              _tagCtrl.text = s.tagline;
              _bannerCtrl.text = s.bannerTitle;
              s.persist();
              widget.onToast('Back to the default design');
            },
            child: const Text('Reset to default'),
          ),
          TextButton(onPressed: widget.onLeave, child: const Text('← Leave admin')),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}
