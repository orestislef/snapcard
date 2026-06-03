import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw edge-to-edge behind the status and navigation bars (true full screen),
  // with transparent system bars so the app content shows through.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize the on-device Gemma runtime once. The model repo is public, so
  // no HuggingFace token is needed.
  await FlutterGemma.initialize();

  final appState = AppState();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const SnapCardApp(),
    ),
  );

  // Detect onboarding/model state after first frame; UI shows a splash until done.
  appState.bootstrap();
}
