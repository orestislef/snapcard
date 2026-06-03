import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.document_scanner_outlined,
    'Scan a business card,\nget a contact in seconds',
    'Point your camera at a card and SnapCard pulls out the name, title, '
        'company, phones, emails and more.',
  ),
  _Slide(
    Icons.lock_outline,
    'Runs 100% on your phone',
    'Your card images and contact data never leave the device. It works fully '
        'offline once the model is downloaded.',
  ),
  _Slide(
    Icons.cloud_download_outlined,
    'One-time AI model download',
    'First, we download the on-device AI model (~3.7 GB). Use Wi-Fi — this only '
        'happens once.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  void _next() {
    if (_isLast) {
      context.read<AppState>().setOnboardingSeen();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _isLast
                  ? const SizedBox(height: 48)
                  : TextButton(
                      onPressed: () =>
                          context.read<AppState>().setOnboardingSeen(),
                      child: const Text('Skip'),
                    ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, size: 96, color: theme.colorScheme.primary),
                        const SizedBox(height: 40),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _next,
                child: Text(_isLast ? 'Download the model' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
