// 60Score — offline cricket scorer for the Super Sixty League.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/services/storage/store.dart';

import 'package:cricket_scorer_app/core/theme/theme.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

import 'package:cricket_scorer_app/services/auth/auth_service.dart';

import 'package:cricket_scorer_app/services/backup/backup_service.dart';

import 'package:cricket_scorer_app/core/utils/debug_info.dart';

import 'package:cricket_scorer_app/core/utils/nav_memory.dart';

import 'package:cricket_scorer_app/views/screens/home/home_screen.dart';

import 'package:cricket_scorer_app/views/screens/home/login_screen.dart';

import 'package:cricket_scorer_app/views/screens/home/profile_setup_screen.dart';

import 'package:cricket_scorer_app/views/screens/teams/profile_screen.dart';

import 'package:cricket_scorer_app/views/screens/scoring/match_setup_screen.dart';

import 'package:cricket_scorer_app/views/screens/tournament/published_search_screen.dart';

import 'package:cricket_scorer_app/views/screens/home/scorer_home_screen.dart';

import 'package:cricket_scorer_app/views/screens/tournament/tournaments_screen.dart';

import 'package:cricket_scorer_app/views/screens/teams/stats_screen.dart';

import 'package:cricket_scorer_app/views/screens/teams/teams_screen.dart';

import 'package:cricket_scorer_app/views/screens/home/settings_screen.dart';

import 'package:cricket_scorer_app/views/screens/home/about_screen.dart';

import 'package:cricket_scorer_app/views/screens/draft/draft_screen.dart';

import 'package:cricket_scorer_app/views/screens/tournament/fixture_detail_screen.dart';

import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';

import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';

import 'package:cricket_scorer_app/views/widgets/app_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Debug info (v1.4.3): record the latest error for the debug

  // screen. Crash behavior itself is unchanged (see debug_info).

  DebugInfo.installHooks();

  // Fire-and-forget: falls back to offline mode when Firebase is not set up.

  AuthService().init();

  runApp(const Score60App());
}

class Score60App extends StatelessWidget {
  const Score60App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '60Score',

      debugShowCheckedModeBanner: false,

      theme: buildScore60Theme(),

      home: const SplashGate(),
    );
  }
}

/// Splash (old style, per Dazy): logo, big app name, loading spinner and

