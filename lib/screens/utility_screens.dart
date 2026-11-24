import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/safepark_store.dart';
import '../utils/theme_constants.dart';

class EmergencyView extends StatelessWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final void Function(String msg) onToast;

  const EmergencyView({super.key, required this.store, required this.pal, required this.onToast});

  static const _guideEn = [
    '1. Move to a safe place and switch on your hazard lights.',
    '2. Call emergency services if anyone is hurt.',
    '3. Take photos and exchange details with the other driver.',
    '4. Never leave the scene of an accident.',
    '5. Smoke or fuel smell: get far away from the car first.',
  ];

  static const _guideAr = [
    '١. انتقل إلى مكان آمن وشغّل أضواء التحذير.',
    '٢. اتصل بالطوارئ إذا أصيب أحد.',
    '٣. صوّر الحادث وتبادل البيانات مع السائق الآخر.',
    '٤. لا تغادر مكان الحادث أبداً.',
    '٥. عند الدخان أو رائحة الوقود ابتعد عن السيارة أولاً.',
  ];

  Future<void> _callNumber(String raw) async {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return onToast('No number set');
    onToast('Calling $raw');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final ar = store.arabic;
    final guide = ar ? _guideAr : _guideEn;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: const Color(0xFFD9857B)),
          const SizedBox(height: 12),
          Text(tr('emergency', ar, 'Emergency'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('Tap a number to call', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: store.emergencyContacts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, i) {
              final e = store.emergencyContacts[i];
              final accent = kPalettes[i % 4].pri;
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _callNumber(e.number),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.phone_in_talk, color: accent),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name.isEmpty ? 'Unnamed' : e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(e.number, style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: accent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(ar ? 'دليل الطوارئ (يعمل دون إنترنت)' : 'Offline emergency guide', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(children: guide.map((line) => ListTile(dense: true, title: Text(line, style: const TextStyle(fontSize: 14)))).toList()),
          ),
        ],
      ),
    );
  }
}

class NearbyView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final void Function(String msg) onToast;

  const NearbyView({super.key, required this.store, required this.pal, required this.onToast});

  @override
  State<NearbyView> createState() => _NearbyViewState();
}

class _NearbyViewState extends State<NearbyView> {
  Position? _pos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)));
      if (mounted) {
        setState(() {
          _pos = p;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMaps(String query) async {
    widget.onToast('Opening Google Maps…');
    final enc = Uri.encodeComponent(query);
    final uri = _pos != null
        ? Uri.parse('https://www.google.com/maps/search/$enc/@${_pos!.latitude},${_pos!.longitude},15z')
        : Uri.parse('https://www.google.com/maps/search/$enc');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final items = _pos != null
        ? const [
            ('Parking Garage', 'parking'),
            ('Gas Station', 'gas station'),
            ('Car Mechanic', 'car mechanic'),
            ('Towing Service', 'tow truck'),
            ('EV Charging', 'ev charging station'),
            ('Car Wash', 'car wash'),
          ]
        : s.nearbyPlaces.map((p) => (p.isEmpty ? 'Unnamed' : p, p)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('nearby', s.arabic, 'Nearby'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text(
            _loading
                ? 'Detecting current location...'
                : (_pos != null ? 'Location loaded · tap a category to search on Google Maps' : 'Showing saved places on Google Maps'),
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, i) {
              final (label, query) = items[i];
              final accent = kPalettes[i % 4].pri;
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openMaps(query),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.location_on, color: accent),
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PricingView extends StatelessWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final void Function(String msg) onToast;

  const PricingView({super.key, required this.store, required this.pal, required this.onToast});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final email = s.currentUser?['email']?.toString();
    final currentPlan = email != null ? s.userPlans[email] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('pricing', s.arabic, 'Pricing'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('Choose the plan that fits you', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
          const SizedBox(height: 12),
          ...s.plans.map((p) {
            final isCurrent = currentPlan == p.name;
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: p.highlight ? pal.pri : Theme.of(context).dividerColor, width: p.highlight ? 2 : 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (p.highlight)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: pal.pri, borderRadius: BorderRadius.circular(999)),
                            child: const Text('Popular', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(p.price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        if (p.period.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(p.period, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final f in p.features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 18, color: pal.pri),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: pal.pri),
                        onPressed: isCurrent
                            ? null
                            : () {
                                if (email == null) return onToast('Please log in first');
                                s.userPlans[email] = p.name;
                                s.persist();
                                onToast('Plan selected: ${p.name}');
                              },
                        child: Text(isCurrent ? '✓ Current plan' : 'Choose ${p.name}'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Text('Demo build: no real payment is taken.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
        ],
      ),
    );
  }
}
