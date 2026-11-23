// 60Score / STUMPS — Minimalist Direct Google Login Screen
// Two clear actions only: Login with Google, or Explore as a Guest (view-only).
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';
import 'package:cricket_scorer_app/views/screens/home/profile_setup_screen.dart';
import 'package:cricket_scorer_app/views/widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  final Store? store;

  /// Gate mode: shown right after splash when nobody is signed in.
  /// No route to pop — [onGatePassed] fires when signed in or Guest chosen.
  final bool gateMode;
  final VoidCallback? onGatePassed;

  const LoginScreen({
    super.key,
    this.store,
    this.gateMode = false,
    this.onGatePassed,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = _auth.consumeForcedLogoutReason();
  }

  String _cleanError(String raw) {
    if (raw.contains('People API') || raw.contains('SERVICE_DISABLED')) {
      return 'Google People API is disabled in Google Cloud Console. Please enable it and retry.';
    }
    if (raw.contains('ApiException: 10') || raw.contains('sign_in_failed')) {
      return 'Google Sign-In configuration error (SHA-1 / Client ID). Please check OAuth setup.';
    }
    if (raw.contains('popup_closed') || raw.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }
    // Keep error banner concise — avoid dumping raw JSON stacks
    if (raw.length > 160) {
      return '${raw.substring(0, 157)}...';
    }
    return raw;
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await _auth.signInWithGoogle(notify: false);
    if (!mounted) return;

    if (result.status != AuthStatus.ok) {
      setState(() {
        _busy = false;
        _error = _cleanError(
          result.message ?? 'Google sign-in failed. Please try again.',
        );
      });
      return;
    }

    try {
      final store = widget.store;
      if (store != null) {
        final cu = _auth.cpanelUser;
        if (cu != null) {
          await store.activateAccount(
            cu.uid,
            email: cu.email,
            displayName: cu.displayName,
            role: cu.cricketRole,
            battingStyle: cu.battingStyle,
            bowlingStyle: cu.bowlingStyle,
            jerseyNumber: cu.jerseyNumber,
            city: cu.city,
          );
          // Pull user's own cloud data (tournaments, matches, teams) in background
          unawaited(() async {
            try {
              final client = CpanelApiClient();
              await client.init();
              final sync = CpanelSyncService(store: store, apiClient: client);
              await sync.pullAndMerge();
            } catch (_) {}
          }());
        } else {
          final fu = _auth.currentUser;
          if (fu != null) {
            await store.activateAccount(
              fu.uid,
              email: fu.email,
              displayName: fu.displayName,
              phoneNumber: fu.phoneNumber,
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Account setup error: ${_cleanError(e.toString())}';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (widget.gateMode) {
      _auth.notifyAuthChanged();
      widget.onGatePassed?.call();
      return;
    }

    if (_auth.needsOnboarding) {
      await Navigator.pushReplacement<bool, bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            store: widget.store,
            gateMode: false,
          ),
        ),
      );
      _auth.notifyAuthChanged();
      widget.onGatePassed?.call();
    } else {
      _auth.notifyAuthChanged();
      widget.onGatePassed?.call();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _exploreAsGuest() async {
    setState(() => _busy = true);
    final store = widget.store;
    if (store != null) {
      await store.activateIdentity('guest');
    }
    await _auth.setGuestMode();
    if (!mounted) return;
    setState(() => _busy = false);

    if (widget.onGatePassed != null) {
      widget.onGatePassed!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topHeroHeight = (screenHeight * 0.40).clamp(240.0, 340.0);

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // -------------------------------------------------------------
            // TOP SECTION: HERO SPORTS GRAPHICS & DESIGN BANNER
            // -------------------------------------------------------------
            Stack(
              children: [
                Container(
                  height: topHeroHeight,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PitchTheme.primary,
                        PitchTheme.primaryContainer,
                        Color(0xFF06281E),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Pitch dynamic ambient decorative circles
                      Positioned(
                        top: -40,
                        right: -30,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PitchTheme.secondary.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -30,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PitchTheme.tertiaryFixed.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      // Center Hero Artwork & Branding
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppLogo(height: 80),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  '60',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Score',
                                  style: TextStyle(
                                    color: PitchTheme.tertiaryFixed,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: PitchTheme.tertiaryFixed.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: PitchTheme.tertiaryFixed.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'OFFLINE CRICKET SCORER & TELEMETRY',
                                style: TextStyle(
                                  color: PitchTheme.tertiaryFixed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.gateMode && Navigator.canPop(context))
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
              ],
            ),

            // -------------------------------------------------------------
            // BOTTOM SECTION: CLEAN AUTH ACTIONS
            // -------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Welcome to 60Score',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: PitchTheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to sync matches, player profile and tournaments across all your devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: PitchTheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Error Banner (Clean and Dismissible)
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: PitchTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PitchTheme.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: PitchTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: PitchTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _error = null),
                              child: const Icon(Icons.close_rounded, size: 16, color: PitchTheme.error),
                            ),
                          ],
                        ),
                      ),

                    // 1. SIGN IN WITH GOOGLE BUTTON (White Card Style with Official Google Colors)
                    InkWell(
                      onTap: _busy ? null : _signInWithGoogle,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: PitchTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PitchTheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _busy
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: PitchTheme.primary,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Official 4-color stylized Google 'G' icon
                                  _buildGoogleLogoBadge(),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Login with Google',
                                    style: TextStyle(
                                      color: PitchTheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Divider with "or"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: PitchTheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: PitchTheme.outline.withValues(alpha: 0.8),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: PitchTheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. EXPLORE AS GUEST BUTTON
                    InkWell(
                      onTap: _busy ? null : _exploreAsGuest,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: PitchTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PitchTheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 19,
                              color: PitchTheme.primary,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Explore as a Guest',
                              style: TextStyle(
                                color: PitchTheme.primary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Bottom offline badge notice
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: PitchTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.offline_pin_rounded,
                              size: 14,
                              color: PitchTheme.secondary,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '100% Offline-First Cricket Scoring',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: PitchTheme.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Official Google Colors G Badge
  Widget _buildGoogleLogoBadge() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'sans-serif'),
            children: [
              TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
            ],
          ),
        ),
      ),
    );
  }
}