/// then the app shell once local data is loaded.

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with WidgetsBindingObserver {
  final Store store = Store();

  bool _ready = false;

  bool _wasGate = false;

  // Recents resume (v1.4.5): loaded once at boot, before the shell

  // builds, so a cold start can restore the last inner screen.

  NavRestore? _restore;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // v1.4.4 light version: returning to the app NO LONGER re-syncs

    // on its own (the v1.3.4 resume hook is gone). There is no sync

    // at all anymore (scoring close is local-only, manual sync is

    // removed), so a foreground return costs no network and cannot

    // pull remote data over local work. The observer registration

    // stays (the mixin is still declared); it simply has no sync

    // work now.
  }

  Future<void> _boot() async {
    final minSplash = Future.delayed(const Duration(milliseconds: 1400));

    try {
      // Settle Firebase auth FIRST (bounded): which identity's data

      // loads depends on who — if anyone — is signed in on this device.

      await AuthService().waitReady(const Duration(seconds: 2));

      final auth = AuthService();

      if (auth.isLoggedIn) {
        final cu = auth.cpanelUser;
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
          if (cu.pendingOnboardingSync) {
            // Fire-and-forget retry when device comes online
            unawaited(auth.syncPendingOnboardingIfNeeded());
          }
          // Non-blocking online check: auto sign-out if banned or deleted in Admin
          unawaited(auth.verifySessionWithServer());
        } else if (auth.currentUser != null) {
          final user = auth.currentUser!;
          await store.activateAccount(
            user.uid,
            email: user.email,
            displayName: user.displayName,
            phoneNumber: user.phoneNumber,
          );
        }
      } else {
        await store.activateIdentity('guest');
      }

      // Daily automatic backup (keeps last 14) — fire and forget.

      runDailyAutoBackup(store);
    } catch (_) {
      // Launch hardening: a failure during boot (corrupt local

      // data, a failing identity switch) must never leave the app

      // stuck on the splash screen — the "app won't open at all"

      // symptom. Fall back to whatever is loaded (possibly empty)

      // and still enter the app; sync runs at scoring close or

      // manually (no auto retry on resume anymore).

      try {
        if (!store.loaded) await store.activateIdentity('guest');
      } catch (_) {}
    }

    // Recents resume: read the saved destination AFTER the store is

    // loaded (its existence is checked against loaded data at

    // restore time, so a stale record safely falls back to home).

    _restore = await NavMemory.load();

    await minSplash;

    if (!mounted) return;

    setState(() => _ready = true);
  }

  /// The login gate appears only when Firebase is live, nobody is

  /// signed in, and this device has not chosen Guest mode. When

  /// Firebase failed to initialize (offline first run, unconfigured

  /// build) the gate never appears — the guest path is always open.

  bool _gateNeeded() {
    final auth = AuthService();

    if (auth.isLoggedIn) return false;

    if (auth.guestMode) return false;

    return true;
  }

  void _onGatePassed() {}

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _SplashView();
    }

    // The gate is derived LIVE from auth state: Google log-in -> optional
    // first-time onboarding -> HomeShell, or Guest (view-only) choice.

    return AnimatedBuilder(
      animation: AuthService(),

      builder: (context, _) {
        final auth = AuthService();
        if (_gateNeeded()) {
          _wasGate = true;

          return LoginScreen(
            store: store,

            gateMode: true,

            onGatePassed: _onGatePassed,
          );
        }

        if (auth.needsOnboarding) {
          return ProfileSetupScreen(
            store: store,
            gateMode: true,
            onCompleted: _onGatePassed,
          );
        }

        if (_wasGate) {
          _wasGate = false;
        }

        return AnimatedBuilder(
          animation: store,

          builder: (context, _) => HomeShell(store: store, restore: _restore),
        );
      },
    );
  }
}

