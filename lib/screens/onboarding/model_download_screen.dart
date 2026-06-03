import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/gemma_service.dart';
import '../../core/model_state.dart';

class ModelDownloadScreen extends StatelessWidget {
  const ModelDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Download AI model')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.smart_toy_outlined,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Gemma 3n — on-device',
                  textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'About ${kModelSizeGb.toStringAsFixed(1)} GB. Downloaded once, '
                'then runs fully offline on your phone.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              switch (state.modelState) {
                ModelState.downloading => _Downloading(state: state),
                ModelState.error =>
                  _ErrorView(state: state, onRetry: state.startDownload),
                _ => _Intro(state: state, onDownload: state.startDownload),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.state, required this.onDownload});
  final AppState state;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Notice(
          icon: Icons.wifi,
          text: 'Large download — Wi-Fi strongly recommended.',
        ),
        if (state.deviceGate.isLowRam)
          _Notice(
            icon: Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            text: 'Your device has ${state.deviceGate.ramLabel} of RAM. The '
                'vision model wants ~8 GB; it may run slowly or fail to load. '
                'You can proceed at your own risk.',
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),
      ],
    );
  }
}

class _Downloading extends StatelessWidget {
  const _Downloading({required this.state});
  final AppState state;

  String _fmtMb(double mb) =>
      mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.round()} MB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = state.downloadProgress;
    final doneMb = kModelSizeGb * 1024 * p / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Downloading…', style: theme.textTheme.titleMedium),
            Text(
              '$p%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: p <= 0 ? null : p / 100,
            minHeight: 12,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.download_done,
                label: 'Downloaded',
                value: _fmtMb(doneMb),
                sub: 'of ${kModelSizeGb.toStringAsFixed(1)} GB',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.speed,
                label: 'Speed',
                value: state.downloadSpeedText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.schedule,
                label: 'Time left',
                value: state.etaText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: state.cancelDownload,
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Keep the app open — it keeps downloading in the background.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One compact stat box (Downloaded / Speed / Time left).
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (sub != null)
            Text(sub!,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state, required this.onRetry});
  final AppState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
        const SizedBox(height: 12),
        Text(state.errorMessage ?? 'Download failed.',
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c)),
          ),
        ],
      ),
    );
  }
}
