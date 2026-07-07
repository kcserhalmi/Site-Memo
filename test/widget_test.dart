import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:site_memo/providers/app_provider.dart';
import 'package:site_memo/screens/auth/auth_gate.dart';

// End-to-end smoke test through demo mode: setup screen → dashboard →
// job detail → timeline. Runs without Firebase.
void main() {
  Future<AppProvider> pumpApp(WidgetTester tester) async {
    final provider = AppProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: AuthGate(firebaseError: 'not configured in tests'),
        ),
      ),
    );
    return provider;
  }

  testWidgets('setup screen offers demo mode when Firebase is missing',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('EXPLORE IN DEMO MODE'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsWidgets);
  });

  testWidgets('demo mode boots to dashboard with sample jobs',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('EXPLORE IN DEMO MODE'));
    await tester.pumpAndSettle();

    // Dashboard header + seeded jobs
    expect(find.text('Site Memo'), findsOneWidget);
    expect(find.text('Commercial Reno'), findsOneWidget);
    expect(find.text('Residential Unit B'), findsOneWidget);
    // Bottom nav tabs
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('job detail opens with inspections and timeline toggle',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('EXPLORE IN DEMO MODE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commercial Reno'));
    await tester.pumpAndSettle();

    // 'INSPECTIONS' appears as both a stat label and the view toggle
    expect(find.text('INSPECTIONS'), findsNWidgets(2));
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Foundation check'), findsOneWidget);

    // Timeline view renders its empty state (sample data has no photos)
    await tester.tap(find.text('TIMELINE'));
    await tester.pumpAndSettle();
    expect(find.text('No photos yet'), findsOneWidget);
  });

  testWidgets('search tab finds jobs by name', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('EXPLORE IN DEMO MODE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'warehouse');
    await tester.pumpAndSettle();
    expect(find.text('Warehouse Facility'), findsOneWidget);
  });
}
