import 'package:flutter/material.dart';
import '../models/safepark_models.dart';
import '../services/safepark_store.dart';
import '../utils/theme_constants.dart';
import '../widgets/shared_widgets.dart';

class AlertsView extends StatefulWidget {
  final SafeParkStore store;
  final PaletteOption pal;
  final void Function(String msg) onToast;

  const AlertsView({
    super.key,
    required this.store,
    required this.pal,
    required this.onToast,
  });

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  bool _sentToMe = true;

  @override
  void initState() {
    super.initState();
    _markMineRead();
  }

  void _markMineRead() {
    final email = widget.store.currentUser?['email']?.toString();
    if (email == null) return;
    bool ch = false;
    for (final a in widget.store.alerts) {
      if (a.to == email && !a.read) {
        a.read = true;
        ch = true;
      }
    }
    if (ch) widget.store.persist();
  }

  void _reply(AlertItem item, String text) {
    item.reply = text;
    if (item.fwd) {
      for (final orig in widget.store.alerts) {
        if (orig.id == item.id - 1) orig.reply = 'Backup contact: $text';
      }
    }
    widget.store.persist();
    setState(() {});
    widget.onToast('Reply sent');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final email = s.currentUser?['email']?.toString() ?? '';
    final inbox = s.alerts.where((a) => a.to == email).toList();
    final sent = s.reports.where((r) => r.user == email).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('alerts', s.arabic, 'Alerts'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('Messages about your car', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(s.arabic ? 'وصلتك' : 'Sent to you')),
              const ButtonSegment(value: false, label: Text('Sent by you')),
            ],
            selected: {_sentToMe},
            onSelectionChanged: (set) => setState(() => _sentToMe = set.first),
          ),
          const SizedBox(height: 14),
          if (_sentToMe) ...[
            if (inbox.isEmpty)
              const EmptyPlaceholder(icon: Icons.notifications_none, text: 'No alerts yet.\nYou will see them here.')
            else
              ...inbox.map((a) {
                final badgeText = a.reply.isNotEmpty ? 'replied' : (a.read ? 'seen' : 'new');
                return AlertCard(
                  badge: badgeText,
                  title: '${a.car}: ${a.kind}',
                  subLines: [
                    if (a.ver) '✓ Verified student',
                    if (a.fwd) '↪ Forwarded: the owner hasn’t replied',
                    if (a.eta != null && a.reply.isEmpty) 'In class until ${a.eta}',
                    if (a.loc.isNotEmpty) a.loc,
                  ],
                  body: a.text,
                  imgBase64: a.imgBase64,
                  footer: a.reply.isNotEmpty
                      ? Text('You: ${a.reply}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))
                      : Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: widget.pal.pri),
                                onPressed: () => _reply(a, 'Coming in 5 min'),
                                child: const Text('5 min'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _reply(a, 'Moving it now'),
                                child: const Text('Moving now'),
                              ),
                            ),
                          ],
                        ),
                );
              }),
          ] else ...[
            if (sent.isEmpty)
              const EmptyPlaceholder(icon: Icons.outbox_outlined, text: 'No sent reports yet.')
            else
              ...sent.map((r) {
                AlertItem? match;
                for (final a in s.alerts) {
                  if (a.id == r.id) {
                    match = a;
                    break;
                  }
                }
                final statusLabel = match != null
                    ? (match.reply.isNotEmpty
                        ? 'replied'
                        : (match.fwdTo != null ? 'sent to backup' : (match.rep1 ? 'repeated' : (match.eta != null ? 'in class' : (match.read ? 'seen' : 'sent')))))
                    : r.status;
                return AlertCard(
                  badge: statusLabel,
                  title: '${r.car}: ${r.kind}',
                  subLines: [
                    if (r.loc.isNotEmpty) r.loc,
                    if (match != null && match.eta != null && match.reply.isEmpty) 'Owner is in class, will reply at ${match.eta}',
                    if (match != null && match.reply.isNotEmpty) 'Owner: ${match.reply}',
                  ],
                  body: r.text,
                  imgBase64: r.imgBase64,
                );
              }),
          ],
        ],
      ),
    );
  }
}
