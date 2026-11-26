// 60Score Pitch Dynamic Home Dashboard Screen
// Faithfully modernized to match Stitch design & user specifications:
// - Modern sports telemetry palette (Pitch Dynamic: forest greens, emeralds, electric lime)
// - Centered "LIVE & RECENT MATCHES" badge
// - Horizontally scrollable match cards row (left-to-right)
// - STRICT responsive layout: no hardcoded widths/heights, dynamic clamping
// - Real data bindings to Store with realistic telemetry fallbacks
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/models/remote_match_summary.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/auth/user_code.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';
import 'package:cricket_scorer_app/views/screens/home/public_matches_screen.dart';
import 'package:cricket_scorer_app/views/screens/home/scorer_home_screen.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/match_setup_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';
import 'package:cricket_scorer_app/views/screens/teams/profile_screen.dart';
import 'package:cricket_scorer_app/views/screens/teams/teams_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournaments_screen.dart';
import 'package:cricket_scorer_app/views/widgets/app_logo.dart';
import 'package:cricket_scorer_app/core/constants/preset_team_logos.dart';
import 'package:cricket_scorer_app/services/sync/live_match_telemetry_hub.dart';

class HomeScreen extends StatefulWidget {
  final Store store;
  final VoidCallback onOpenDrawer;
  final ValueChanged<int> onSelectTab;
  final CpanelApiClient? apiClient;

  const HomeScreen({
    super.key,
    required this.store,
    required this.onOpenDrawer,
    required this.onSelectTab,
    this.apiClient,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _UnifiedMatchCardItem {
  final String id;
  final String? tournamentId;
  final String matchTitle;
  final String venue;
  final String status;
  final int oversLimit;
  final int ballsPerOver;
  final String resultText;
  final String creatorName;
  final int updatedAtEpoch;

  final String teamAId;
  final String teamBId;
  final String teamAName;
  final String teamBName;
  final String teamALogo;
  final String teamBLogo;
  final String teamACode;
  final String teamBCode;

  final String? teamARuns;
  final String? teamAOvers;
  final String? teamBRuns;
  final String? teamBOvers;

  final String? teamAScore;
  final String? teamBScore;
  final bool isTeamABatting;
  final bool isTeamBBatting;

  final String activeOversText;
  final double activeCrr;
  final double activeRrr;
  final int activeTarget;
  final bool canScore;

  final Match? localMatch;
  final RemoteMatchSummary? remoteSummary;

  const _UnifiedMatchCardItem({
    required this.id,
    this.tournamentId,
    required this.matchTitle,
    required this.venue,
    required this.status,
    required this.oversLimit,
    required this.ballsPerOver,
    required this.resultText,
    required this.creatorName,
    required this.updatedAtEpoch,
    required this.teamAId,
    required this.teamBId,
    required this.teamAName,
    required this.teamBName,
    this.teamALogo = '',
    this.teamBLogo = '',
    this.teamACode = '',
    this.teamBCode = '',
    this.teamARuns,
    this.teamAOvers,
    this.teamBRuns,
    this.teamBOvers,
    required this.teamAScore,
    required this.teamBScore,
    required this.isTeamABatting,
    required this.isTeamBBatting,
    required this.activeOversText,
    required this.activeCrr,
    this.activeRrr = 0.0,
    required this.activeTarget,
    required this.canScore,
    this.localMatch,
    this.remoteSummary,
  });

  bool get isLive => status == 'live';
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _kCachedFeedKey = 'score60_cached_live_feed_v1';

  Store get store => widget.store;

  // Filter state: 0 = All Feed, 1 = Live, 2 = Tournaments, 3 = Clubs & Teams
  int _activeFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<RemoteMatchSummary> _remoteLive = [];
  List<RemoteMatchSummary> _remoteRecent = [];
  List<Team> _remoteTeams = [];
  List<Player> _remotePlayers = [];
  List<Tournament> _remoteTournaments = [];
  bool _searchingRemote = false;
  bool _loadingFeed = false;
  bool _feedOffline = false;
  String? _openingRemoteId;
  Timer? _feedTimer;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStoreChanged);
    LiveMatchTelemetryHub.instance.addListener(_onStoreChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
        _triggerRemoteSearch(q);
      }
    });

