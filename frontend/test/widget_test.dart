// Widget tests for the Navigatio Map App
//
// These tests verify the core functionality of the map application,
// including UI components and basic interactions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  group('Navigatio Map App Tests', () {
    testWidgets('App loads with correct title', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the app title is displayed
      expect(find.text('Navigatio - OSM Karte'), findsOneWidget);
    });

    testWidgets('App contains map and navigation buttons', (
      WidgetTester tester,
    ) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify that essential UI elements are present
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.add_location), findsOneWidget);

      // Check for zoom controls
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    });

    testWidgets('Dark/Light mode toggle works', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find and tap the dark/light mode toggle
      final toggleButton = find.byIcon(Icons.dark_mode);
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // After toggle, should show light mode icon
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('Marker mode toggle works', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find and tap the add marker button
      final markerButton = find.byIcon(Icons.add_location);
      expect(markerButton, findsOneWidget);

      await tester.tap(markerButton);
      await tester.pumpAndSettle();

      // After toggle, should show place icon (marker mode active)
      expect(find.byIcon(Icons.place), findsOneWidget);
    });
  });
}
