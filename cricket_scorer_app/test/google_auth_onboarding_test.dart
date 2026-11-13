import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/home/login_screen.dart';
import 'package:cricket_scorer_app/views/screens/home/profile_setup_screen.dart';
import 'package:cricket_scorer_app/views/widgets/guest_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().signOut();
  });

  group('cPanel Google Auth & Onboarding API', () {
    test('signInWithGoogle posts id_token and persists Bearer token', () async {
      String? capturedPath;
      Map<String, dynamic> capturedBody = {};

      final mockHttp = MockClient((req) async {
        capturedPath = req.url.path;
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'token': 'tok_google_abc123',
              'is_new_user': true,
              'profile_completed': false,
              'user': {
                'uid': 'usr_123456',
                'user_code': '60S-ABCDEF',
                'name': 'Aliyan',
                'email': 'aliyan@example.com',
                'profile_completed': false,
              }
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      final res = await client.signInWithGoogle(idToken: 'fake_google_jwt');

      expect(capturedPath, endsWith('/auth/google'));
      expect(capturedBody['id_token'], 'fake_google_jwt');
      expect(res['status'], 'success');
      expect(client.token, 'tok_google_abc123');
    });

    test('completeOnboarding posts profile details with Bearer token', () async {
      Map<String, dynamic> capturedBody = {};
      String? authHeader;

      final mockHttp = MockClient((req) async {
        authHeader = req.headers['Authorization'];
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'profile_completed': true,
              'user': {
                'uid': 'usr_123456',
                'user_code': '60S-ABCDEF',
                'name': 'Aliyan Tarar',
                'email': 'aliyan@example.com',
                'profile_completed': true,
                'city': 'Lahore',
                'player_profile': {
                  'role': 'Bowler',
                  'batting_style': 'Left-hand bat',
                  'bowling_style': 'Left-arm fast',
                  'jersey_number': 18,
                  'city': 'Lahore',
                }
              }
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      await client.setToken('tok_google_abc123');

      final auth = AuthService();
      await auth.setCpanelSessionForTest(
        const CpanelAuthUser(
          uid: 'usr_123456',
          userCode: '60S-ABCDEF',
          email: 'aliyan@example.com',
          displayName: 'Aliyan',
          profileCompleted: false,
        ),
      );
      expect(auth.needsOnboarding, isTrue);

      final result = await auth.completeOnboarding(
        name: 'Aliyan Tarar',
        cricketRole: 'Bowler',
        battingStyle: 'Left-hand bat',
        bowlingStyle: 'Left-arm fast',
        jerseyNumber: 18,
        city: 'Lahore',
        apiClient: client,
      );

      expect(result.status, AuthStatus.ok);
      expect(authHeader, 'Bearer tok_google_abc123');
      expect(capturedBody['cricket_role'], 'Bowler');
      expect(capturedBody['jersey_number'], 18);
      expect(auth.needsOnboarding, isFalse);
      expect(auth.cpanelUser?.cricketRole, 'Bowler');
      expect(auth.cpanelUser?.pendingOnboardingSync, isFalse);
    });
  });

  group('Guest Mode Read-Only Restrictions & Onboarding UI', () {
    test('isRestrictedGuest is true only when guest mode is active without login',
        () async {
      final auth = AuthService();
      expect(auth.isRestrictedGuest, isFalse);

      await auth.setGuestMode();
      expect(auth.isRestrictedGuest, isTrue);

      await auth.setCpanelSessionForTest(
        const CpanelAuthUser(
          uid: 'usr_1',
          userCode: '60S-111111',
          email: 'player@example.com',
          displayName: 'Player',
          profileCompleted: true,
        ),
        guestMode: false,
      );
      expect(auth.isRestrictedGuest, isFalse);
    });

    testWidgets('LoginScreen renders Google Sign-In and Guest option cleanly',
        (tester) async {
      final store = Store();
      await store.activateIdentity('guest');

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(store: store, gateMode: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Login with Google'), findsOneWidget);
      expect(find.text('Explore as a Guest'), findsOneWidget);
    });

    testWidgets('ProfileSetupScreen collects name and role and completes onboarding',
        (tester) async {
      final store = Store();
      await store.activateAccount('usr_new_1', email: 'new@example.com');
      final auth = AuthService();
      await auth.setCpanelSessionForTest(
        const CpanelAuthUser(
          uid: 'usr_new_1',
          userCode: '60S-222222',
          email: 'new@example.com',
          displayName: 'New User',
          profileCompleted: false,
        ),
      );

      var completedCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            store: store,
            gateMode: true,
            onCompleted: () => completedCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Bowler role chip
      await tester.tap(find.text('Bowler'));
      await tester.pumpAndSettle();

      // Scroll and tap Save Profile & Continue
      final saveBtn = find.text('Save Profile & Continue');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(completedCalled, isTrue);
      expect(auth.needsOnboarding, isFalse);
      expect(auth.cpanelUser?.cricketRole, 'Bowler');
      expect(store.activeProfile.role, 'Bowler');
    });

    testWidgets('requireSignedInAction blocks restricted guests with prompt',
        (tester) async {
      final store = Store();
      await store.activateIdentity('guest');
      await AuthService().setGuestMode();

      bool? allowed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  allowed = await requireSignedInAction(ctx, store,
                      actionLabel: 'create matches');
                },
                child: const Text('Create Match'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Match'));
      await tester.pumpAndSettle();

      expect(find.text('Guest Mode is View-Only'), findsOneWidget);
      expect(find.text('Sign In with Google'), findsOneWidget);

      await tester.tap(find.text('Continue Viewing as Guest'));
      await tester.pumpAndSettle();
      expect(allowed, isFalse);
    });

    test('verifySessionWithServer signs out banned/deleted user on 403',
        () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'status': 'error',
            'message': 'Your account has been banned by an administrator.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      await client.setToken('tok_banned');

      final auth = AuthService();
      await auth.setCpanelSessionForTest(
        const CpanelAuthUser(
          uid: 'usr_banned',
          userCode: '60S-999999',
          email: 'banned@example.com',
          displayName: 'Banned Player',
          profileCompleted: true,
        ),
      );
      expect(auth.isLoggedIn, isTrue);

      final valid = await auth.verifySessionWithServer(apiClient: client);
      expect(valid, isFalse);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.consumeForcedLogoutReason(),
          'Your account has been banned by an administrator.');
    });
  });
}
