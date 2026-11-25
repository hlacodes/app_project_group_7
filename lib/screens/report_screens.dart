import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/safepark_models.dart';
import '../services/safepark_state.dart';

class ReportScreen extends StatefulWidget {
  final SafeParkState state;
  final VoidCallback onReportSubmitted;

  const ReportScreen({
    super.key,
    required this.state,
    required this.onReportSubmitted,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _codeCtrl = TextEditingController();
  bool _savingSpot = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _openProblemForm(String rawCode) {
    final code = rawCode.trim().toUpperCase().isEmpty
        ? 'DEMO-001'
        : rawCode.trim().toUpperCase();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProblemFormScreen(
          state: widget.state,
          carCode: code,
          onDone: widget.onReportSubmitted,
        ),
      ),
    );
  }

  Future<void> _scanQr() async {
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QrCameraModal(),
    );
    if (scanned != null && scanned.isNotEmpty && mounted) {
      final match = RegExp(r'#car-([A-Za-z0-9-]+)').firstMatch(scanned);
      final code = (match?.group(1) ?? scanned.split('/').last).toUpperCase();
      _openProblemForm(code);
    }
  }

  Future<void> _parkOrFind() async {
    final spot = widget.state.parkedSpot;
    if (spot != null) {
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${spot.lat},${spot.lon}&travelmode=walking',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    setState(() => _savingSpot = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final pos = await Geolocator.getCurrentPosition();
      widget.state.saveParkedSpot(pos.latitude, pos.longitude);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parking spot saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSpot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.state.design;
    final spot = widget.state.parkedSpot;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        Text(
          'Report a car',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: d.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Alert the owner in one tap.',
          style: TextStyle(fontSize: 14, color: d.mute),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocked in? Lights left on?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: d.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan the sticker on the windshield and the owner is notified instantly.',
                  style: TextStyle(fontSize: 13, color: d.mute),
                ),
                const SizedBox(height: 14),
                // Only Scan a QR code button (QR image button removed)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _scanQr,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: d.primary,
                      foregroundColor: d.primaryInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(d.buttonRadius),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan a QR code', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: d.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('OR ENTER THE CODE', style: TextStyle(fontSize: 11, color: d.mute)),
            ),
            Expanded(child: Divider(color: d.border)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            prefixText: '#  ',
            hintText: 'Car code (try DEMO-001)',
            filled: true,
            fillColor: d.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(d.cardRadius),
              borderSide: BorderSide(color: d.border),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ['DEMO-001', 'CAR-1234']
              .map(
                (code) => ActionChip(
                  label: Text(code),
                  onPressed: () => _openProblemForm(code),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => _openProblemForm(_codeCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: d.primary,
              foregroundColor: d.primaryInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(d.buttonRadius),
              ),
            ),
            child: const Text('Continue →', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(d.cardRadius),
          onTap: _savingSpot ? null : _parkOrFind,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: d.accent2,
              borderRadius: BorderRadius.circular(d.cardRadius),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot != null
                            ? 'Find my car'
                            : (_savingSpot ? 'Saving GPS spot...' : 'I parked here'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spot != null
                            ? 'Saved · opens walking directions in Google Maps'
                            : 'Save your GPS spot so you never lose your car',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  spot != null ? Icons.navigation_rounded : Icons.location_on_rounded,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QrCameraModal extends StatelessWidget {
  const _QrCameraModal();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          AppBar(title: const Text('Scan Windshield QR')),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final val = capture.barcodes.firstOrNull?.rawValue;
                if (val != null) Navigator.pop(context, val);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProblemFormScreen extends StatefulWidget {
  final SafeParkState state;
  final String carCode;
  final VoidCallback onDone;

  const ProblemFormScreen({
    super.key,
    required this.state,
    required this.carCode,
    required this.onDone,
  });

  @override
  State<ProblemFormScreen> createState() => _ProblemFormScreenState();
}

class _ProblemFormScreenState extends State<ProblemFormScreen> {
  int _selectedKind = -1;
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  String? _imagePath;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, maxWidth: 1080, imageQuality: 75);
    if (xfile != null && mounted) {
      setState(() => _imagePath = xfile.path);
    }
  }

  void _submit() {
    if (_selectedKind < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick the problem first')),
      );
      return;
    }
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of the problem')),
      );
      return;
    }

    final err = widget.state.submitReport(
      carCode: widget.carCode,
      kind: kProblemKinds[_selectedKind],
      description: _descCtrl.text,
      location: _locCtrl.text,
      imagePath: _imagePath!,
    );

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    Navigator.pop(context);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.state.design;
    return Scaffold(
      appBar: AppBar(title: Text('Car ${widget.carCode}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('What is the problem?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: d.ink)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: kProblemKinds.length,
            itemBuilder: (_, i) {
              final active = i == _selectedKind;
              return ElevatedButton(
                onPressed: () => setState(() => _selectedKind = i),
                style: ElevatedButton.styleFrom(
                  backgroundColor: active ? d.primary : d.card,
                  foregroundColor: active ? d.primaryInk : d.ink,
                  elevation: 0,
                  side: BorderSide(color: active ? d.primary : d.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(kProblemKinds[i], textAlign: TextAlign.center),
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Add details (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locCtrl,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'Where? e.g. Gate 3, Lot B',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickPhoto,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: d.card,
                borderRadius: BorderRadius.circular(d.cardRadius),
                border: Border.all(color: d.border),
              ),
              child: _imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(d.cardRadius),
                      child: Image.file(File(_imagePath!), fit: BoxFit.cover, width: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: d.mute),
                        const SizedBox(height: 6),
                        Text('Add a photo of the problem (required)', style: TextStyle(fontSize: 12, color: d.mute)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: d.primary,
                foregroundColor: d.primaryInk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.buttonRadius)),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Notify the owner', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