    _loadCachedFeed();
    store.purgeOrphanTournamentMatches();
    _fetchLiveFeed(silent: true);
  }

  void _scheduleAdaptiveFeedTimer() {
    _feedTimer?.cancel();
    // Smoothness: poll every 12 seconds when matches are live, or 30 seconds when idle
    final intervalMs = _remoteLive.isNotEmpty ? 12000 : 30000;
    _feedTimer = Timer(Duration(milliseconds: intervalMs), () {
      if (mounted) {
        if (_searchQuery.isEmpty) {
          _fetchLiveFeed(silent: true);
        } else {
          _scheduleAdaptiveFeedTimer();
        }
      }
    });
  }

  bool _isFeedListEqual(List<RemoteMatchSummary> a, List<RemoteMatchSummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.status != y.status ||
          x.resultText != y.resultText ||
          x.updatedAtEpoch != y.updatedAtEpoch ||
          x.innings.length != y.innings.length) {
        return false;
      }
      for (var j = 0; j < x.innings.length; j++) {
        final ix = x.innings[j];
        final iy = y.innings[j];
        if (ix.totalRuns != iy.totalRuns ||
            ix.wickets != iy.wickets ||
            ix.legalBalls != iy.legalBalls ||
            ix.oversText != iy.oversText) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _feedTimer?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    store.removeListener(_onStoreChanged);
    LiveMatchTelemetryHub.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _triggerRemoteSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _remoteTeams = [];
          _remotePlayers = [];
          _remoteTournaments = [];
          _searchingRemote = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _searchingRemote = true);
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final q = query.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _searchingRemote = false);
        return;
      }
      try {
        final client = widget.apiClient ?? CpanelApiClient();
        if (widget.apiClient == null) await client.init();

        final resTeams = await client.searchTeams(q);
        final foundTeams = <Team>[];
        final foundPlayers = <Player>[];
        final foundTournaments = <Tournament>[];

        if (resTeams['status'] == 'success' && resTeams['data'] is List) {
          for (final item in (resTeams['data'] as List)) {
            if (item is Map) {
              final teamMap = Map<String, dynamic>.from(item);
              final t = Team(
                id: (teamMap['id'] ?? '').toString(),
                name: (teamMap['name'] ?? 'Team').toString(),
              );
              foundTeams.add(t);

              if (teamMap['players'] is List) {
                for (final pItem in (teamMap['players'] as List)) {
                  if (pItem is Map) {
                    final pm = Map<String, dynamic>.from(pItem);
                    foundPlayers.add(Player(
                      id: (pm['id'] ?? '').toString(),
                      name: (pm['name'] ?? 'Player').toString(),
                      jerseyNo: int.tryParse((pm['jersey_no'] ?? '0').toString()) ?? 0,
                      role: (pm['role'] ?? 'Batter').toString(),
                      userCode: (pm['user_code'] ?? '').toString(),
                      isVerified: pm['is_verified'] == 1 || pm['is_verified'] == true,
                    ));
                  }
                }
              }
            }
          }
        }

        // Also hit direct player search API
        final resPlayers = await client.searchPlayers(q);
        if (resPlayers['status'] == 'success' && resPlayers['data'] is List) {
          for (final item in (resPlayers['data'] as List)) {
            if (item is Map) {
              final pm = Map<String, dynamic>.from(item);
              final pId = (pm['id'] ?? '').toString();
              if (!foundPlayers.any((x) => x.id == pId)) {
                foundPlayers.add(Player(
                  id: pId,
                  name: (pm['name'] ?? 'Player').toString(),
                  jerseyNo: 0,
                  role: (pm['role'] ?? 'Batter').toString(),
                  userCode: (pm['user_code'] ?? '').toString(),
                  isVerified: pm['is_verified'] == 1 || pm['is_verified'] == true,
                ));
              }
            }
          }
        }

        // Hit tournament search API
        final resTournaments = await client.searchTournaments(q);
        if (resTournaments['status'] == 'success' && resTournaments['data'] is List) {
          for (final item in (resTournaments['data'] as List)) {
            if (item is Map) {
              final tm = Map<String, dynamic>.from(item);
              final payload = tm['payload'] is Map ? Map<String, dynamic>.from(tm['payload'] as Map) : null;
              if (payload != null && payload.isNotEmpty) {
                try {
                  foundTournaments.add(Tournament.fromJson(payload));
                  continue;
                } catch (_) {}
              }
              foundTournaments.add(Tournament(
                id: (tm['id'] ?? '').toString(),
                name: (tm['name'] ?? 'Tournament').toString(),
                venue: (tm['venue'] ?? '').toString(),
                format: (tm['format'] ?? 'Round Robin').toString(),
                creatorId: (tm['owner_uid'] ?? '').toString(),
                published: (tm['status'] ?? '') == 'published' || (tm['is_published'] ?? 0) == 1,
              ));
            }
          }
        }

        if (mounted && _searchQuery.isNotEmpty) {
          setState(() {
            _remoteTeams = foundTeams;
            _remotePlayers = foundPlayers;
            _remoteTournaments = foundTournaments;
            _searchingRemote = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searchingRemote = false);
      }
    });
  }

  Future<void> _loadCachedFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedFeedKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final liveList = ((decoded['live'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final recentList = ((decoded['recent'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _remoteLive = liveList;
        _remoteRecent = recentList;
      });
    } catch (_) {}
  }

  Future<void> _fetchLiveFeed({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loadingFeed = true);
    }
    try {
      final client = widget.apiClient ?? CpanelApiClient();
      if (widget.apiClient == null) {
        await client.init();
      }
      if (!silent && client.token != null && client.token!.isNotEmpty) {
        unawaited(() async {
          try {
            final syncService = CpanelSyncService(store: store, apiClient: client);
            final counts = await syncService.pullAndMerge();
            if (counts != null && mounted) {
              setState(() {});
            }
          } catch (_) {}
        }());
      }
      final res = await client.getMatchesFeed(limit: 15);
      if (!mounted) return;

      if (res['status'] == 'success' && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final liveList = ((data['live'] as List?) ?? [])
            .whereType<Map>()
            .map((e) =>
                RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
            .where((m) => m.id.isNotEmpty)
            .toList();
        final recentList = ((data['recent'] as List?) ?? [])
            .whereType<Map>()
            .map((e) =>
                RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
            .where((m) => m.id.isNotEmpty)
            .toList();

        final feedChanged = !_isFeedListEqual(_remoteLive, liveList) ||
            !_isFeedListEqual(_remoteRecent, recentList);

        if (feedChanged) {
          setState(() {
            _remoteLive = liveList;
            _remoteRecent = recentList;
            _loadingFeed = false;
            _feedOffline = false;
          });

          // Only write disk cache when data actually changed
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              _kCachedFeedKey,
              jsonEncode({
                'live': liveList.map((e) => e.toJson()).toList(),
                'recent': recentList.map((e) => e.toJson()).toList(),
              }),
            );
          } catch (_) {}
        } else {
          _loadingFeed = false;
          _feedOffline = false;
        }

        // Watch ALL active live matches (remote feed + local store + hub memory) in telemetry hub
        final allLiveIds = <String>{
          ...liveList.map((m) => m.id),
          ...store.matches.where((m) => m.status == 'live').map((m) => m.id),
          ...LiveMatchTelemetryHub.instance.allLiveMatches.where((m) => m.status == 'live').map((m) => m.id),
        }.where((id) => id.isNotEmpty).toList();

        if (allLiveIds.isNotEmpty) {
          LiveMatchTelemetryHub.instance.watchMatches(
            allLiveIds,
            store: store,
          );
        }
        _scheduleAdaptiveFeedTimer();
      } else {
        if (mounted) {
          setState(() {
            _loadingFeed = false;
            _feedOffline = true;
          });
        }
        _scheduleAdaptiveFeedTimer();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingFeed = false;
          _feedOffline = true;
        });
      }
      _scheduleAdaptiveFeedTimer();
    }
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // Real deduplicated count of live matches (local + remote server)
  int get _liveMatchCount {
    final ids = <String>{
      for (final m in store.matches)
        if (m.status == 'live') m.id,
      for (final rm in _remoteLive) rm.id,
    };
    return ids.length;
  }

  String _getUserDisplayName() {
    final auth = AuthService();
    if (auth.displayName.trim().isNotEmpty) {
      return auth.displayName.trim();
    }
    final localName = store.activeProfile.displayName.trim();
    if (localName.isNotEmpty && localName != 'Player') {
      return localName;
    }
    return AuthService().isRestrictedGuest ? 'Guest' : 'Player';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PitchTheme.surface,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Sticky Top Header with Brand, Search, Bell & Avatar
            _buildTopHeader(),

            // Scrollable Content with Pull-to-Refresh
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResultsView()
                  : RefreshIndicator(
                      color: PitchTheme.primary,
                      onRefresh: () => _fetchLiveFeed(silent: false),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Interactive Filter Bar
                            _buildFilterPills(),
                            const SizedBox(height: 18),

                            // SECTION 1: LIVE & RECENT MATCHES (Centered Badge + Horizontal Scroll)
                            _buildLiveRecentMatchesSection(),
                            const SizedBox(height: 22),

                            // SECTION 2: MY PROFILE QUICK ACCESS CARD
                            _buildProfileCard(),
                            const SizedBox(height: 22),

                            // SECTION 3: QUICK ACTIONS (Fast Start)
                            _buildQuickActionsSection(),
                            const SizedBox(height: 22),

                            // SECTION 4: ACTIVE TOURNAMENTS
                            _buildActiveTournamentsSection(),
                            const SizedBox(height: 22),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER: STUMPS Brand, Search bar, Notifications, Avatar
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader() {
    final userName = _getUserDisplayName();
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: PitchTheme.cardBg,
        border: const Border(
          bottom: BorderSide(
            color: PitchTheme.hairlineBorder,
            width: 0.9,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 60Score Brand Logo & Text
          GestureDetector(
            onTap: widget.onOpenDrawer,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(height: 34),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '60',
                      style: TextStyle(
                        color: PitchTheme.slateHeading,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      'Score',
                      style: TextStyle(
                        color: PitchTheme.sportsEmerald,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Search Field (Flexible responsive)
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PitchTheme.hairlineBorder,
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: PitchTheme.slateHeading,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search matches, teams, tournaments...',
                  hintStyle: const TextStyle(
                    color: PitchTheme.slateSubdued,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: PitchTheme.slateSubdued,
                    size: 19,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchingRemote)
                              const Padding(
                                padding: EdgeInsets.only(right: 6.0),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PitchTheme.sportsEmerald,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: PitchTheme.slateSubdued,
                              onPressed: () => _searchController.clear(),
                            ),
                          ],
                        )
                      : null,
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell with Indicator Dot
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No new notifications at this moment.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PitchTheme.hairlineBorder,
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: PitchTheme.slateHeading,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: PitchTheme.liveRed,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // User Profile Avatar
          InkWell(
            onTap: () => _push(ProfileScreen(store: store)),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PitchTheme.sportsEmeraldLight,
                border: Border.all(
                  color: PitchTheme.sportsEmerald.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  userInitial,
                  style: const TextStyle(
                    color: PitchTheme.sportsEmerald,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GLOBAL MULTI-CATEGORY SEARCH VIEW
  // ---------------------------------------------------------------------------
  Widget _buildSearchResultsView() {
    final query = _searchQuery.trim().toLowerCase();

    // 1. Matches (Local + Remote)
    final matchedMatches = store.matches.where((m) {
      final a = store.teamById(m.teamAId)?.name ?? 'Team A';
      final b = store.teamById(m.teamBId)?.name ?? 'Team B';
      return a.toLowerCase().contains(query) ||
          b.toLowerCase().contains(query) ||
          m.venue.toLowerCase().contains(query) ||
          m.id.toLowerCase().contains(query);
    }).toList();

    final allRemote = [..._remoteLive, ..._remoteRecent];
    final matchedRemote = allRemote.where((rm) {
      return rm.teamAName.toLowerCase().contains(query) ||
          rm.teamBName.toLowerCase().contains(query) ||
          rm.venue.toLowerCase().contains(query) ||
          rm.id.toLowerCase().contains(query);
    }).toList();

    // 2. Teams (by Name or TM-XXXXXX Code - Local + Remote)
    final localTeamIds = store.teams.map((t) => t.id).toSet();
    final matchedTeams = store.teams.where((t) {
      return t.name.toLowerCase().contains(query) ||
          t.teamCode.toLowerCase().contains(query) ||
          t.id.toLowerCase().contains(query);
    }).toList();

    for (final rt in _remoteTeams) {
      if (!localTeamIds.contains(rt.id)) {
        if (rt.name.toLowerCase().contains(query) ||
            rt.teamCode.toLowerCase().contains(query) ||
            rt.id.toLowerCase().contains(query)) {
          matchedTeams.add(rt);
        }
      }
    }

    // 3. Players (from regPlayers, all team squads, and match participants)
    final seenPlayerIds = <String>{};
    final matchedPlayers = <Player>[];
    final cleanQuery = query.replaceAll('-', '').replaceAll(' ', '');

    for (final reg in store.regPlayers) {
      if (seenPlayerIds.add(reg.id)) {
        final code = userCodeForUid(reg.id).toLowerCase();
        final cleanCode = code.replaceAll('-', '').replaceAll(' ', '');
        final id = reg.id.toLowerCase();
        final name = reg.name.toLowerCase();
        if (name.contains(query) ||
            code.contains(query) ||
            cleanCode.contains(cleanQuery) ||
            id.contains(query) ||
            (reg.jerseyNo > 0 && '${reg.jerseyNo}' == query)) {
          matchedPlayers.add(reg.toTeamPlayer());
        }
      }
    }
    for (final t in store.teams) {
      for (final p in t.players) {
        if (seenPlayerIds.add(p.id)) {
          final code = (p.userCode ?? userCodeForUid(p.id)).toLowerCase();
          final cleanCode = code.replaceAll('-', '').replaceAll(' ', '');
          final id = p.id.toLowerCase();
          final name = p.name.toLowerCase();
          if (name.contains(query) ||
              code.contains(query) ||
              cleanCode.contains(cleanQuery) ||
              id.contains(query) ||
              (p.jerseyNo > 0 && '${p.jerseyNo}' == query)) {
            matchedPlayers.add(p);
          }
        }
      }
    }
    // Also include any player who participated in recorded matches
    for (final m in store.matches) {
      final allPids = {...m.xiA, ...m.xiB};
      for (final inn in m.innings) {
        allPids.addAll(inn.batting.keys);
        allPids.addAll(inn.bowling.keys);
      }
      for (final pid in allPids) {
        if (seenPlayerIds.add(pid)) {
          final pName = store.playerName(pid).toLowerCase();
          final code = userCodeForUid(pid).toLowerCase();
          final cleanCode = code.replaceAll('-', '').replaceAll(' ', '');
          final id = pid.toLowerCase();
          if (pName.contains(query) ||
              code.contains(query) ||
              cleanCode.contains(cleanQuery) ||
              id.contains(query)) {
            matchedPlayers.add(store.findPlayer(pid) ??
                Player(
                  id: pid,
                  name: store.playerName(pid),
                  jerseyNo: 0,
                  userCode: userCodeForUid(pid),
                ));
          }
        }
      }
    }

    // Also include any remote players from live server
    for (final rp in _remotePlayers) {
      if (seenPlayerIds.add(rp.id)) {
        final pName = rp.name.toLowerCase();
        final code = (rp.userCode ?? userCodeForUid(rp.id)).toLowerCase();
        final cleanCode = code.replaceAll('-', '').replaceAll(' ', '');
        final id = rp.id.toLowerCase();
        if (pName.contains(query) ||
            code.contains(query) ||
            cleanCode.contains(cleanQuery) ||
            id.contains(query) ||
            (rp.jerseyNo > 0 && '${rp.jerseyNo}' == query)) {
          matchedPlayers.add(rp);
        }
      }
    }

    // 4. Tournaments (by Name, Venue or ID - Local + Remote)
    final localTournIds = store.tournaments.map((t) => t.id).toSet();
    final matchedTournaments = store.tournaments.where((t) {
      return t.name.toLowerCase().contains(query) ||
          t.venue.toLowerCase().contains(query) ||
          t.id.toLowerCase().contains(query);
    }).toList();

    for (final rt in _remoteTournaments) {
      if (!localTournIds.contains(rt.id)) {
        if (rt.name.toLowerCase().contains(query) ||
            rt.venue.toLowerCase().contains(query) ||
            rt.id.toLowerCase().contains(query)) {
          matchedTournaments.add(rt);
        }
      }
    }

    final totalResults = matchedMatches.length +
        matchedRemote.length +
        matchedTeams.length +
        matchedPlayers.length +
        matchedTournaments.length;

    if (totalResults == 0) {
      if (_searchingRemote) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
          child: Center(
            child: Column(
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: PitchTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Searching online for "$_searchQuery"...',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PitchTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Looking up players and teams in cloud database',
                  style: TextStyle(
                    fontSize: 12,
                    color: PitchTheme.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: PitchTheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: PitchTheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No results found for "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PitchTheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Search by Team Name, Team ID (TM-XXXXXX), Player Name, User Code (60S-XXXXXX), Match, or Tournament.',
                style: TextStyle(
                  fontSize: 12,
                  color: PitchTheme.outline,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Clear search'),
                onPressed: () => _searchController.clear(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PitchTheme.primary,
                  side: const BorderSide(color: PitchTheme.outlineVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Summary Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SEARCH RESULTS ($totalResults)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: PitchTheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () => _searchController.clear(),
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: PitchTheme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. TEAMS SECTION
          if (matchedTeams.isNotEmpty) ...[
            _buildSearchSectionHeader('TEAMS', matchedTeams.length, Icons.shield_rounded),
            const SizedBox(height: 8),
            ...matchedTeams.map((t) => _buildTeamSearchResultTile(t)),
            const SizedBox(height: 16),
          ],

          // 2. PLAYERS SECTION
          if (matchedPlayers.isNotEmpty) ...[
            _buildSearchSectionHeader('PLAYERS', matchedPlayers.length, Icons.person_rounded),
            const SizedBox(height: 8),
            ...matchedPlayers.map((p) => _buildPlayerSearchResultTile(p)),
            const SizedBox(height: 16),
          ],

          // 3. MATCHES SECTION
          if (matchedMatches.isNotEmpty || matchedRemote.isNotEmpty) ...[
            _buildSearchSectionHeader(
              'MATCHES',
              matchedMatches.length + matchedRemote.length,
              Icons.sports_cricket_rounded,
            ),
            const SizedBox(height: 8),
            ...matchedMatches.map((m) => _buildLocalMatchSearchResultTile(m)),
            ...matchedRemote.map((rm) => _buildRemoteMatchSearchResultTile(rm)),
            const SizedBox(height: 16),
          ],

          // 4. TOURNAMENTS SECTION
          if (matchedTournaments.isNotEmpty) ...[
            _buildSearchSectionHeader('TOURNAMENTS', matchedTournaments.length, Icons.emoji_events_rounded),
            const SizedBox(height: 8),
            ...matchedTournaments.map((tr) => _buildTournamentSearchResultTile(tr)),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSearchSectionHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PitchTheme.secondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: PitchTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: PitchTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSearchResultTile(Team t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: PitchTheme.primary,
          foregroundColor: Colors.white,
          radius: 18,
          child: Text(
            t.name.isEmpty ? '?' : t.name[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                t.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Text(
                t.teamCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: PitchTheme.secondary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${t.players.length} squad players',
          style: const TextStyle(fontSize: 11, color: PitchTheme.outline),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PitchTheme.outline),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamDetailScreen(store: store, team: t),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildPlayerSearchResultTile(Player p) {
    final code = p.userCode ?? (p.id.isNotEmpty ? p.id : '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: PitchTheme.sportsEmeraldLight,
          foregroundColor: PitchTheme.sportsEmerald,
          radius: 18,
          child: Text(
            p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (code.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: PitchTheme.outline,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${p.role} · ${p.battingStyle}',
          style: const TextStyle(fontSize: 11, color: PitchTheme.outline),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PitchTheme.outline),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                store: store,
                playerId: p.id,
                playerName: p.name,
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildLocalMatchSearchResultTile(Match m) {
    final a = store.teamById(m.teamAId)?.name ?? 'Team A';
    final b = store.teamById(m.teamBId)?.name ?? 'Team B';
    final isLive = m.status == 'live';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isLive ? PitchTheme.error.withValues(alpha: 0.1) : PitchTheme.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sports_cricket_rounded,
            size: 18,
            color: isLive ? PitchTheme.error : PitchTheme.primary,
          ),
        ),
        title: Text(
          '$a vs $b',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${isLive ? "🔴 LIVE" : m.status.toUpperCase()} · ${m.venue.isNotEmpty ? m.venue : "Local match"}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
            color: isLive ? PitchTheme.error : PitchTheme.outline,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PitchTheme.outline),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScorecardScreen(store: store, match: m),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildRemoteMatchSearchResultTile(RemoteMatchSummary rm) {
    final isLive = rm.isLive;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isLive ? PitchTheme.error.withValues(alpha: 0.1) : PitchTheme.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_outlined,
            size: 18,
            color: isLive ? PitchTheme.error : PitchTheme.secondary,
          ),
        ),
        title: Text(
          '${rm.teamAName} vs ${rm.teamBName}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${isLive ? "🔴 LIVE (SERVER)" : "RECENT (SERVER)"} · ${rm.venue}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
            color: isLive ? PitchTheme.error : PitchTheme.outline,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PitchTheme.outline),
        onTap: () => _openRemoteMatch(rm),
      ),
      ),
    );
  }

  Widget _buildTournamentSearchResultTile(Tournament tr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: const CircleAvatar(
          backgroundColor: PitchTheme.surfaceContainer,
          foregroundColor: PitchTheme.primary,
          radius: 18,
          child: Icon(Icons.emoji_events_rounded, size: 18),
        ),
        title: Text(
          tr.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${tr.teamIds.length} teams · ${tr.venue.isNotEmpty ? tr.venue : "Tournament"}',
          style: const TextStyle(fontSize: 11, color: PitchTheme.outline),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PitchTheme.outline),
        onTap: () {
          if (store.tournamentById(tr.id) == null) {
            store.tournaments.add(tr);
          }
          final activeTr = store.tournamentById(tr.id) ?? tr;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TournamentDetailScreen(store: store, tournament: activeTr),
            ),
          );
        },
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. FILTER PILLS: All Feed, Live, Tournaments, Clubs & Teams
  // ---------------------------------------------------------------------------
  Widget _buildFilterPills() {
    final filters = [
      {'label': 'ALL FEED', 'hasLiveDot': false},
      {'label': 'LIVE ($_liveMatchCount)', 'hasLiveDot': true},
      {'label': 'TOURNAMENTS', 'hasLiveDot': false},
      {'label': 'CLUBS & TEAMS', 'hasLiveDot': false},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(filters.length, (index) {
          final item = filters[index];
          final isActive = _activeFilter == index;
          final hasLive = item['hasLiveDot'] as bool;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => setState(() => _activeFilter = index),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 7.0,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? PitchTheme.sportsEmerald
                      : PitchTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? PitchTheme.sportsEmerald
                        : PitchTheme.hairlineBorder,
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.02),
                      blurRadius: isActive ? 6 : 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasLive) ...[
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) => Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : PitchTheme.liveRed
                                      .withValues(alpha: _pulseAnimation.value),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : PitchTheme.slateHeading,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SECTION 1: LIVE & RECENT MATCHES
  // Requirements:
  // - Badge properly centered in the middle (darmyan)
  // - Horizontally scrollable row from left to right
  // - Strictly responsive: flexible card widths without hardcoded rigidity
  // ---------------------------------------------------------------------------
  Widget _buildLiveRecentMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header Row: Title on Left, View All on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_activeFilter == 1 || _liveMatchCount > 0)
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: PitchTheme.liveRed
                              .withValues(alpha: _pulseAnimation.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.sports_cricket,
                      size: 15,
                      color: PitchTheme.sportsEmerald,
                    ),
                  ),
                Text(
                  _activeFilter == 1
                      ? 'LIVE MATCHES'
                      : _activeFilter == 2
                          ? 'TOURNAMENT MATCHES'
                          : _activeFilter == 3
                              ? 'CLUB & TEAM MATCHES'
                              : 'LIVE & RECENT MATCHES',
                  style: const TextStyle(
                    color: PitchTheme.slateHeading,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicMatchesScreen(
                      store: store,
                      apiClient: widget.apiClient,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 2.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'VIEW ALL',
                      style: TextStyle(
                        color: PitchTheme.sportsEmerald,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: PitchTheme.sportsEmerald,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontally Scrollable Match Cards Carousel (Left-to-Right)
        _buildMatchCardsCarousel(),
      ],
    );
  }

  Widget _buildMatchCardsCarousel() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.86).clamp(290.0, 360.0);

    bool matchesQuery(String a, String b, String title, String venue) {
      if (_searchQuery.isEmpty) return true;
      return a.toLowerCase().contains(_searchQuery) ||
          b.toLowerCase().contains(_searchQuery) ||
          title.toLowerCase().contains(_searchQuery) ||
          venue.toLowerCase().contains(_searchQuery);
    }

    final filter = _activeFilter;
    final liveOnly = filter == 1;
    final tournamentOnly = filter == 2;
    final clubsOnly = filter == 3;

    bool matchesFilter(_UnifiedMatchCardItem item) {
      if (liveOnly && !item.isLive) return false;
      final isTourn = item.tournamentId != null && item.tournamentId!.trim().isNotEmpty;
      if (tournamentOnly && !isTourn) return false;
      if (clubsOnly && isTourn) return false;
      return true;
    }

    // 1. Gather all unique live matches from local store, memory telemetry hub, and remote feed
    final liveMap = <String, _UnifiedMatchCardItem>{};

    for (final rm in _remoteLive) {
      if (matchesQuery(rm.teamAName, rm.teamBName, rm.matchTitle, rm.venue)) {
        liveMap[rm.id] = _resolveMatchItem(remote: rm);
      }
    }
    for (final m in LiveMatchTelemetryHub.instance.allLiveMatches) {
      if (m.status == 'live') {
        final a = store.teamName(m.teamAId);
        final b = store.teamName(m.teamBId);
        if (matchesQuery(a, b, m.matchTitle, m.venue)) {
          liveMap[m.id] = _resolveMatchItem(match: m, remote: liveMap[m.id]?.remoteSummary);
        }
      }
    }
    for (final m in store.matches) {
      if (m.status == 'live') {
        final a = store.teamById(m.teamAId)?.name ?? 'Team A';
        final b = store.teamById(m.teamBId)?.name ?? 'Team B';
        if (matchesQuery(a, b, m.matchTitle, m.venue)) {
          liveMap[m.id] = _resolveMatchItem(match: m, remote: liveMap[m.id]?.remoteSummary);
        }
      }
    }

    final liveItems = liveMap.values
        .where((i) => i.isLive && matchesFilter(i))
        .toList()
      ..sort((a, b) => b.updatedAtEpoch.compareTo(a.updatedAtEpoch));

    // 2. Gather completed / recent matches if not in live-only filter
    final completedMap = <String, _UnifiedMatchCardItem>{};
    if (!liveOnly) {
      for (final rm in _remoteRecent) {
        if (matchesQuery(rm.teamAName, rm.teamBName, rm.matchTitle, rm.venue)) {
          completedMap[rm.id] = _resolveMatchItem(remote: rm);
        }
      }
      for (final m in store.matches) {
        if (m.status == 'completed' || m.status == 'noResult') {
          final a = store.teamById(m.teamAId)?.name ?? 'Team A';
          final b = store.teamById(m.teamBId)?.name ?? 'Team B';
          if (matchesQuery(a, b, m.matchTitle, m.venue)) {
            completedMap[m.id] = _resolveMatchItem(match: m, remote: completedMap[m.id]?.remoteSummary);
          }
        }
      }
    }

    final completedItems = completedMap.values
        .where((i) => !liveMap.containsKey(i.id) && matchesFilter(i))
        .toList()
      ..sort((a, b) => b.updatedAtEpoch.compareTo(a.updatedAtEpoch));

    final displayItems = [...liveItems, ...completedItems];

    if (displayItems.isEmpty) {
      return _buildEmptyMatchesCard(cardWidth, activeFilter: filter);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in displayItems.take(20))
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildUnifiedMatchCard(item, cardWidth),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMatchesCard(double cardWidth, {int activeFilter = 0}) {
    final String emptyTitle;
    final String emptySubtitle;
    if (_loadingFeed) {
      emptyTitle = 'Fetching Matches...';
      emptySubtitle = 'Connecting to server feed...';
    } else if (activeFilter == 1) {
      emptyTitle = 'No Live Matches Right Now';
      emptySubtitle = _feedOffline
          ? 'Offline mode — live matches will appear here.'
          : 'Start scoring a live match or tap Refresh.';
    } else if (activeFilter == 2) {
      emptyTitle = 'No Tournament Matches Found';
      emptySubtitle = _feedOffline
          ? 'No local tournament matches recorded yet.'
          : 'Create or join a tournament to see scheduled matches.';
    } else if (activeFilter == 3) {
      emptyTitle = 'No Club & Team Matches Found';
      emptySubtitle = _feedOffline
          ? 'No local bilateral club matches recorded yet.'
          : 'Start a friendly or club match from Quick Actions.';
    } else {
      emptyTitle = 'No Live or Recent Matches';
      emptySubtitle = _feedOffline
          ? 'Offline mode — pull down to refresh when online.'
          : 'Start scoring a match or tap Refresh to check the server.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PitchTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PitchTheme.hairlineBorder,
          width: 0.9,
        ),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _loadingFeed
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: PitchTheme.sportsEmerald,
                    ),
                  )
                : Icon(
                    _feedOffline
                        ? Icons.cloud_off_outlined
                        : Icons.sports_cricket_outlined,
                    color: PitchTheme.sportsEmerald,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emptyTitle,
                  style: const TextStyle(
                    color: PitchTheme.slateHeading,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  emptySubtitle,
                  style: const TextStyle(
                    color: PitchTheme.slateSubdued,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _loadingFeed ? null : () => _fetchLiveFeed(silent: false),
            child: const Text(
              'Refresh',
              style: TextStyle(
                color: PitchTheme.sportsEmerald,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRemoteMatch(RemoteMatchSummary rm) async {
    final cachedM = LiveMatchTelemetryHub.instance.getLiveMatch(rm.id) ?? store.matchById(rm.id);
    if (cachedM != null && cachedM.innings.isNotEmpty) {
      final canScore = !AuthService().isRestrictedGuest &&
          cachedM.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);
      if (canScore && cachedM.status == 'live') {
        _push(ScoringScreen(store: store, match: cachedM));
      } else {
        _push(ScorecardScreen(store: store, match: cachedM, isScorer: false));
      }
      return;
    }

    if (_openingRemoteId != null) return;
    setState(() => _openingRemoteId = rm.id);

    try {
      final client = widget.apiClient ?? CpanelApiClient();
      if (widget.apiClient == null) {
        await client.init();
      }
      final res = await client.getMatchDetail(rm.id);
      if (!mounted) return;

      if (res['status'] != 'success' || res['data'] is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (res['message'] ?? 'Could not load match scorecard from server.')
                  .toString(),
            ),
          ),
        );
        return;
      }

      final data = Map<String, dynamic>.from(res['data'] as Map);
      final rawPayload = data['payload'];
      final matchMap = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{};
      if ((matchMap['id'] ?? '').toString().isEmpty) {
        matchMap['id'] = rm.id;
        matchMap['teamAId'] = rm.teamAId;
        matchMap['teamBId'] = rm.teamBId;
        matchMap['oversLimit'] = rm.oversLimit;
        matchMap['ballsPerOver'] = rm.ballsPerOver;
        matchMap['status'] = rm.status;
        matchMap['resultText'] = rm.resultText;
      }
      matchMap['creatorId'] = (matchMap['creatorId'] ?? '').toString().isNotEmpty
          ? matchMap['creatorId']
          : (data['creator_id'] ?? rm.creatorId);
      matchMap['creatorCode'] = (matchMap['creatorCode'] ?? '').toString().isNotEmpty
          ? matchMap['creatorCode']
          : (data['creator_code'] ?? rm.creatorCode);
      matchMap['creatorName'] = (matchMap['creatorName'] ?? '').toString().isNotEmpty
          ? matchMap['creatorName']
          : (data['creator_name'] ?? rm.creatorName);

      final remoteMatch = Match.fromJson(matchMap);

      final remoteTeams = <Team>[];
      final rawTeams = data['teams'];
      if (rawTeams is List) {
        for (final t in rawTeams) {
          if (t is Map) {
            try {
              remoteTeams.add(Team.fromJson(Map<String, dynamic>.from(t)));
            } catch (_) {}
          }
        }
      }
      if (!remoteTeams.any((t) => t.id == remoteMatch.teamAId) &&
          remoteMatch.teamAId.isNotEmpty) {
        remoteTeams.add(Team(id: remoteMatch.teamAId, name: rm.teamAName));
      }
      if (!remoteTeams.any((t) => t.id == remoteMatch.teamBId) &&
          remoteMatch.teamBId.isNotEmpty) {
        remoteTeams.add(Team(id: remoteMatch.teamBId, name: rm.teamBName));
      }

      final previewStore = Store.remotePreview(
        match: remoteMatch,
        teams: remoteTeams,
      );

      if (!mounted) return;
      _push(ScorecardScreen(store: previewStore, match: remoteMatch, isScorer: false));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offline or unable to open match: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingRemoteId = null);
    }
  }

  _UnifiedMatchCardItem _resolveMatchItem({Match? match, RemoteMatchSummary? remote}) {
    final mid = match?.id ?? remote!.id;
    final isScoringThis = LiveMatchTelemetryHub.instance.isActivelyScoring(mid);
    final freshM = isScoringThis
        ? (store.matchById(mid) ?? LiveMatchTelemetryHub.instance.getLiveMatch(mid) ?? match)
        : (LiveMatchTelemetryHub.instance.getLiveMatch(mid) ?? match ?? store.matchById(mid));
    final rm = remote;

    final id = freshM?.id ?? rm!.id;
    final tournamentId = freshM?.tournamentId ?? rm?.tournamentId;
    final matchTitle = (freshM?.matchTitle ?? rm?.matchTitle ?? '').trim();
    final venue = (freshM?.venue ?? rm?.venue ?? '').trim();
    final status = (freshM?.status ?? rm?.status ?? 'live').toLowerCase();
    final isLive = status == 'live';
    final oversLimit = freshM?.oversLimit ?? rm?.oversLimit ?? 20;
    final ballsPerOver = freshM?.ballsPerOver ?? rm?.ballsPerOver ?? 6;
    final resultText = (freshM?.resultText ?? rm?.resultText ?? '').trim();
    final creatorName = (freshM?.creatorName ?? rm?.creatorName ?? '').trim();

    final teamAId = (freshM?.teamAId ?? rm?.teamAId ?? '').trim();
    final teamBId = (freshM?.teamBId ?? rm?.teamBId ?? '').trim();

    String tAName = store.teamById(teamAId)?.name ?? '';
    if (tAName.isEmpty || tAName == 'Team A') {
      if (rm != null && rm.teamAName.isNotEmpty && rm.teamAName != 'Team A') {
        tAName = rm.teamAName;
      } else {
        tAName = tAName.isEmpty ? 'Team A' : tAName;
      }
    }

    String tBName = store.teamById(teamBId)?.name ?? '';
    if (tBName.isEmpty || tBName == 'Team B') {
      if (rm != null && rm.teamBName.isNotEmpty && rm.teamBName != 'Team B') {
        tBName = rm.teamBName;
      } else {
        tBName = tBName.isEmpty ? 'Team B' : tBName;
      }
    }

    bool isMatchForTeamA(String bId) {
      final clean = bId.trim();
      if (clean.isEmpty) return false;
      if (clean == teamAId) return true;
      if (tAName.isNotEmpty && clean.toLowerCase() == tAName.toLowerCase()) return true;
      final t = store.teamById(clean);
      if (t != null && (t.id == teamAId || (tAName.isNotEmpty && t.name.toLowerCase() == tAName.toLowerCase()))) {
        return true;
      }
      return false;
    }

    bool isMatchForTeamB(String bId) {
      final clean = bId.trim();
      if (clean.isEmpty) return false;
      if (clean == teamBId) return true;
      if (tBName.isNotEmpty && clean.toLowerCase() == tBName.toLowerCase()) return true;
      final t = store.teamById(clean);
      if (t != null && (t.id == teamBId || (tBName.isNotEmpty && t.name.toLowerCase() == tBName.toLowerCase()))) {
        return true;
      }
      return false;
    }

    int epoch = 0;
    if (freshM != null) {
      for (final inn in freshM.innings) {
        epoch += inn.events.length;
      }
    }
    if (rm != null) {
      epoch = max(epoch, rm.updatedAtEpoch);
    }

    String? teamAScore;
    String? teamBScore;
    bool isTeamABatting = false;
    bool isTeamBBatting = false;
    String activeOversText = '0.0';
    double activeCrr = 0.0;
    int activeTarget = 0;

    if (freshM != null && freshM.innings.isNotEmpty) {
      InningsState? innA;
      InningsState? innB;

      for (final inn in freshM.innings) {
        final bId = inn.battingTeamId.trim();
        if (isMatchForTeamA(bId) && innA == null) innA = inn;
        if (isMatchForTeamB(bId) && innB == null) innB = inn;
      }

      // Positional fallback ONLY if neither team was identified by battingTeamId:
      if (innA == null && innB == null) {
        final teamABatsFirst = freshM.battingFirstId.isNotEmpty
            ? (freshM.battingFirstId == teamAId || isMatchForTeamA(freshM.battingFirstId))
            : true;
        if (teamABatsFirst) {
          innA = freshM.innings[0];
          if (freshM.innings.length > 1) innB = freshM.innings[1];
        } else {
          innB = freshM.innings[0];
          if (freshM.innings.length > 1) innA = freshM.innings[1];
        }
      } else if (innA != null && innB == null && freshM.innings.length > 1) {
        innB = freshM.innings.firstWhere((i) => i != innA, orElse: () => freshM.innings[1]);
      } else if (innB != null && innA == null && freshM.innings.length > 1) {
        innA = freshM.innings.firstWhere((i) => i != innB, orElse: () => freshM.innings[0]);
      }

      final activeInn = freshM.innings.last;
      final activeBalls = activeInn.legalBalls;
      activeOversText = '${activeBalls ~/ ballsPerOver}.${activeBalls % ballsPerOver}';
      activeCrr = activeBalls > 0 ? (activeInn.totalRuns * ballsPerOver) / activeBalls : 0.0;
      activeTarget = activeInn.target;

      if (innA != null) {
        final b = innA.legalBalls;
        final ov = '${b ~/ ballsPerOver}.${b % ballsPerOver}';
        teamAScore = '${innA.totalRuns}/${innA.wickets} ($ov)';
      }
      if (innB != null) {
        final b = innB.legalBalls;
        final ov = '${b ~/ ballsPerOver}.${b % ballsPerOver}';
        teamBScore = '${innB.totalRuns}/${innB.wickets} ($ov)';
      }

      if (isLive) {
        final curBattingId = activeInn.battingTeamId.trim();
        if (curBattingId.isNotEmpty) {
          isTeamABatting = isMatchForTeamA(curBattingId);
          isTeamBBatting = isMatchForTeamB(curBattingId);
        } else if (activeInn == innA) {
          isTeamABatting = true;
          isTeamBBatting = false;
        } else if (activeInn == innB) {
          isTeamABatting = false;
          isTeamBBatting = true;
        } else {
          final teamABatsFirst = freshM.battingFirstId == teamAId;
          isTeamABatting = (freshM.innings.length == 1) ? teamABatsFirst : !teamABatsFirst;
          isTeamBBatting = (freshM.innings.length == 1) ? !teamABatsFirst : teamABatsFirst;
        }
      }
    } else if (rm != null && rm.innings.isNotEmpty) {
      InningsScoreSummary? innA;
      InningsScoreSummary? innB;

      for (final inn in rm.innings) {
        final bId = inn.battingTeamId.trim();
        if (isMatchForTeamA(bId) && innA == null) innA = inn;
        if (isMatchForTeamB(bId) && innB == null) innB = inn;
      }

      if (innA == null && innB == null) {
        if (rm.innings.length >= 2) {
          innA = rm.innings[0];
          innB = rm.innings[1];
        } else {
          final singleInn = rm.innings[0];
          if (singleInn.target > 0) {
            innB = singleInn;
          } else {
            innA = singleInn;
          }
        }
      } else if (innA != null && innB == null && rm.innings.length > 1) {
        innB = rm.innings.firstWhere((i) => i != innA, orElse: () => rm.innings[1]);
      } else if (innB != null && innA == null && rm.innings.length > 1) {
        innA = rm.innings.firstWhere((i) => i != innB, orElse: () => rm.innings[0]);
      }

      final activeInn = rm.innings.last;
      activeOversText = activeInn.oversText;
      activeCrr = activeInn.crr;
      activeTarget = activeInn.target;

      if (innA != null) {
        teamAScore = '${innA.totalRuns}/${innA.wickets} (${innA.oversText})';
      }
      if (innB != null) {
        teamBScore = '${innB.totalRuns}/${innB.wickets} (${innB.oversText})';
      }

      if (isLive) {
        final curBattingId = activeInn.battingTeamId.trim();
        if (curBattingId.isNotEmpty) {
          isTeamABatting = isMatchForTeamA(curBattingId);
          isTeamBBatting = isMatchForTeamB(curBattingId);
        } else if (activeInn == innA) {
          isTeamABatting = true;
          isTeamBBatting = false;
        } else if (activeInn == innB) {
          isTeamABatting = false;
          isTeamBBatting = true;
        } else {
          isTeamABatting = (rm.innings.length == 1);
          isTeamBBatting = (rm.innings.length > 1);
        }
      }
    }

    final canScore = freshM != null &&
        !AuthService().isRestrictedGuest &&
        freshM.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);

    // Compute team logos and codes from local store
    final tA = store.teamById(teamAId);
    final tB = store.teamById(teamBId);
    final logoA = tA?.logo ?? '';
    final logoB = tB?.logo ?? '';
    final codeA = tA?.displayCode ?? (tAName.length >= 2 ? tAName.substring(0, 2).toUpperCase() : tAName.toUpperCase());
    final codeB = tB?.displayCode ?? (tBName.length >= 2 ? tBName.substring(0, 2).toUpperCase() : tBName.toUpperCase());

    // Compute RRR if second innings running
    double rrr = 0.0;
    if (freshM != null && freshM.innings.length > 1 && activeTarget > 0) {
      final lastInn = freshM.innings.last;
      final runsNeeded = activeTarget - lastInn.totalRuns;
      final ballsLeft = (oversLimit * ballsPerOver) - lastInn.legalBalls;
      if (ballsLeft > 0 && runsNeeded > 0) {
        rrr = (runsNeeded * ballsPerOver) / ballsLeft;
      }
    }

    // Parse teamARuns/Overs for display
    String? aRuns;
    String? aOvers;
    String? bRuns;
    String? bOvers;
    if (teamAScore != null) {
      final m = RegExp(r'(\d+/\d+)\s*\(([^)]+)\)').firstMatch(teamAScore);
      if (m != null) { aRuns = m.group(1); aOvers = '(${m.group(2)})'; }
      else { aRuns = teamAScore; }
    }
    if (teamBScore != null) {
      final m = RegExp(r'(\d+/\d+)\s*\(([^)]+)\)').firstMatch(teamBScore);
      if (m != null) { bRuns = m.group(1); bOvers = '(${m.group(2)})'; }
      else { bRuns = teamBScore; }
    }

    return _UnifiedMatchCardItem(
      id: id,
      tournamentId: tournamentId,
      matchTitle: matchTitle,
      venue: venue,
      status: status,
      oversLimit: oversLimit,
      ballsPerOver: ballsPerOver,
      resultText: resultText,
      creatorName: creatorName,
      updatedAtEpoch: epoch,
      teamAId: teamAId,
      teamBId: teamBId,
      teamAName: tAName,
      teamBName: tBName,
      teamALogo: logoA,
      teamBLogo: logoB,
      teamACode: codeA,
      teamBCode: codeB,
      teamARuns: aRuns,
      teamAOvers: aOvers,
      teamBRuns: bRuns,
      teamBOvers: bOvers,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      isTeamABatting: isTeamABatting,
      isTeamBBatting: isTeamBBatting,
      activeOversText: activeOversText,
      activeCrr: activeCrr,
      activeRrr: rrr,
      activeTarget: activeTarget,
      canScore: canScore,
      localMatch: freshM,
      remoteSummary: rm,
    );
  }

  Widget _buildUnifiedMatchCard(_UnifiedMatchCardItem item, double cardWidth) {
    final isOpening = _openingRemoteId == item.id;

    // Build equation text for footer
    String footerText;
    if (item.isLive) {
      if (item.activeTarget > 0) {
        final runsNeeded = item.activeTarget - (int.tryParse(item.teamBRuns?.split('/').first ?? '0') ?? 0);
        final battingTeam = item.isTeamBBatting ? item.teamBName : item.teamAName;
        footerText = '$battingTeam need $runsNeeded runs'
            '${item.activeRrr > 0 ? ' • RRR ${item.activeRrr.toStringAsFixed(2)}' : ''}';
      } else {
        footerText = 'CRR ${item.activeCrr.toStringAsFixed(2)} • ${item.oversLimit} Overs';
      }
    } else {
      footerText = item.resultText.isNotEmpty ? item.resultText : 'Match Concluded';
    }

    // Tournament/series label
    String? tournamentLabel;
    if (item.tournamentId != null) {
      final t = store.tournamentById(item.tournamentId!);
      if (t != null && t.name.isNotEmpty) tournamentLabel = t.name;
    }
    tournamentLabel ??= item.matchTitle.isNotEmpty ? item.matchTitle : null;

    return InkWell(
      onTap: () {
        if (isOpening) return;
        if (item.canScore && item.isLive && item.localMatch != null) {
          _push(ScoringScreen(store: store, match: item.localMatch!));
        } else if (item.localMatch != null) {
          _push(ScorecardScreen(store: store, match: item.localMatch!, isScorer: item.canScore));
        } else if (item.remoteSummary != null) {
          _openRemoteMatch(item.remoteSummary!);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: cardWidth,
        child: Container(
          decoration: BoxDecoration(
            color: PitchTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PitchTheme.hairlineBorder, width: 0.9),
            boxShadow: PitchTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header: tournament label + status ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tournamentLabel ?? (item.oversLimit > 0 ? '${item.oversLimit} Overs Match' : 'Match'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PitchTheme.slateSubdued,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isOpening)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: PitchTheme.sportsEmerald),
                      ),
                  ],
                ),
              ),

              // ── 3-column showdown body ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT: Team A
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PresetTeamLogoBadge(
                                logoKey: item.teamALogo,
                                teamName: item.teamAName,
                                size: 36,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.teamACode,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: item.isTeamABatting ? FontWeight.w900 : FontWeight.w700,
                                        color: PitchTheme.slateHeading,
                                      ),
                                    ),
                                    if (item.teamARuns != null) ...[
                                      Text(
                                        item.teamARuns!,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: item.isTeamABatting
                                              ? PitchTheme.sportsEmerald
                                              : PitchTheme.slateHeading,
                                        ),
                                      ),
                                      if (item.teamAOvers != null)
                                        Text(
                                          item.teamAOvers!,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: PitchTheme.slateSubdued,
                                          ),
                                        ),
                                    ] else
                                      const Text(
                                        'Yet to bat',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: PitchTheme.slateSubdued,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // CENTER: Status badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(color: PitchTheme.hairlineBorder, width: 0.9),
                            ),
                            child: const Icon(
                              Icons.sports_cricket,
                              size: 18,
                              color: PitchTheme.sportsEmerald,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (item.isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: PitchTheme.liveRedBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: PitchTheme.liveRed.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RepaintBoundary(
                                    child: AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, _) => Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: PitchTheme.liveRed.withValues(alpha: _pulseAnimation.value),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: PitchTheme.liveRed,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: PitchTheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'FT',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: PitchTheme.slateSubdued,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // RIGHT: Team B
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item.teamBCode,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: item.isTeamBBatting ? FontWeight.w900 : FontWeight.w700,
                                        color: PitchTheme.slateHeading,
                                      ),
                                    ),
                                    if (item.teamBRuns != null) ...[
                                      Text(
                                        item.teamBRuns!,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: item.isTeamBBatting
                                              ? PitchTheme.sportsEmerald
                                              : PitchTheme.slateHeading,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                      if (item.teamBOvers != null)
                                        Text(
                                          item.teamBOvers!,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: PitchTheme.slateSubdued,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                    ] else
                                      const Text(
                                        'Yet to bat',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: PitchTheme.slateSubdued,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              PresetTeamLogoBadge(
                                logoKey: item.teamBLogo,
                                teamName: item.teamBName,
                                size: 36,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer: equation / result ──
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: PitchTheme.hairlineBorder, width: 0.9)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  footerText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: item.isLive ? PitchTheme.slateHeading : PitchTheme.slateSubdued,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }





  // ---------------------------------------------------------------------------
  // 4. SECTION 2: MY PROFILE QUICK ACCESS CARD
  // ---------------------------------------------------------------------------
  Widget _buildProfileCard() {
    final profile = store.activeProfile;
    final userName = profile.displayName.isNotEmpty ? profile.displayName : 'Player';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'P';
    final userCode = profile.userCode;
    final roleSummary = profile.roleSummary;

    String teamName = 'NO TEAM REGISTERED';
    for (final t in store.teams) {
      if (t.players.any((p) =>
          p.name.trim().toLowerCase() == userName.toLowerCase() ||
          p.id == profile.uid)) {
        teamName = t.name;
        break;
      }
    }
    if (teamName == 'NO TEAM REGISTERED' && store.teams.isNotEmpty) {
      teamName = store.teams.first.name;
    }

    return InkWell(
      onTap: () => _push(ProfileScreen(store: store)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PitchTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PitchTheme.hairlineBorder,
            width: 0.9,
          ),
          boxShadow: PitchTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar with green checkmark badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: PitchTheme.sportsEmeraldLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PitchTheme.sportsEmerald.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userInitial,
                          style: const TextStyle(
                            color: PitchTheme.sportsEmerald,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: PitchTheme.sportsEmerald,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name, PRO badge, Unique ID chip, role, team
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                color: PitchTheme.slateHeading,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: PitchTheme.sportsEmeraldLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: PitchTheme.sportsEmerald,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: PitchTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: PitchTheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              userCode,
                              style: const TextStyle(
                                color: PitchTheme.secondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleSummary,
                        style: const TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        teamName.toUpperCase(),
                        style: const TextStyle(
                          color: PitchTheme.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Profile CTA Button
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 9.0,
              ),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.sports_cricket,
                    color: PitchTheme.secondary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View Career Profile & Stats',
                      style: TextStyle(
                        color: PitchTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: PitchTheme.outline,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. SECTION 3: QUICK ACTIONS (Fast Start)
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: PitchTheme.slateSubdued,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                icon: Icons.sports_cricket,
                label: 'Create Match',
                sublabel: 'Start scoring now',
                gradient: const LinearGradient(
                  colors: [Color(0xFF047857), Color(0xFF064E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => _push(MatchSetupScreen(store: store)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                icon: Icons.emoji_events_rounded,
                label: 'Tournament',
                sublabel: 'Manage fixtures',
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFF78350F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => widget.onSelectTab(2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. SECTION 4: ACTIVE TOURNAMENTS
  // ---------------------------------------------------------------------------
  Widget _buildActiveTournamentsSection() {
    final uid = store.effectiveUserId;
    final userTournaments = store.tournaments.where((t) {
      if (t.creatorId.isEmpty) return true;
      return uid.isNotEmpty && t.creatorId == uid;
    }).toList();
    final activeCount = userTournaments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'ACTIVE TOURNAMENTS',
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: activeCount > 0
                        ? PitchTheme.secondaryContainer
                        : PitchTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeCount Active',
                    style: TextStyle(
                      color: activeCount > 0
                          ? PitchTheme.onSecondaryContainer
                          : PitchTheme.outline,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _push(TournamentsScreen(store: store)),
              child: const Text(
                'Explore →',
                style: TextStyle(
                  color: PitchTheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tournament Cards
        if (userTournaments.isNotEmpty)
          ...userTournaments.take(5).map((t) => _buildRealTournamentCard(t))
        else
          _buildEmptyTournamentsCard(),
      ],
    );
  }

  Widget _buildRealTournamentCard(Tournament t) {
    final matches =
        store.matches.where((m) => m.tournamentId == t.id).toList();
    final done = matches
        .where((m) => m.status == 'completed' || m.status == 'noResult')
        .length;
    final total = matches.isNotEmpty ? matches.length : 1;
    final pct = (done / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () => _push(TournamentDetailScreen(store: store, tournament: t)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PitchTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: PitchTheme.hairlineBorder,
              width: 0.9,
            ),
            boxShadow: PitchTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(
                              color: PitchTheme.slateHeading,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: PitchTheme.sportsEmeraldLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${t.oversLimit}O',
                            style: const TextStyle(
                              color: PitchTheme.sportsEmerald,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${t.teamIds.length} Teams Active • ${t.venue.isNotEmpty ? t.venue : 'League Phase'}',
                      style: const TextStyle(
                        color: PitchTheme.outline,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: $done/${matches.length} Matches',
                          style: const TextStyle(
                            color: PitchTheme.onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toInt()}%',
                          style: const TextStyle(
                            color: PitchTheme.secondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: PitchTheme.surfaceContainer,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          PitchTheme.secondary,
                        ),
                        minHeight: 4,
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

  Widget _buildEmptyTournamentsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PitchTheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: PitchTheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_outlined,
                color: PitchTheme.secondary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No Tournaments Created Yet',
            style: TextStyle(
              color: PitchTheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Create your own tournament to manage teams, fixtures, and points table.',
            style: TextStyle(
              color: PitchTheme.outline,
              fontSize: 11.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _push(TournamentsScreen(store: store)),
            icon: const Icon(
              Icons.add,
              size: 16,
              color: PitchTheme.surfaceContainerLowest,
            ),
            label: const Text(
              'Create Tournament',
              style: TextStyle(
                color: PitchTheme.surfaceContainerLowest,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PitchTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }


}
