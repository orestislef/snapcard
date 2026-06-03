import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/business_card.dart';
import '../review/review_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<BusinessCard>? _cards;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final cards = await context.read<AppState>().history.load();
    if (mounted) setState(() => _cards = cards);
  }

  Future<void> _clearAll() async {
    final history = context.read<AppState>().history;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all scanned cards from the app. '
            'Contacts already saved to your phone are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await history.clear();
      await _reload();
    }
  }

  Future<void> _open(BusinessCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewScreen(card: card, isNew: false)),
    );
    await _reload();
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (cards != null && cards.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _body(cards),
      ),
    );
  }

  Widget _body(List<BusinessCard>? cards) {
    if (cards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('No scans yet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Scanned cards show up here. Tap one to edit or add it to '
                'your contacts.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      // SafeArea already insets the bottom; just a little breathing room.
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = cards[i];
        return Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) async {
            await context.read<AppState>().history.delete(c.id);
            setState(() => cards.removeAt(i));
          },
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                c.displayTitle.isNotEmpty
                    ? c.displayTitle.characters.first.toUpperCase()
                    : '?',
              ),
            ),
            title: Text(c.displayTitle),
            subtitle: Text(
              [
                if (c.displaySubtitle.isNotEmpty) c.displaySubtitle,
                _fmtDate(c.scannedAt),
              ].join('\n'),
            ),
            isThreeLine: c.displaySubtitle.isNotEmpty,
            trailing: c.addedToContacts
                ? Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary)
                : const Icon(Icons.chevron_right),
            onTap: () => _open(c),
          ),
        );
      },
    );
  }
}
