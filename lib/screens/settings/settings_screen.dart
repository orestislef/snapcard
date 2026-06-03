import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/gemma_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _deleteModel() async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete the AI model?'),
        content: const Text(
          'Frees about 3.7 GB. You\'ll need to re-download it to scan again.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await state.deleteModel();
    if (!mounted) return;
    // Model gone → the root router now shows the download screen; close settings.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const _SectionTitle('AI model'),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Gemma 3n (on-device)'),
              subtitle: Text(state.modelReady
                  ? 'Installed · ${kModelSizeGb.toStringAsFixed(1)} GB'
                  : 'Not installed'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('Delete model',
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Free up ~3.7 GB'),
              enabled: state.modelReady,
              onTap: state.modelReady ? _deleteModel : null,
            ),
            const Divider(),
            const _SectionTitle('Device'),
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Total RAM'),
              subtitle: Text(state.deviceGate.ramLabel),
              trailing: state.deviceGate.isLowRam
                  ? Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error)
                  : null,
            ),
            if (state.deviceGate.isLowRam)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'The vision model wants ~8 GB of RAM; on this device it may be '
                  'slow or fail to load.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const Divider(),
            const _SectionTitle('About'),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Private by design'),
              subtitle: Text(
                'Card images and contact data are processed entirely on your '
                'phone and never uploaded.',
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Version'),
              subtitle: Text('SnapCard 1.0.0'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
