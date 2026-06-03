import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'screens/capture/capture_screen.dart';
import 'screens/onboarding/model_download_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

class SnapCardApp extends StatelessWidget {
  const SnapCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'SnapCard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          // Kill the Material 3 scroll-under tint band so the top looks flat
          // and full-bleed instead of a separate coloured bar.
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      // Tap anywhere outside a text field to dismiss the keyboard — applies to
      // every route, including pushed ones.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      home: const _RootRouter(),
    );
  }
}

/// Picks the top-level screen from [AppState]: splash → onboarding → download →
/// capture. Rebuilds automatically as the state changes.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.bootstrapped) return const _Splash();
    if (!state.onboardingSeen) return const OnboardingScreen();
    if (!state.modelReady) return const ModelDownloadScreen();
    return const CaptureScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_mail_outlined, size: 64),
            SizedBox(height: 16),
            Text('SnapCard'),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
