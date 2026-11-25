import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/safepark_state.dart';
import '../widgets/design_picker_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final SafeParkState state;
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.state,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _plateCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _backupCtrl;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.state.settings.phone);
    _backupCtrl = TextEditingController(text: widget.state.settings.backupEmail);
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _phoneCtrl.dispose();
    _backupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final d = s.design;
    final set = s.settings;
    final user = s.currentUser;
    final myCars = user == null
        ? <dynamic>[]
        : s.cars.where((c) => c.owner == user.email).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          if (user != null)
            Text(
              '${user.name} · ${user.email}',
              style: TextStyle(fontSize: 12, color: d.mute),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => DesignPickerSheet(state: s),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: d.primary,
                foregroundColor: d.primaryInk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.buttonRadius)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Switch App Design', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(d.name, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('LOOK & FEEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.mute)),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Arabic (RTL)'),
                  value: set.arabic,
                  onChanged: (v) => s.updateSettings(set.copyWith(arabic: v)),
                ),
                Divider(height: 1, color: d.border),
                SwitchListTile(
                  title: const Text('Haptics'),
                  value: set.haptics,
                  onChanged: (v) => s.updateSettings(set.copyWith(haptics: v)),
                ),
                Divider(height: 1, color: d.border),
                SwitchListTile(
                  title: const Text('Alerts for my cars'),
                  value: set.notifications,
                  onChanged: (v) => s.updateSettings(set.copyWith(notifications: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('IF I DON\'T REPLY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.mute)),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Call from app if no reply'),
                    subtitle: Text('Rings in-app after ${set.escalationMinutes} min'),
                    value: set.autoCall,
                    onChanged: (v) => s.updateSettings(set.copyWith(autoCall: v)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Minutes before call'),
                      DropdownButton<int>(
                        value: set.escalationMinutes,
                        items: [1, 3, 5, 10, 15]
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            s.updateSettings(set.copyWith(escalationMinutes: val));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => s.updateSettings(set.copyWith(phone: v)),
                    decoration: const InputDecoration(
                      labelText: 'Phone number (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _backupCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => s.updateSettings(set.copyWith(backupEmail: v)),
                    decoration: const InputDecoration(
                      labelText: 'Backup contact email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('MY CARS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.mute)),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final car in myCars) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(car.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(car.code),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: d.danger),
                        onPressed: () => s.removeCar(car.code),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: 'https://safepark.app/#car-${car.code}',
                        size: 150,
                      ),
                    ),
                    const Divider(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _plateCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Plate number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            s.addCar(_plateCtrl.text.trim());
                            _plateCtrl.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: d.primary,
                            foregroundColor: d.primaryInk,
                          ),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: () {
                s.logout();
                widget.onBack();
              },
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
