import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/safepark_models.dart';
import '../services/safepark_store.dart';
import '../utils/theme_constants.dart';

class SettingsView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final VoidCallback onBackToApp;
  final VoidCallback onLoggedOut;
  final void Function(String msg) onToast;

  const SettingsView({
    super.key,
    required this.store,
    required this.pal,
    required this.onBackToApp,
    required this.onLoggedOut,
    required this.onToast,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _plateCtrl = TextEditingController();
  bool _showPrivacy = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  String _makeCarCode(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (cleaned.isNotEmpty) return cleaned.substring(0, min(20, cleaned.length));
    return 'SP-${Random().nextInt(9999).toString().padLeft(4, '0')}';
  }

  void _addCar() {
    final email = widget.store.currentUser?['email']?.toString();
    if (email == null) return;
    final plate = _plateCtrl.text.trim();
    if (plate.isEmpty) return widget.onToast('Enter your plate number');
    final code = _makeCarCode(plate);
    if (widget.store.cars.any((c) => c.code == code)) return widget.onToast('That plate is already registered');
    widget.store.cars.add(RegisteredCar(owner: email, name: plate, code: code));
    widget.store.persist();
    _plateCtrl.clear();
    setState(() {});
    widget.onToast('Car added: $code');
  }

  void _confirmDialog(String title, String body, VoidCallback onConfirm, {bool danger = false}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(widget.store.arabic ? 'لا' : 'No')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFD9534F)) : null,
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(widget.store.arabic ? 'نعم' : 'Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final me = s.currentUser;
    final email = me?['email']?.toString();
    final myCars = email == null ? <RegisteredCar>[] : s.cars.where((c) => c.owner == email).toList();
    final backup = email != null ? (s.backupContacts[email] ?? '') : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(onPressed: widget.onBackToApp, icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 4),
              Text(tr('settings', s.arabic, 'Settings'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(
            me != null
                ? '${me['name']} · $email · ${s.isVerifiedStudent(me) ? 'Verified student' : (me['role'] == 'student' ? 'Student' : 'Guest')}'
                : 'Not logged in',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text('LOOK & FEEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Card(
            child: Column(
              children: [
                SwitchListTile(title: const Text('Dark mode'), value: s.darkMode, onChanged: (v) { s.darkMode = v; s.persist(); }),
                ListTile(
                  title: const Text('Language · اللغة'),
                  trailing: SegmentedButton<bool>(
                    segments: const [ButtonSegment(value: false, label: Text('EN')), ButtonSegment(value: true, label: Text('عربي'))],
                    selected: {s.arabic},
                    onSelectionChanged: (set) { s.arabic = set.first; s.persist(); },
                  ),
                ),
                SwitchListTile(title: const Text('Haptics'), value: s.haptics, onChanged: (v) { s.haptics = v; s.persist(); }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('MY CARS & QR STICKERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (myCars.isEmpty) Text('No cars yet.', style: TextStyle(color: Theme.of(context).hintColor)),
                  for (final c in myCars) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(c.code),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFB5574D)),
                        onPressed: () { s.cars.remove(c); s.persist(); setState(() {}); },
                      ),
                    ),
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(data: 'https://safepark.app/#car-${c.code}', size: 150),
                      ),
                    ),
                    const Divider(),
                  ],
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _plateCtrl, decoration: const InputDecoration(hintText: 'Plate number'), onChanged: (_) => setState(() {}))),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _addCar, child: const Text('Add')),
                    ],
                  ),
                  if (_plateCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Preview code: ${_makeCarCode(_plateCtrl.text.trim())}'),
                  ],
                ],
              ),
            ),
          ),
          if (email != null) ...[
            const SizedBox(height: 14),
            const Text('IF I DON’T REPLY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Repeat after (min)'),
                        DropdownButton<int>(
                          value: s.escalateMinutes,
                          items: [1, 3, 5, 10, 15, 30].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                          onChanged: (v) { if (v != null) { s.escalateMinutes = v; s.persist(); } },
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: backup,
                      decoration: const InputDecoration(labelText: 'Backup contact email', hintText: 'friend@mail.com'),
                      onChanged: (v) { s.backupContacts[email] = v.trim().toLowerCase(); s.persist(); },
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text('PRIVACY & DATA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Terms & Privacy'),
                  trailing: Icon(_showPrivacy ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() => _showPrivacy = !_showPrivacy),
                ),
                if (_showPrivacy)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text('Reporters never see owner details, and owners never see who reported. Only admins can see report emails.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                  ),
                if (email != null)
                  ListTile(
                    title: const Text('Delete my account', style: TextStyle(color: Color(0xFFB5574D))),
                    onTap: () => _confirmDialog(
                      'Delete account',
                      'Are you sure you want to delete your account?',
                      () {
                        s.users.removeWhere((u) => u['email'] == email);
                        s.cars.removeWhere((c) => c.owner == email);
                        s.alerts.removeWhere((a) => a.to == email);
                        s.currentUser = null;
                        s.persist();
                        widget.onLoggedOut();
                      },
                      danger: true,
                    ),
                  ),
                ListTile(
                  title: const Text('Reset all app data', style: TextStyle(color: Color(0xFFB5574D))),
                  onTap: () => _confirmDialog(
                    'Reset data',
                    'Are you sure you want to reset data? Everything will be erased.',
                    () async { await s.resetAllData(); widget.onLoggedOut(); },
                    danger: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.pal.pri, minimumSize: const Size.fromHeight(48)),
            onPressed: () => _confirmDialog('Log out', 'Are you sure you want to log out?', () { s.currentUser = null; s.persist(); widget.onLoggedOut(); }),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
