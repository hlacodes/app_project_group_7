import 'dart:async';
import 'package:flutter/material.dart';
import '../models/safepark_models.dart';
import '../services/safepark_state.dart';

class AlertsScreen extends StatefulWidget {
  final SafeParkState state;
  const AlertsScreen({super.key, required this.state});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _showSentToYou = true;
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration remaining) {
    final secs = remaining.inSeconds.clamp(0, 999999);
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final d = s.design;
    final email = s.currentUser?.email;

    final incoming = email == null
        ? <SafeParkAlert>[]
        : s.alerts.where((a) => a.to == email).toList();
    final outgoing = email == null
        ? <SafeParkReport>[]
        : s.reports.where((r) => r.user == email).toList();

    final escDuration = Duration(minutes: s.settings.escalationMinutes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        Text('Alerts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: d.ink)),
        const SizedBox(height: 4),
        Text('Messages about your car', style: TextStyle(fontSize: 14, color: d.mute)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: d.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: d.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentBtn(
                  label: 'Sent to you (${incoming.length})',
                  active: _showSentToYou,
                  design: d,
                  onTap: () => setState(() => _showSentToYou = true),
                ),
              ),
              Expanded(
                child: _SegmentBtn(
                  label: 'Sent by you (${outgoing.length})',
                  active: !_showSentToYou,
                  design: d,
                  onTap: () => setState(() => _showSentToYou = false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_showSentToYou)
          if (incoming.isEmpty)
            _EmptyBox(design: d)
          else
            ...incoming.map((a) {
              final elapsed = _now.difference(a.createdAt);
              final remaining = escDuration - elapsed;
              final callReached = remaining <= Duration.zero || a.called;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.car} · ${a.kind}', style: TextStyle(fontWeight: FontWeight.w700, color: d.ink)),
                      if (a.loc.isNotEmpty)
                        Text(a.loc, style: TextStyle(fontSize: 12, color: d.mute)),
                      const SizedBox(height: 6),
                      Text(a.text, style: TextStyle(fontSize: 14, color: d.ink)),
                      if (a.reply.isEmpty && s.settings.autoCall) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              callReached
                                  ? 'No reply in ${s.settings.escalationMinutes}m · app call triggered'
                                  : 'Auto-call in ${_formatCountdown(remaining)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: callReached ? d.danger : d.mute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (callReached)
                              TextButton.icon(
                                onPressed: () => s.triggerCall(a),
                                icon: Icon(Icons.phone_in_talk_rounded, size: 16, color: d.danger),
                                label: Text('Answer call', style: TextStyle(color: d.danger)),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (a.reply.isNotEmpty)
                        Text('Your reply: ${a.reply}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: d.success))
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => s.replyToAlert(a.id, 'Coming in 5 min'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: d.primary,
                                  foregroundColor: d.primaryInk,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.buttonRadius)),
                                ),
                                child: const Text('Coming in 5 min', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => s.replyToAlert(a.id, 'Moving it now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: d.ink,
                                  side: BorderSide(color: d.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.buttonRadius)),
                                ),
                                child: const Text('Moving now', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            })
        else if (outgoing.isEmpty)
          _EmptyBox(design: d)
        else
          ...outgoing.map((r) {
            final linked = s.alerts.where((a) => a.id == r.id).firstOrNull;
            final createdAt = linked?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(r.id);
            final remaining = escDuration - _now.difference(createdAt);
            final callReady = (linked == null || linked.reply.isEmpty) &&
                (remaining <= Duration.zero || (linked?.called ?? false));

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.car} · ${r.kind}', style: TextStyle(fontWeight: FontWeight.w700, color: d.ink)),
                    const SizedBox(height: 4),
                    Text(r.text, style: TextStyle(fontSize: 14, color: d.ink)),
                    if (linked?.reply.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text('Owner: ${linked!.reply}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: d.success)),
                    ] else if (s.settings.autoCall) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            callReady
                                ? 'No reply in ${s.settings.escalationMinutes}m'
                                : 'App call in ${_formatCountdown(remaining)}',
                            style: TextStyle(fontSize: 12, color: callReady ? d.danger : d.mute),
                          ),
                          if (callReady)
                            ElevatedButton.icon(
                              onPressed: () => s.triggerCall(
                                linked ??
                                    SafeParkAlert(
                                      id: r.id,
                                      to: r.car,
                                      car: r.car,
                                      kind: r.kind,
                                      text: r.text,
                                      loc: r.loc,
                                      createdAt: createdAt,
                                      called: true,
                                    ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: d.primary,
                                foregroundColor: d.primaryInk,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(d.buttonRadius)),
                              ),
                              icon: const Icon(Icons.phone_rounded, size: 15),
                              label: const Text('Call from app', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool active;
  final dynamic design;
  final VoidCallback onTap;

  const _SegmentBtn({
    required this.label,
    required this.active,
    required this.design,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? design.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? design.primaryInk : design.mute,
          ),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final dynamic design;
  const _EmptyBox({required this.design});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: design.card,
        borderRadius: BorderRadius.circular(design.cardRadius),
        border: Border.all(color: design.border),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 36, color: design.mute),
          const SizedBox(height: 8),
          Text('No alerts yet.', style: TextStyle(color: design.mute, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