/// Redesigned modern Pitch Dynamic splash screen for 60Score (SixtyScore).

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _fadeIn;

  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,

      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,

        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A12),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,

            colors: [Color(0xFF001811), Color(0xFF00261B), Color(0xFF063324)],
          ),
        ),

        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background pitch radial glow
              Center(
                child: Container(
                  width: 320,

                  height: 320,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    gradient: RadialGradient(
                      colors: [
                        PitchTheme.secondary.withValues(alpha: 0.16),

                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main animated brand content
              Center(
                child: FadeTransition(
                  opacity: _fadeIn,

                  child: ScaleTransition(
                    scale: _scale,

                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          // 60Score Illuminated Brand Emblem
                          Container(
                            width: 104,

                            height: 104,

                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,

                                end: Alignment.bottomRight,

                                colors: [Color(0xFF0D4735), Color(0xFF00261B)],
                              ),

                              borderRadius: BorderRadius.circular(28),

                              border: Border.all(
                                color: PitchTheme.secondary.withValues(
                                  alpha: 0.45,
                                ),

                                width: 1.5,
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: PitchTheme.secondary.withValues(
                                    alpha: 0.30,
                                  ),

                                  blurRadius: 32,

                                  spreadRadius: 2,

                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),

                            child: const Center(child: AppLogo(height: 72)),
                          ),
                          const SizedBox(height: 26),

                          // Brand Title: 60SCORE
                          const Text(
                            '60SCORE',

                            style: TextStyle(
                              color: Colors.white,

                              fontSize: 34,

                              fontWeight: FontWeight.w900,

                              letterSpacing: 4.0,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Brand Sub-title: SIXTY SCORE
                          const Text(
                            'SIXTY SCORE',

                            style: TextStyle(
                              color: PitchTheme.tertiaryFixed,

                              fontSize: 11,

                              fontWeight: FontWeight.w800,

                              letterSpacing: 5.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Tagline pill container
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,

                              vertical: 6,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),

                              borderRadius: BorderRadius.circular(20),

                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),

                            child: const Text(
                              'CRICKET SCORING, SIMPLIFIED',

                              style: TextStyle(
                                fontSize: 11,

                                letterSpacing: 2.0,

                                fontWeight: FontWeight.w700,

                                color: Colors.white70,
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Sleek telemetry progress line
                          SizedBox(
                            width: 140,

                            height: 3,

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),

                              child: const LinearProgressIndicator(
                                backgroundColor: Colors.white10,

                                valueColor: AlwaysStoppedAnimation<Color>(
                                  PitchTheme.tertiaryFixed,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'INITIALIZING ENGINE...',

                            style: TextStyle(
                              color: Colors.white38,

                              fontSize: 9.5,

                              fontWeight: FontWeight.w700,

                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom telemetry & version (NO DEVELOPER DETAILS)
              Positioned(
                left: 0,

                right: 0,

                bottom: 24,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Container(
                          width: 6,

                          height: 6,

                          decoration: const BoxDecoration(
                            color: PitchTheme.tertiaryFixed,

                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 8),

                        const Text(
                          'OFFLINE-FIRST CRICKET',

                          style: TextStyle(
                            fontSize: 11,

                            fontWeight: FontWeight.w800,

                            letterSpacing: 2.2,

                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'v1.4.9',

                      style: TextStyle(
                        fontSize: 10,

                        fontWeight: FontWeight.w600,

                        letterSpacing: 1.0,

                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App shell: bottom navigation (Home / Matches / New Match / Statistics /

/// More) plus a half-width side drawer. New Match pushes the setup screen

/// without changing tabs; More opens the drawer.

class HomeShell extends StatefulWidget {
  final Store store;

  // Recents resume (v1.4.5): the destination saved at boot, if any.

  // Null means a normal cold start (fresh install / no prior

  // context / record already cleared) → home, as before.

  final NavRestore? restore;

  const HomeShell({super.key, required this.store, this.restore});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _navIndex =
      0; // 0 Home, 1 Matches, 2 New Match (action), 3 Statistics, 4 More (action)

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Store get store => widget.store;

  @override
  void initState() {
    super.initState();

    final r = widget.restore;

    if (r != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restore(r));
    }
  }

  /// Recents resume: push the saved inner screen when its record

  /// still exists in the loaded store. A stale record (deleted

  /// match/tournament, or a status that no longer fits the screen)

  /// falls back to home — never a crash, never a blank screen.

  /// Match routing mirrors _openFixture: live → scoring,

  /// completed → scorecard, anything else → fixture detail.

  void _restore(NavRestore r) {
    if (!mounted) return;

    Widget? page;

    switch (r.kind) {
      case 'tournament':
        final t = store.tournamentById(r.id);

        if (t != null) {
          page = TournamentDetailScreen(store: store, tournament: t);
        }

      case 'scoring':
      case 'scorecard':
      case 'fixture':
        final m = store.matchById(r.id);

        if (m != null) {
          if (m.status == 'live') {
            final canScore = m.canUserScore(
              store.effectiveUserId,
              userCode: store.effectiveUserCode,
            );
            page = canScore
                ? ScoringScreen(store: store, match: m)
                : ScorecardScreen(store: store, match: m);
          } else if (m.status == 'completed') {
            page = ScorecardScreen(store: store, match: m);
          } else {
            page = FixtureDetailScreen(store: store, matchId: m.id);
          }
        }
    }

    final target = page;

    if (target == null || !mounted) return;

    Navigator.push(context, MaterialPageRoute(builder: (_) => target));
  }

  /// Bottom-nav index -> IndexedStack page index.

  int get _pageIndex => _navIndex == 3 ? 2 : _navIndex;

  void _onNavTap(int i) {
    if (i == 2) {
      // New Match: push the setup screen, keep the current tab selected.

      Navigator.push(
        context,

        MaterialPageRoute(builder: (_) => MatchSetupScreen(store: store)),
      );

      return;
    }

    if (i == 4) {
      _scaffoldKey.currentState?.openDrawer();

      return;
    }

    setState(() => _navIndex = i);
  }

  void _closeDrawerAndGoTab(int navIndex) {
    Navigator.pop(context);

    setState(() => _navIndex = navIndex);
  }

  void _closeDrawerAndPush(Widget page) {
    Navigator.pop(context);

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // Back navigation (v1.4.5): tab switches are state, not routes,

    // so Back from the Matches/Statistics tabs used to exit the app

    // outright. Now Back from a non-home tab returns to the Home tab,

    // and only Back from the Home tab exits. Pushed routes

    // (tournament detail, fixture, scoring, ...) pop normally above

    // this — this scope only governs the shell route itself, and

    // dialogs/drawer (routes on top) still close first by default.

    // No double-tap-to-exit, no new confirm dialogs.

    return PopScope(
      canPop: _navIndex == 0,

      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) setState(() => _navIndex = 0);
      },

      child: Scaffold(
        key: _scaffoldKey,

        drawer: _buildDrawer(),

        body: IndexedStack(
          index: _pageIndex,

          children: [
            HomeScreen(
              store: store,

              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),

              onSelectTab: _onNavTap,
            ),

            ScorerHomeScreen(
              store: store,

              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            StatsScreen(
              store: store,

              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ],
        ),

        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  /// Custom bottom bar: Home | Matches | (gold + circle) | Statistics | More.

  /// Index contract (shared with HomeScreen.onSelectTab):

  /// 0 Home, 1 Matches, 2 New Match (action), 3 Statistics, 4 More (drawer).

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,

        border: Border(
          top: BorderSide(
            color: PitchTheme.outlineVariant.withValues(alpha: 0.4),

            width: 1,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),

            blurRadius: 10,

            offset: const Offset(0, -2),
          ),
        ],
      ),

      child: SafeArea(
        top: false,

        child: SizedBox(
          height: 66,

          child: Row(
            children: [
              _navBtn(0, Icons.home_outlined, Icons.home, 'Home'),

              _navBtn(
                1,

                Icons.sports_cricket_outlined,

                Icons.sports_cricket,

                'Matches',
              ),

              Expanded(
                child: InkWell(
                  onTap: () => _onNavTap(2),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Transform.translate(
                        offset: const Offset(0, -4),

                        child: Container(
                          width: 42,

                          height: 42,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: PitchTheme.primary,

                            border: Border.all(
                              color: PitchTheme.primaryContainer,

                              width: 2,
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: PitchTheme.primary.withValues(
                                  alpha: 0.35,
                                ),

                                blurRadius: 10,

                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),

                          child: const Icon(
                            Icons.add,

                            color: PitchTheme.tertiaryFixed,

                            size: 24,
                          ),
                        ),
                      ),

                      const Text(
                        'New Match',

                        style: TextStyle(
                          color: PitchTheme.outline,

                          fontSize: 10,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _navBtn(
                3,

                Icons.bar_chart_outlined,

                Icons.bar_chart,

                'Statistics',
              ),

              _navBtn(4, Icons.menu, Icons.menu, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(int index, IconData icon, IconData activeIcon, String label) {
    final active = _navIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavTap(index),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              active ? activeIcon : icon,

              color: active ? PitchTheme.secondary : PitchTheme.outline,

              size: 23,
            ),

            const SizedBox(height: 2),

            Text(
              label,

              style: TextStyle(
                color: active ? PitchTheme.secondary : PitchTheme.outline,

                fontSize: 10.5,

                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sidebar per the approved reference:

  /// Home, Tournaments, Teams & Players, Drafting, Statistics,

  /// Settings, About 60Score — plus Search Tournaments (v1.3.0,

  /// public published-tournament search / follow).

  Widget _buildDrawer() {
    return Drawer(
      width: math.min(320.0, MediaQuery.of(context).size.width * 0.82),

      backgroundColor: PitchTheme.surfaceContainerLowest,

      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const AppLogo(height: 56),

                        const SizedBox(height: 10),

                        const Text(
                          '60Score',

                          style: TextStyle(
                            color: PitchTheme.primary,

                            fontSize: 24,

                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        Text(
                          'Cricket Scoring, Simplified.',

                          style: TextStyle(
                            color: PitchTheme.outline,

                            fontSize: 12,

                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Close',

                    icon: const Icon(Icons.close, color: PitchTheme.primary),

                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: PitchTheme.surfaceContainerLow),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),

                children: [
                  _drawerCard(
                    icon: Icons.home_rounded,

                    label: 'Home',

                    selected: _navIndex == 0,

                    onTap: () => _closeDrawerAndGoTab(0),
                  ),

                  _drawerCard(
                    icon: Icons.emoji_events_rounded,

                    label: 'Tournaments',

                    onTap: () =>
                        _closeDrawerAndPush(TournamentsScreen(store: store)),
                  ),

                  _drawerCard(
                    icon: Icons.search_rounded,

                    label: 'Search Tournaments',

                    onTap: () =>
                        _closeDrawerAndPush(const PublishedSearchScreen()),
                  ),

                  _drawerCard(
                    icon: Icons.groups_rounded,

                    label: 'Teams & Players',

                    onTap: () => _closeDrawerAndPush(TeamsScreen(store: store)),
                  ),

                  _drawerCard(
                    icon: Icons.edit_note_rounded,

                    label: 'Drafting',

                    onTap: () =>
                        _closeDrawerAndPush(DraftListScreen(store: store)),
                  ),

                  _drawerCard(
                    icon: Icons.bar_chart_rounded,

                    label: 'Statistics',

                    selected: _navIndex == 3,

                    onTap: () => _closeDrawerAndGoTab(3),
                  ),

                  _drawerCard(
                    icon: Icons.account_circle_rounded,

                    label: 'My Profile',

                    onTap: () =>
                        _closeDrawerAndPush(ProfileScreen(store: store)),
                  ),

                  const Divider(
                    height: 24,
                    color: PitchTheme.surfaceContainerLow,
                  ),

                  _drawerCard(
                    icon: Icons.settings_rounded,

                    label: 'Settings',

                    onTap: () =>
                        _closeDrawerAndPush(SettingsScreen(store: store)),
                  ),

                  _drawerCard(
                    icon: Icons.info_outline_rounded,

                    label: 'About 60Score',

                    onTap: () => _closeDrawerAndPush(const AboutScreen()),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),

              child: Text(
                'Version 1.3.4',

                textAlign: TextAlign.center,

                style: TextStyle(
                  color: PitchTheme.outline,

                  fontSize: 11,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerCard({
    required IconData icon,

    required String label,

    required VoidCallback onTap,

    bool selected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),

      decoration: BoxDecoration(
        color: selected
            ? PitchTheme.secondaryContainer.withValues(alpha: 0.35)
            : PitchTheme.surfaceContainerLowest,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: selected
              ? PitchTheme.secondary
              : PitchTheme.surfaceContainerLow,
        ),
      ),

      child: ListTile(
        dense: true,

        leading: Icon(
          icon,

          color: selected
              ? PitchTheme.onSecondaryContainer
              : PitchTheme.primary,

          size: 22,
        ),

        title: Text(
          label,

          style: TextStyle(
            color: selected
                ? PitchTheme.onSecondaryContainer
                : PitchTheme.onSurface,

            fontSize: 14,

            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),

        trailing: Icon(
          Icons.chevron_right_rounded,

          size: 20,

          color: selected
              ? PitchTheme.onSecondaryContainer
              : PitchTheme.outline,
        ),

        onTap: onTap,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
