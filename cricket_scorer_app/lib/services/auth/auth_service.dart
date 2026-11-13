// 60Score / STUMPS account service — Google Sign-In + cPanel MySQL Backend.
// The app is offline-first: signed-in sessions persist locally in SharedPreferences
// so cold starts offline stay signed in, and guests get read-only viewing access.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';

/// Web OAuth 2.0 Client ID from Google Cloud / Firebase project `score-prod-50b9c` (60Score-Prod).
/// Passed as `serverClientId` on Android so `google_sign_in` returns a valid `idToken`
/// for our cPanel PHP backend (`/api/auth/google`) to verify.
const String kGoogleWebClientId =
        '425277341454-5vkvjag46pj9cu3q8e48t155fpm45bp1.apps.googleusercontent.com';

/// Result of an auth attempt.
enum AuthStatus {
  ok,

  /// Cloud auth is unavailable / unconfigured.
  unavailable,

  /// Wrong credentials / invalid code.
  invalidCredentials,

  /// Any other failure (network, cancelled, etc.).
  failed,
}

class AuthResult {
  final AuthStatus status;
  final String? message;
  const AuthResult(this.status, [this.message]);
}

/// Persisted cPanel Google user session for offline-first cold starts.
class CpanelAuthUser {
  final String uid;
  final String userCode;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool profileCompleted;
  final String cricketRole;
  final String battingStyle;
  final String bowlingStyle;
  final int jerseyNumber;
  final String city;
  final String contact;
  final bool pendingOnboardingSync;

  const CpanelAuthUser({
    required this.uid,
    required this.userCode,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.profileCompleted = false,
    this.cricketRole = 'All-Rounder',
    this.battingStyle = 'Right-hand bat',
    this.bowlingStyle = 'Right-arm fast-medium',
    this.jerseyNumber = 7,
    this.city = '',
    this.contact = '',
    this.pendingOnboardingSync = false,
  });

  CpanelAuthUser copyWith({
    String? displayName,
    String? avatarUrl,
    bool? profileCompleted,
    String? cricketRole,
    String? battingStyle,
    String? bowlingStyle,
    int? jerseyNumber,
    String? city,
    String? contact,
    bool? pendingOnboardingSync,
  }) {
    return CpanelAuthUser(
      uid: uid,
      userCode: userCode,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      cricketRole: cricketRole ?? this.cricketRole,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      city: city ?? this.city,
      contact: contact ?? this.contact,
      pendingOnboardingSync:
          pendingOnboardingSync ?? this.pendingOnboardingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'user_code': userCode,
        'email': email,
        'name': displayName,
        'avatar_url': avatarUrl,
        'profile_completed': profileCompleted,
        'cricket_role': cricketRole,
        'batting_style': battingStyle,
        'bowling_style': bowlingStyle,
        'jersey_number': jerseyNumber,
        'city': city,
        'contact': contact,
        'pending_onboarding_sync': pendingOnboardingSync,
      };

  factory CpanelAuthUser.fromBackendUser(
    Map<String, dynamic> userJson, {
    bool pendingOnboardingSync = false,
  }) {
    final playerProfile =
        userJson['player_profile'] as Map<String, dynamic>? ?? const {};
    final profileCompletedRaw = userJson['profile_completed'];
    final completed = profileCompletedRaw is bool
        ? profileCompletedRaw
        : (profileCompletedRaw == 1 || profileCompletedRaw == '1');

    return CpanelAuthUser(
      uid: (userJson['uid'] ?? '').toString(),
      userCode: (userJson['user_code'] ?? '').toString(),
      email: (userJson['email'] ?? '').toString(),
      displayName: (userJson['name'] ?? 'Player').toString(),
      avatarUrl: userJson['avatar_url'] as String?,
      profileCompleted: completed,
      cricketRole: (playerProfile['role'] ??
              userJson['cricket_role'] ??
              'All-Rounder')
          .toString(),
      battingStyle: (playerProfile['batting_style'] ??
              userJson['batting_style'] ??
              'Right-hand bat')
          .toString(),
      bowlingStyle: (playerProfile['bowling_style'] ??
              userJson['bowling_style'] ??
              'Right-arm fast-medium')
          .toString(),
      jerseyNumber: ((playerProfile['jersey_number'] ??
                  userJson['jersey_number'] ??
                  7) as num?)
              ?.toInt() ??
          7,
      city: (playerProfile['city'] ?? userJson['city'] ?? '').toString(),
      contact: (userJson['contact'] ?? '').toString(),
      pendingOnboardingSync: pendingOnboardingSync,
    );
  }

  factory CpanelAuthUser.fromJson(Map<String, dynamic> j) => CpanelAuthUser(
        uid: (j['uid'] ?? '').toString(),
        userCode: (j['user_code'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        displayName: (j['name'] ?? 'Player').toString(),
        avatarUrl: j['avatar_url'] as String?,
        profileCompleted: j['profile_completed'] == true ||
            j['profile_completed'] == 1,
        cricketRole: (j['cricket_role'] ?? 'All-Rounder').toString(),
        battingStyle: (j['batting_style'] ?? 'Right-hand bat').toString(),
        bowlingStyle:
            (j['bowling_style'] ?? 'Right-arm fast-medium').toString(),
        jerseyNumber: (j['jersey_number'] as num?)?.toInt() ?? 7,
        city: (j['city'] ?? '').toString(),
        contact: (j['contact'] ?? '').toString(),
        pendingOnboardingSync: j['pending_onboarding_sync'] == true,
      );
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _firebaseReady = false;
  bool get firebaseReady => _firebaseReady;

  /// The exception thrown by Firebase.initializeApp(), if it failed.
  String? _initError;
  String? get initError => _initError;

  static const _kGuestFlag = 'score60_guest_v1';
  static const _kCpanelSessionKey = 'score60_cpanel_session_v1';

  bool _guestMode = false;
  bool get guestMode => _guestMode;

  CpanelAuthUser? _cpanelUser;
  CpanelAuthUser? get cpanelUser => _cpanelUser;

  String? _forcedLogoutReason;
  String? consumeForcedLogoutReason() {
    final msg = _forcedLogoutReason;
    _forcedLogoutReason = null;
    return msg;
  }

  /// True when the user explicitly entered via "Continue as Guest" without logging in.
  /// Guests have read-only access (can view matches/scorecards, cannot create or score).
  bool get isRestrictedGuest => _guestMode && !isLoggedIn;

  /// True when signed in via Google and first-time onboarding is not yet completed.
  bool get needsOnboarding =>
      _cpanelUser != null && !_cpanelUser!.profileCompleted;

  bool _initStarted = false;
  bool _initDone = false;
  final Completer<void> _readyCompleter = Completer<void>();

  bool get initDone => _initDone;

  Future<void> waitReady(Duration timeout) async {
    if (!_initStarted || _initDone) return;
    try {
      await _readyCompleter.future.timeout(timeout);
    } catch (_) {}
  }

  Future<void> _persistGuestFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kGuestFlag, _guestMode);
    } catch (_) {}
  }

