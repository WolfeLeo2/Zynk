// Zynk POS Widget Tests
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/main.dart';

void main() {
  group('Zynk App Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('App renders without crashing', (WidgetTester tester) async {
      // Build our app wrapped in ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MyApp(),
        ),
      );

      // Wait for initialization
      await tester.pump(const Duration(seconds: 2));

      // Verify app title is present
      expect(find.text('Zynk POS'), findsOneWidget);
    });

    testWidgets('Login screen shows on initial load', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MyApp(),
        ),
      );

      await tester.pump(const Duration(seconds: 2));

      // Should show login screen elements
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });
  });
}
