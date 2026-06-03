import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snapcard/app.dart';
import 'package:snapcard/core/app_state.dart';

void main() {
  testWidgets('shows the splash until the app is bootstrapped', (tester) async {
    // A fresh AppState is not bootstrapped, so the router renders the splash
    // without touching any platform plugins.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: const SnapCardApp(),
      ),
    );

    expect(find.text('SnapCard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
