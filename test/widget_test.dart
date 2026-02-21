// Zynk POS Widget Tests
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zynk/main.dart';

void main() {
  group('Zynk App Tests', () {
    testWidgets('App renders without crashing', (WidgetTester tester) async {
      // Build our app wrapped in ProviderScope
      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      // Wait for initialization
      await tester.pumpAndSettle();

      // Verify app title is present
      expect(find.text('Zynk POS'), findsOneWidget);
    });

    testWidgets('Login screen shows on initial load', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      await tester.pumpAndSettle();

      // Should show login screen elements
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });
  });
}
