// Widget tests for the Navigatio Map App
//
// These tests verify the core functionality of the map application,
// including UI components and basic interactions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  group('Navigatio Map App Tests', () {
    testWidgets('App loads successfully with modern UI', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify the app builds without errors
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('App shows loading state initially', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Initially should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Lade Karte...'), findsOneWidget);
    });
  });
}