  Future<void> _persistCpanelUser(CpanelAuthUser? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user == null) {
        await prefs.remove(_kCpanelSessionKey);
      } else {
        await prefs.setString(_kCpanelSessionKey, jsonEncode(user.toJson()));
      }
    } catch (_) {}
  }

  /// Remembers the "Continue as Guest" choice on this device.
  Future<void> setGuestMode() async {
    _guestMode = true;
    await _persistGuestFlag();
    notifyListeners();
  }

  User? get currentUser =>
      _firebaseReady ? FirebaseAuth.instance.currentUser : null;

  bool get isLoggedIn => _cpanelUser != null || currentUser != null;

  String get effectiveUid => _cpanelUser?.uid ?? currentUser?.uid ?? '';

  String? get currentEmail => _cpanelUser?.email ?? currentUser?.email;

  String get displayName =>
      _cpanelUser?.displayName ??
      currentUser?.displayName ??
      currentUser?.email ??
      currentUser?.phoneNumber ??
      '';

  /// Call once at startup. Restores cPanel Google session immediately offline,
  /// and keeps Firebase init optional.
  Future<void> init() async {
    _initStarted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _guestMode = prefs.getBool(_kGuestFlag) ?? false;
      final rawSession = prefs.getString(_kCpanelSessionKey);
      if (rawSession != null && rawSession.isNotEmpty) {
        try {
          _cpanelUser = CpanelAuthUser.fromJson(
              jsonDecode(rawSession) as Map<String, dynamic>);
          if (_cpanelUser != null && _guestMode) {
            _guestMode = false;
            await prefs.setBool(_kGuestFlag, false);
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      _initError = null;
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && _guestMode) {
          _guestMode = false;
          _persistGuestFlag();
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint('Auth stream error (ignored): $e');
      });
      try {
        await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    } catch (e) {
      _firebaseReady = false;
      _initError = e.toString();
    }
    _initDone = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    notifyListeners();
  }

  AuthResult _guard() {
    if (!_firebaseReady) {
      if (_initError != null) {
        return AuthResult(
            AuthStatus.unavailable, 'Cloud setup failed: $_initError');
      }
      return const AuthResult(AuthStatus.unavailable,
          'Cloud account is not set up yet. The app works fully offline.');
    }
    return const AuthResult(AuthStatus.ok);
  }

  void notifyAuthChanged() => notifyListeners();

  // ---------- Direct Google + cPanel Backend Sign-In ----------

  Future<AuthResult> signInWithGoogle({
    CpanelApiClient? apiClient,
    GoogleSignIn? googleSignIn,
    bool notify = true,
  }) async {
    try {
      final gsi = googleSignIn ??
          GoogleSignIn(
            scopes: const ['email', 'profile'],
            serverClientId: kIsWeb ? null : kGoogleWebClientId,
          );

      final googleUser = await gsi.signIn();
      if (googleUser == null) {
        return const AuthResult(
            AuthStatus.failed, 'Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        return const AuthResult(AuthStatus.failed,
            'Could not obtain Google authentication token. Please try again.');
      }

      final client = apiClient ?? CpanelApiClient();
      if (apiClient == null) {
        await client.init();
      }

      final res = await client.signInWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
      );

      if (res['status'] != 'success' || res['data']?['user'] == null) {
        return AuthResult(
          AuthStatus.failed,
          (res['message'] ?? 'Backend Google authentication failed.')
              .toString(),
        );
      }

      final userMap =
          Map<String, dynamic>.from(res['data']['user'] as Map<String, dynamic>);
      if (res['data']['profile_completed'] != null &&
          userMap['profile_completed'] == null) {
        userMap['profile_completed'] = res['data']['profile_completed'];
      }
      _cpanelUser = CpanelAuthUser.fromBackendUser(userMap);
      _guestMode = false;
      await _persistGuestFlag();
      await _persistCpanelUser(_cpanelUser);
      if (notify) notifyListeners();

      return const AuthResult(AuthStatus.ok);
    } catch (e) {
      return AuthResult(AuthStatus.failed, e.toString());
    }
  }

  /// Completes first-time onboarding locally and syncs to cPanel backend.
  /// Works offline-first: if the network fails, saves locally with `pendingOnboardingSync`.
  Future<AuthResult> completeOnboarding({
    required String name,
    required String cricketRole,
    String battingStyle = 'Right-hand bat',
    String bowlingStyle = 'Right-arm fast-medium',
    int jerseyNumber = 7,
    String city = '',
    String contact = '',
    CpanelApiClient? apiClient,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      return const AuthResult(AuthStatus.invalidCredentials,
          'Please enter your full name (at least 2 characters).');
    }

    final existing = _cpanelUser;
    if (existing != null) {
      _cpanelUser = existing.copyWith(
        displayName: trimmedName,
        cricketRole: cricketRole,
        battingStyle: battingStyle,
        bowlingStyle: bowlingStyle,
        jerseyNumber: jerseyNumber,
        city: city.trim(),
        contact: contact.trim(),
        profileCompleted: true,
        pendingOnboardingSync: true,
      );
      await _persistCpanelUser(_cpanelUser);
      notifyListeners();
    }

    try {
      final client = apiClient ?? CpanelApiClient();
      if (apiClient == null) {
        await client.init();
      }
      if (client.token != null && client.token!.isNotEmpty) {
        final res = await client.completeOnboarding(
          name: trimmedName,
          cricketRole: cricketRole,
          battingStyle: battingStyle,
          bowlingStyle: bowlingStyle,
          jerseyNumber: jerseyNumber,
          city: city.trim(),
          contact: contact.trim(),
        );
        if (res['status'] == 'success' && res['data']?['user'] != null) {
          _cpanelUser = CpanelAuthUser.fromBackendUser(
            res['data']['user'] as Map<String, dynamic>,
            pendingOnboardingSync: false,
          );
          await _persistCpanelUser(_cpanelUser);
          notifyListeners();
        }
      }
    } catch (_) {
      // Keep local completion; pendingOnboardingSync remains true for background sync.
    }

    return const AuthResult(AuthStatus.ok);
  }

  /// Retries onboarding sync if completed offline.
  Future<void> syncPendingOnboardingIfNeeded(
      {CpanelApiClient? apiClient}) async {
    final u = _cpanelUser;
    if (u == null || !u.pendingOnboardingSync) return;
    final client = apiClient ?? CpanelApiClient();
    if (apiClient == null) await client.init();
    if (client.token == null || client.token!.isEmpty) return;

    final res = await client.completeOnboarding(
      name: u.displayName,
      cricketRole: u.cricketRole,
      battingStyle: u.battingStyle,
      bowlingStyle: u.bowlingStyle,
      jerseyNumber: u.jerseyNumber,
      city: u.city,
      contact: u.contact,
    );
    if (res['status'] == 'success') {
      _cpanelUser = u.copyWith(pendingOnboardingSync: false);
      await _persistCpanelUser(_cpanelUser);
      notifyListeners();
    }
  }

  /// Checks with the cPanel backend when online whether this account is still active.
  /// - Offline / timeout: leaves session intact (100% offline-first).
  /// - 401 / 403 (account deleted or banned by admin): signs out immediately.
  Future<bool> verifySessionWithServer({CpanelApiClient? apiClient}) async {
    if (_cpanelUser == null) return true;
    try {
      final client = apiClient ?? CpanelApiClient();
      if (apiClient == null) await client.init();
      if (client.token == null || client.token!.isEmpty) return true;

      final res = await client.getMe();
      final statusCode = res['statusCode'];
      if (statusCode == 401 || statusCode == 403) {
        await handleServerRevocation(res['message']?.toString());
        return false;
      }

      if (res['status'] == 'success' && res['data']?['user'] != null) {
        _cpanelUser = CpanelAuthUser.fromBackendUser(
          res['data']['user'] as Map<String, dynamic>,
          pendingOnboardingSync: _cpanelUser?.pendingOnboardingSync ?? false,
        );
        await _persistCpanelUser(_cpanelUser);
        notifyListeners();
      }
    } catch (_) {
      // Offline or unreachable: preserve local offline session
    }
    return true;
  }

  /// Forces local sign-out when the server rejects the token (401 deleted / 403 banned).
  Future<void> handleServerRevocation(String? message) async {
    _forcedLogoutReason = (message != null && message.trim().isNotEmpty)
        ? message.trim()
        : 'Your account has been suspended or removed by an administrator.';
    await signOut();
  }

  /// Helper for unit/widget tests to simulate a signed-in cPanel session.
  @visibleForTesting
  Future<void> setCpanelSessionForTest(CpanelAuthUser? user,
      {bool guestMode = false}) async {
    _cpanelUser = user;
    _guestMode = guestMode;
    await _persistGuestFlag();
    await _persistCpanelUser(user);
    notifyListeners();
  }

  // ---------- Legacy Email / Phone methods (retained for compatibility/tests) ----------

  Future<AuthResult> signInWithEmail(String email, String password) async {
    final g = _guard();
    if (g.status != AuthStatus.ok) return g;
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      notifyListeners();
      return const AuthResult(AuthStatus.ok);
    } on FirebaseAuthException catch (e) {
      return AuthResult(AuthStatus.invalidCredentials, _friendly(e));
    } catch (e) {
      return AuthResult(AuthStatus.failed, e.toString());
    }
  }

  Future<AuthResult> signUpWithEmail(String email, String password) async {
    final g = _guard();
    if (g.status != AuthStatus.ok) return g;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      notifyListeners();
      return const AuthResult(AuthStatus.ok);
    } on FirebaseAuthException catch (e) {
      return AuthResult(AuthStatus.invalidCredentials, _friendly(e));
    } catch (e) {
      return AuthResult(AuthStatus.failed, e.toString());
    }
  }

  Future<AuthResult> startPhoneVerification(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    void Function(String message)? onFailed,
  }) async {
    final g = _guard();
    if (g.status != AuthStatus.ok) return g;
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          notifyListeners();
        },
        verificationFailed: (e) {
          onFailed?.call(_friendly(e));
        },
        codeSent: (verificationId, _) => onCodeSent(verificationId),
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
      return const AuthResult(AuthStatus.ok);
    } catch (e) {
      return AuthResult(AuthStatus.failed, e.toString());
    }
  }

  Future<AuthResult> confirmPhoneCode(
      String verificationId, String smsCode) async {
    final g = _guard();
    if (g.status != AuthStatus.ok) return g;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      notifyListeners();
      return const AuthResult(AuthStatus.ok);
    } on FirebaseAuthException catch (e) {
      return AuthResult(AuthStatus.invalidCredentials, _friendly(e));
    } catch (e) {
      return AuthResult(AuthStatus.failed, e.toString());
    }
  }

  // ---------- Sign out ----------

  Future<void> signOut() async {
    _cpanelUser = null;
    _guestMode = false;
    await _persistGuestFlag();
    await _persistCpanelUser(null);
    try {
      final client = CpanelApiClient();
      await client.setToken(null);
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    notifyListeners();
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'invalid-verification-code':
        return 'Wrong SMS code. Try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}
