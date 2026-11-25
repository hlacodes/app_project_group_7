import 'package:flutter/material.dart';
import '../services/safepark_state.dart';

class AdminLoginScreen extends StatefulWidget {
  final SafeParkState state;
  const AdminLoginScreen({super.key, required this.state});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _login() {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email == 'admin@uni.edu' && _pwCtrl.text == 'admin123') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AdminConsoleScreen(state: widget.state)),
      );
    } else {
      setState(() => _error = 'Wrong email or password. Try admin@uni.edu / admin123');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.state.design;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('University staff only', style: TextStyle(color: d.mute)),
            const SizedBox(height: 14),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Admin email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: TextStyle(color: d.danger, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: d.primary,
                  foregroundColor: d.primaryInk,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.buttonRadius)),
                ),
                child: const Text('Log in as admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminConsoleScreen extends StatelessWidget {
  final SafeParkState state;
  const AdminConsoleScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final d = state.design;
        final openCount = state.reports.where((r) => r.status == 'open').length;
        final resolvedCount = state.reports.where((r) => r.status == 'resolved').length;
        final blockedCount = state.reports
            .where((r) => r.status == 'blocked')
            .map((r) => r.user)
            .toSet()
            .length;

        return Scaffold(
          appBar: AppBar(title: const Text('Admin Console')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  _StatBox(label: 'Open', value: '$openCount', design: d),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Resolved', value: '$resolvedCount', design: d),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Blocked', value: '$blockedCount', design: d),
                ],
              ),
              const SizedBox(height: 18),
              Text('REPORTS (${state.reports.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: d.mute)),
              const SizedBox(height: 8),
              ...state.reports.map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r.car} · ${r.kind}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(r.status.toUpperCase(), style: TextStyle(fontSize: 11, color: d.mute)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(r.user, style: TextStyle(fontSize: 12, color: d.mute)),
                        const SizedBox(height: 6),
                        Text(r.text),
                        if (r.status == 'open') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => state.resolveReport(r.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: d.primary,
                                    foregroundColor: d.primaryInk,
                                  ),
                                  child: const Text('Mark resolved'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => state.blockReportUser(r.id),
                                  child: const Text('Block user'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final dynamic design;
  const _StatBox({required this.label, required this.value, required this.design});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(fontSize: 11, color: design.mute)),
            ],
          ),
        ),
      ),
    );
  }
}
