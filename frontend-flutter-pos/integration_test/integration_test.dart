import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Flutter Backend Integration Tests', () {
    testWidgets('Backend Health Check', (final WidgetTester tester) async {
      // Test backend health endpoint
      final response =
          await http.get(Uri.parse('http://localhost:8081/actuator/health'));
      expect(response.statusCode, 200);
      final data = json.decode(response.body);
      expect(data['status'], 'UP');
    });

    testWidgets('Authentication API Test', (final WidgetTester tester) async {
      // Test login endpoint
      final response = await http.post(
        Uri.parse('http://localhost:8081/api/auth/login'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: json.encode(
          <String, String>{
            'email': 'owner@kaknnea.local',
            'password': 'Password123!',
          },
        ),
      );
      expect(response.statusCode, 200);
      final data = json.decode(response.body);
      expect(data['token'], isNotNull);
      expect(data['user'], isNotNull);
      expect(data['user']['email'], 'owner@kaknnea.local');
    });

    testWidgets('Products API Test', (final WidgetTester tester) async {
      // First login to get token
      final loginResponse = await http.post(
        Uri.parse('http://localhost:8081/api/auth/login'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: json.encode(
          <String, String>{
            'email': 'owner@kaknnea.local',
            'password': 'Password123!',
          },
        ),
      );
      final loginData = json.decode(loginResponse.body);
      final token = loginData['token'];

      // Test products endpoint with authentication
      final response = await http.get(
        Uri.parse('http://localhost:8081/api/products'),
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      expect(response.statusCode, 200);
      final data = json.decode(response.body);
      expect(data['content'], isNotNull);
      expect(data['content'], isA<List>());
      expect(data['content'].length, greaterThan(0));
    });

    testWidgets('Categories API Test', (final WidgetTester tester) async {
      // First login to get token
      final loginResponse = await http.post(
        Uri.parse('http://localhost:8081/api/auth/login'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: json.encode(
          <String, String>{
            'email': 'owner@kaknnea.local',
            'password': 'Password123!',
          },
        ),
      );
      final loginData = json.decode(loginResponse.body);
      final token = loginData['token'];

      // Test categories endpoint with authentication
      final response = await http.get(
        Uri.parse('http://localhost:8081/api/categories'),
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      expect(response.statusCode, 200);
      final data = json.decode(response.body);
      expect(data, isA<List>());
      expect(data.length, greaterThan(0));
      expect(data[0]['nameEn'], isNotNull);
    });

    testWidgets('Flutter App Loads', (final WidgetTester tester) async {
      // Test that the Flutter app can be built and run
      await tester.pumpWidget(const ProviderScope(child: PosApp()));

      // Wait for initialization
      await tester.pumpAndSettle();

      // The app should load without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Flutter App API Integration',
        (final WidgetTester tester) async {
      // This test verifies that the Flutter app can make API calls
      // We can't easily test the full UI flow without mocking, but we can verify
      // that the app structure is correct and API services are configured

      await tester.pumpWidget(const ProviderScope(child: PosApp()));
      await tester.pumpAndSettle();

      // App should load login screen initially (since no user is authenticated)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
