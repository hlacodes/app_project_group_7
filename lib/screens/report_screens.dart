import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/safepark_models.dart';
import '../services/safepark_store.dart';
import '../utils/theme_constants.dart';

class ReportView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final void Function(String code) onContinueCode;
  final void Function(String msg) onToast;

  const ReportView({
    super.key,
    required this.store,
    required this.pal,
    required this.onContinueCode,
    required this.onToast,
  });

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final _codeCtrl = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String _extractCode(String raw) {
    final match = RegExp(r'#car-([A-Za-z0-9-]+)', caseSensitive: false).firstMatch(raw);
    if (match != null) return match.group(1)!;
    final parts = raw.trim().split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.last;
  }

  void _submitCode() {
    final cleaned = _codeCtrl.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    final code = cleaned.isEmpty ? 'CAR-1234' : cleaned;
    if (cleaned.isNotEmpty) {
      widget.store.recentCodes.remove(code);
      widget.store.recentCodes.insert(0, code);
      if (widget.store.recentCodes.length > 4) {
        widget.store.recentCodes = widget.store.recentCodes.take(4).toList();
      }
      widget.store.persist();
    }
    widget.onContinueCode(code);
  }

  Future<void> _saveParkedSpot() async {
    widget.onToast('Saving your spot…');
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        widget.onToast('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)));
      widget.store.parkedSpot = {'lat': pos.latitude, 'lon': pos.longitude, 't': DateTime.now().millisecondsSinceEpoch};
      await widget.store.persist();
      widget.onToast('Parking spot saved');
    } catch (_) {
      widget.onToast('Could not get location');
    }
  }

  Future<void> _openSpotDirections() async {
    final sp = widget.store.parkedSpot;
    if (sp == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${sp['lat']},${sp['lon']}&travelmode=walking');
    widget.onToast('Opening Google Maps…');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final firstName = (s.currentUser?['name'] ?? '').toString().split(' ').first;
    final hr = DateTime.now().hour;
    final greeting = hr < 12 ? 'Good morning' : (hr < 18 ? 'Good afternoon' : 'Good evening');
    final subText = firstName.isNotEmpty ? '$greeting, $firstName. Alert an owner in one tap' : 'Alert the owner in one tap';
    final extraChips = ['DEMO-001', ...s.recentCodes.where((c) => c != 'DEMO-001')];
    final spot = s.parkedSpot;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('report_car', s.arabic, 'Report a car'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subText, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: const BorderSide(color: Color(0xFFE8A88C), width: 4),
                top: BorderSide(color: Theme.of(context).dividerColor),
                right: BorderSide(color: Theme.of(context).dividerColor),
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.bannerTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Scan the sticker on the windshield and the owner is notified instantly.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: widget.pal.pri, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => setState(() => _scanning = !_scanning),
                    child: Text(_scanning ? 'Stop scanner' : 'Scan a QR code'),
                  ),
                ),
              ],
            ),
          ),
          if (_scanning) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: MobileScanner(
                  onDetect: (capture) {
                    final raw = capture.barcodes.firstOrNull?.rawValue;
                    if (raw == null) return;
                    final code = _extractCode(raw).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
                    if (code.isNotEmpty) {
                      setState(() {
                        _scanning = false;
                        _codeCtrl.text = code.substring(0, min(20, code.length));
                      });
                      _submitCode();
                    }
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR ENTER THE CODE', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11, letterSpacing: 0.6)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _submitCode(),
            decoration: InputDecoration(prefixText: '# ', hintText: 'Car code (try DEMO-001)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: extraChips.map((c) {
              return OutlinedButton(
                style: OutlinedButton.styleFrom(side: BorderSide(color: widget.pal.pri), shape: const StadiumBorder()),
                onPressed: () {
                  _codeCtrl.text = c;
                  _submitCode();
                },
                child: Text(c == 'DEMO-001' ? 'Try DEMO-001' : c, style: TextStyle(color: widget.pal.pri, fontSize: 12)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.pal.pri, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _submitCode,
            child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFFBF7D54),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: spot != null ? _openSpotDirections : _saveParkedSpot,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.local_parking, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spot != null ? 'Find my car' : 'I parked here', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            spot != null ? 'Saved spot · opens Google Maps walking route' : 'Save your spot so you never lose your car',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProblemView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final String carCode;
  final VoidCallback onBack;
  final void Function(bool notifiedOwner) onSent;
  final void Function(String msg) onToast;

  const ProblemView({
    super.key,
    required this.store,
    required this.pal,
    required this.carCode,
    required this.onBack,
    required this.onSent,
    required this.onToast,
  });

  @override
  State<ProblemView> createState() => _ProblemViewState();
}

class _ProblemViewState extends State<ProblemView> {
  static const _kinds = ['Blocking me', 'Lights on', 'Window open', 'Flat tire', 'Being towed', 'Hit your car', 'Other'];
  static final _badWords = RegExp(r'\b(idiot|stupid|fuck|shit|dumb)\b', caseSensitive: false);
  static final _spamPattern = RegExp(r'https?:|www\.|followers|\bfree\b|\bbuy\b|(.)\1{5,}', caseSensitive: false);

  int _selectedKind = -1;
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  Uint8List? _photoBytes;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 720);
      if (x != null) {
        final bytes = await x.readAsBytes();
        setState(() => _photoBytes = bytes);
      }
    } catch (_) {
      widget.onToast('Couldn’t read that photo');
    }
  }

  void _notify() {
    final s = widget.store;
    final me = s.currentUser;
    if (me == null) return widget.onToast('Please log in first');
    if (_selectedKind < 0) return widget.onToast('Pick the problem first');
    if (_photoBytes == null) return widget.onToast('Please add a photo of the problem');

    final email = me['email'].toString();
    if (s.reports.any((r) => r.user == email && r.status == 'blocked')) return widget.onToast('Your account is blocked');
    if (s.verifiedOnly && !s.isVerifiedStudent(me)) return widget.onToast('Only verified students can report');

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (s.reports.where((r) => r.user == email && (nowMs - r.id) < 3600000).length >= 5) {
      return widget.onToast('Too many reports. Try again later');
    }

    final desc = _descCtrl.text.trim();
    if (desc.isNotEmpty && (_spamPattern.hasMatch(desc) || _badWords.hasMatch(desc))) {
      return widget.onToast('Blocked by the spam filter');
    }

    final b64 = base64Encode(_photoBytes!);
    final kindStr = _kinds[_selectedKind];
    final locStr = _locCtrl.text.trim();
    final report = CarReport(
      id: nowMs,
      car: widget.carCode,
      kind: kindStr,
      text: desc.isEmpty ? 'No description' : desc,
      loc: locStr,
      user: email,
      status: 'open',
      imgBase64: b64,
    );
    s.reports.insert(0, report);

    RegisteredCar? ownerCar;
    for (final c in s.cars) {
      if (c.code == widget.carCode) {
        ownerCar = c;
        break;
      }
    }

    if (ownerCar != null) {
      s.alerts.insert(
        0,
        AlertItem(
          id: report.id,
          to: ownerCar.owner,
          car: widget.carCode,
          kind: kindStr,
          text: report.text,
          loc: locStr,
          imgBase64: b64,
          read: false,
          reply: '',
          ts: nowMs,
          ver: s.isVerifiedStudent(me),
          eta: s.activeClassEnd(ownerCar.owner),
        ),
      );
    }

    s.persist();
    _descCtrl.clear();
    _locCtrl.clear();
    setState(() {
      _selectedKind = -1;
      _photoBytes = null;
    });
    widget.onSent(ownerCar != null);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 6),
              Text('Car ${widget.carCode}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('What is the problem?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Text('Pick the problem, add a photo, then send', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_kinds.length, (i) {
              final active = i == _selectedKind;
              return ChoiceChip(
                label: Text(_kinds[i]),
                selected: active,
                selectedColor: widget.pal.pri,
                labelStyle: TextStyle(color: active ? Colors.white : null, fontWeight: FontWeight.w500),
                onSelected: (_) => setState(() => _selectedKind = i),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(hintText: 'Add details (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locCtrl,
            maxLength: 40,
            decoration: InputDecoration(hintText: 'Where? e.g. Gate 3, Lot B', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _photoBytes != null ? widget.pal.pri : Theme.of(context).dividerColor),
              ),
              child: _photoBytes != null
                  ? Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_photoBytes!, width: double.infinity, height: 180, fit: BoxFit.cover),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () => setState(() => _photoBytes = null),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: Theme.of(context).hintColor, size: 26),
                        const SizedBox(height: 6),
                        const Text('Add a photo of the problem (required)', style: TextStyle(fontSize: 13)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: widget.pal.pri, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _notify,
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Notify the owner', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Text('Messages are checked automatically. Spam and inappropriate content are blocked.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
        ],
      ),
    );
  }
}
