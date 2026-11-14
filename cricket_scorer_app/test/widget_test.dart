import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scorer_app/main.dart';

void main() {
  testWidgets('60Score boots to splash then login gate and guest home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const Score60App());
    await tester.pump();
    // Splash shows the embedded logo artwork.
    expect(find.byType(Image), findsWidgets);
    // Let the splash timer finish and the Google login gate appear.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Login with Google'), findsOneWidget);
    expect(find.text('Explore as a Guest'), findsOneWidget);

    // Continuing as Guest enters the read-only Home dashboard.
    final guestBtn = find.text('Explore as a Guest');
    await tester.ensureVisible(guestBtn);
    await tester.tap(guestBtn);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('ACTIVE TOURNAMENTS'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Matches'), findsWidgets);
  });
}
