import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/models/remote_match_summary.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';
import 'package:cricket_scorer_app/views/widgets/broadcast_match_card.dart';

class PublicMatchesScreen extends StatefulWidget {
  final Store store;
  final CpanelApiClient? apiClient;

  const PublicMatchesScreen({
    super.key,
    required this.store,
    this.apiClient,
  });

  @override
  State<PublicMatchesScreen> createState() => _PublicMatchesScreenState();
}

class _PublicMatchesScreenState extends State<PublicMatchesScreen>
    with SingleTickerProviderStateMixin {
  Store get store => widget.store;

  // 0: All, 1: Live, 2: Completed
  int _selectedTab = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<RemoteMatchSummary> _remoteLive = [];
  List<RemoteMatchSummary> _remoteRecent = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _openingMatchId;
  Timer? _pollingTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String _kCachedPublicFeedKey = 'score60_cached_public_matches_feed';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadCachedFeed();
    _fetchMatches(silent: false);

    // Periodic live feed refresh every 12 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _fetchMatches(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCachedFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCachedPublicFeedKey);
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final liveList = ((decoded['live'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final recentList = ((decoded['recent'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _remoteLive = liveList;
            _remoteRecent = recentList;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchMatches({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final client = widget.apiClient ?? CpanelApiClient();
      if (widget.apiClient == null) {
        await client.init();
      }
      final res = await client.getMatchesFeed(limit: 50);
      if (!mounted) return;

      if (res['status'] == 'success' && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final liveList = ((data['live'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
            .where((m) => m.id.isNotEmpty)
            .toList();
        final recentList = ((data['recent'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => RemoteMatchSummary.fromJson(Map<String, dynamic>.from(e)))
            .where((m) => m.id.isNotEmpty)
            .toList();

        setState(() {
          _remoteLive = liveList;
          _remoteRecent = recentList;
          _isLoading = false;
          _isOffline = false;
        });

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _kCachedPublicFeedKey,
            jsonEncode({
              'live': liveList.map((e) => e.toJson()).toList(),
              'recent': recentList.map((e) => e.toJson()).toList(),
            }),
          );
        } catch (_) {}
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOffline = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  Future<void> _openMatch(dynamic matchItem) async {
    if (_openingMatchId != null) return;

    if (matchItem is Match) {
      final canScore = !AuthService().isRestrictedGuest &&
          matchItem.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);

      if (matchItem.status == 'live') {
        if (canScore) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScoringScreen(store: store, match: matchItem),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScorecardScreen(store: store, match: matchItem, isScorer: false),
            ),
          );
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScorecardScreen(store: store, match: matchItem, isScorer: canScore),
          ),
        );
      }
      return;
    }

    if (matchItem is RemoteMatchSummary) {
      setState(() => _openingMatchId = matchItem.id);
      try {
        final client = widget.apiClient ?? CpanelApiClient();
        if (widget.apiClient == null) {
          await client.init();
        }
        final res = await client.getMatchDetail(matchItem.id);
        if (!mounted) return;

        if (res['status'] != 'success' || res['data'] is! Map) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Could not load match detail.'),
              backgroundColor: PitchTheme.error,
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
          matchMap['id'] = matchItem.id;
          matchMap['teamAId'] = matchItem.teamAId;
          matchMap['teamBId'] = matchItem.teamBId;
          matchMap['oversLimit'] = matchItem.oversLimit;
          matchMap['ballsPerOver'] = matchItem.ballsPerOver;
          matchMap['status'] = matchItem.status;
          matchMap['resultText'] = matchItem.resultText;
        }

        matchMap['creatorId'] = (matchMap['creatorId'] ?? '').toString().isNotEmpty
            ? matchMap['creatorId']
            : (data['creator_id'] ?? matchItem.creatorId);
        matchMap['creatorCode'] = (matchMap['creatorCode'] ?? '').toString().isNotEmpty
            ? matchMap['creatorCode']
            : (data['creator_code'] ?? matchItem.creatorCode);
        matchMap['creatorName'] = (matchMap['creatorName'] ?? '').toString().isNotEmpty
            ? matchMap['creatorName']
            : (data['creator_name'] ?? matchItem.creatorName);

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
          remoteTeams.add(Team(id: remoteMatch.teamAId, name: matchItem.teamAName));
        }
        if (!remoteTeams.any((t) => t.id == remoteMatch.teamBId) &&
            remoteMatch.teamBId.isNotEmpty) {
          remoteTeams.add(Team(id: remoteMatch.teamBId, name: matchItem.teamBName));
        }

        final previewStore = Store.remotePreview(
          match: remoteMatch,
          teams: remoteTeams,
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScorecardScreen(
              store: previewStore,
              match: remoteMatch,
              isScorer: false, // Strictly spectator view
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offline or unable to open match: $e'),
              backgroundColor: PitchTheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _openingMatchId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    bool matchesSearch(String teamA, String teamB, String title, String venue) {
      if (query.isEmpty) return true;
      return teamA.toLowerCase().contains(query) ||
          teamB.toLowerCase().contains(query) ||
          title.toLowerCase().contains(query) ||
          venue.toLowerCase().contains(query);
    }

    // 1. Gather local matches
    final localLive = store.matches.where((m) {
      if (m.status != 'live') return false;
      final a = store.teamName(m.teamAId);
      final b = store.teamName(m.teamBId);
      return matchesSearch(a, b, m.matchTitle, m.venue);
    }).toList();

    final localRecent = store.matches.where((m) {
      if (m.status != 'completed' && m.status != 'noResult') return false;
      final a = store.teamName(m.teamAId);
      final b = store.teamName(m.teamBId);
      return matchesSearch(a, b, m.matchTitle, m.venue);
    }).toList();

    final localIds = {for (final m in store.matches) m.id};

    // 2. Filter remote matches (deduplicated against local store)
    final remoteLive = _remoteLive.where((rm) {
      if (localIds.contains(rm.id)) return false;
      return matchesSearch(rm.teamAName, rm.teamBName, rm.matchTitle, rm.venue);
    }).toList();

    final remoteRecent = _remoteRecent.where((rm) {
      if (localIds.contains(rm.id)) return false;
      return matchesSearch(rm.teamAName, rm.teamBName, rm.matchTitle, rm.venue);
    }).toList();

    final allLive = <dynamic>[...localLive, ...remoteLive];
    final allRecent = <dynamic>[...localRecent, ...remoteRecent];
    final allMatches = <dynamic>[...allLive, ...allRecent];

    final displayList = _selectedTab == 1
        ? allLive
        : (_selectedTab == 2 ? allRecent : allMatches);

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      appBar: AppBar(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PitchTheme.primary),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) => Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: PitchTheme.error.withValues(alpha: _pulseAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Public & Live Matches',
              style: TextStyle(
                color: PitchTheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PitchTheme.secondary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: PitchTheme.secondary),
              tooltip: 'Refresh feed',
              onPressed: () => _fetchMatches(silent: false),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: PitchTheme.secondary,
        backgroundColor: PitchTheme.surfaceContainerLowest,
        onRefresh: () => _fetchMatches(silent: false),
        child: Column(
          children: [
            // Top Section: Search Bar & Tab Pills
            Container(
              color: PitchTheme.surfaceContainerLowest,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  // Search Box
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: PitchTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PitchTheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: PitchTheme.outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Search teams, venue, or match title...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: PitchTheme.outline,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: PitchTheme.onSurface,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.clear, size: 18, color: PitchTheme.outline),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Tabs: All, Live Now, Completed
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildTabChip(
                          index: 0,
                          label: 'All Matches',
                          count: allMatches.length,
                        ),
                        const SizedBox(width: 8),
                        _buildTabChip(
                          index: 1,
                          label: 'Live Now',
                          count: allLive.length,
                          isLiveIndicator: true,
                        ),
                        const SizedBox(width: 8),
                        _buildTabChip(
                          index: 2,
                          label: 'Completed',
                          count: allRecent.length,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: PitchTheme.primaryContainer,
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off, size: 14, color: PitchTheme.tertiaryFixed),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing cached matches. Connect to the internet for live cloud updates.',
                        style: TextStyle(
                          color: PitchTheme.tertiaryFixed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Matches List
            Expanded(
              child: displayList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        if (item is Match) {
                          return _buildLocalMatchCard(item);
                        } else if (item is RemoteMatchSummary) {
                          return _buildRemoteMatchCard(item);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required int index,
    required String label,
    required int count,
    bool isLiveIndicator = false,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? PitchTheme.primary : PitchTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? PitchTheme.primary
                : PitchTheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLiveIndicator) ...[
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) => Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? PitchTheme.tertiaryFixed
                        : PitchTheme.error.withValues(alpha: _pulseAnimation.value),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? PitchTheme.surfaceContainerLowest : PitchTheme.onSurface,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? PitchTheme.secondaryContainer
                    : PitchTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected
                      ? PitchTheme.onSecondaryContainer
                      : PitchTheme.outline,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: PitchTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_cricket_outlined,
                size: 44,
                color: PitchTheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matches matching "$_searchQuery"'
                  : (_selectedTab == 1
                      ? 'No Live Matches Right Now'
                      : 'No Matches Available'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PitchTheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedTab == 1
                  ? 'Matches started across the league will show up live here with telemetry.'
                  : 'Pull down to refresh or check your internet connection.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PitchTheme.outline,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalMatchCard(Match m) {
    final tA = store.teamById(m.teamAId);
    final tB = store.teamById(m.teamBId);
    final teamAName = tA?.name ?? store.teamName(m.teamAId);
    final teamBName = tB?.name ?? store.teamName(m.teamBId);
    final teamACode = tA?.displayCode ??
        (teamAName.length >= 2
            ? teamAName.substring(0, 2).toUpperCase()
            : teamAName.toUpperCase());
    final teamBCode = tB?.displayCode ??
        (teamBName.length >= 2
            ? teamBName.substring(0, 2).toUpperCase()
            : teamBName.toUpperCase());
    final isLive = m.status == 'live';

    String? aRuns;
    String? aOvers;
    String? bRuns;
    String? bOvers;
    final bpo = m.ballsPerOver > 0 ? m.ballsPerOver : 6;
    for (final inn in m.innings) {
      final runs = '${inn.totalRuns}/${inn.wickets}';
      final ov = '(${inn.legalBalls ~/ bpo}.${inn.legalBalls % bpo})';
      if (inn.battingTeamId == m.teamAId) {
        aRuns = runs;
        aOvers = ov;
      } else {
        bRuns = runs;
        bOvers = ov;
      }
    }

    final activeBattingId =
        m.innings.isNotEmpty ? m.innings.last.battingTeamId : '';
    final isTeamABatting = isLive && activeBattingId == m.teamAId;
    final isTeamBBatting = isLive && activeBattingId == m.teamBId;

    String? headerTitle;
    if (m.tournamentId != null) {
      final t = store.tournamentById(m.tournamentId!);
      if (t != null && t.name.isNotEmpty) headerTitle = t.name;
    }
    headerTitle ??= m.matchTitle.isNotEmpty
        ? m.matchTitle
        : (m.venue.isNotEmpty ? m.venue : '${m.oversLimit} Overs Match');

    String footerText;
    if (isLive) {
      if (m.innings.length > 1 && m.innings[1].target > 0) {
        final inn2 = m.innings[1];
        final runsNeeded = inn2.target - inn2.totalRuns;
        final ballsLeft = (m.oversLimit * bpo) - inn2.legalBalls;
        final rrr = (ballsLeft > 0 && runsNeeded > 0)
            ? (runsNeeded * bpo) / ballsLeft
            : 0.0;
        final battingName =
            inn2.battingTeamId == m.teamAId ? teamAName : teamBName;
        footerText = '$battingName need $runsNeeded runs'
            '${rrr > 0 ? ' • RRR ${rrr.toStringAsFixed(2)}' : ''}';
      } else if (m.innings.isNotEmpty) {
        final inn = m.innings.last;
        final crr = inn.legalBalls > 0
            ? (inn.totalRuns * bpo) / inn.legalBalls
            : 0.0;
        footerText = 'CRR ${crr.toStringAsFixed(2)} • ${m.oversLimit} Overs';
      } else {
        footerText = '${m.oversLimit} Overs Match';
      }
    } else {
      footerText =
          m.resultText.isNotEmpty ? m.resultText : 'Match Concluded';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BroadcastMatchCard(
        headerTitle: headerTitle,
        teamAName: teamAName,
        teamACode: teamACode,
        teamALogo: tA?.logo ?? '',
        teamARuns: aRuns,
        teamAOvers: aOvers,
        isTeamABatting: isTeamABatting,
        teamBName: teamBName,
        teamBCode: teamBCode,
        teamBLogo: tB?.logo ?? '',
        teamBRuns: bRuns,
        teamBOvers: bOvers,
        isTeamBBatting: isTeamBBatting,
        isLive: isLive,
        footerText: footerText,
        pulseAnimation: _pulseAnimation,
        onTap: () => _openMatch(m),
      ),
    );
  }

  Widget _buildRemoteMatchCard(RemoteMatchSummary rm) {
    final tA = store.teamById(rm.teamAId);
    final tB = store.teamById(rm.teamBId);
    final logoA = (tA != null && tA.logo.isNotEmpty) ? tA.logo : rm.teamALogo;
    final logoB = (tB != null && tB.logo.isNotEmpty) ? tB.logo : rm.teamBLogo;
    final codeA = (tA != null && tA.shortCode.isNotEmpty)
        ? tA.shortCode
        : (rm.teamACode.isNotEmpty
            ? rm.teamACode
            : (rm.teamAName.length >= 2
                ? rm.teamAName.substring(0, 2).toUpperCase()
                : rm.teamAName.toUpperCase()));
    final codeB = (tB != null && tB.shortCode.isNotEmpty)
        ? tB.shortCode
        : (rm.teamBCode.isNotEmpty
            ? rm.teamBCode
            : (rm.teamBName.length >= 2
                ? rm.teamBName.substring(0, 2).toUpperCase()
                : rm.teamBName.toUpperCase()));

    final innA = rm.inningsForTeam(rm.teamAId) ??
        (rm.innings.isNotEmpty ? rm.innings.first : null);
    final innB = rm.inningsForTeam(rm.teamBId) ??
        (rm.innings.length > 1 ? rm.innings[1] : null);

    final aRuns = innA != null ? '${innA.totalRuns}/${innA.wickets}' : null;
    final aOvers = innA != null ? '(${innA.oversText})' : null;
    final bRuns = innB != null ? '${innB.totalRuns}/${innB.wickets}' : null;
    final bOvers = innB != null ? '(${innB.oversText})' : null;

    final activeInn = rm.innings.isNotEmpty ? rm.innings.last : null;
    final isOpening = _openingMatchId == rm.id;

    final headerTitle = rm.matchTitle.isNotEmpty
        ? rm.matchTitle
        : (rm.venue.isNotEmpty ? rm.venue : '${rm.oversLimit} Overs Match');

    final footerText = rm.isLive
        ? (activeInn != null && activeInn.target > 0
            ? 'Target ${activeInn.target} • CRR ${activeInn.crr.toStringAsFixed(2)}'
            : (activeInn != null
                ? 'CRR ${activeInn.crr.toStringAsFixed(2)} • ${rm.oversLimit} Overs'
                : 'Live on STUMPS'))
        : (rm.resultText.isNotEmpty ? rm.resultText : 'Match Concluded');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BroadcastMatchCard(
        headerTitle: headerTitle,
        teamAName: rm.teamAName,
        teamACode: codeA,
        teamALogo: logoA,
        teamARuns: aRuns,
        teamAOvers: aOvers,
        isTeamABatting: rm.isLive && activeInn?.battingTeamId == rm.teamAId,
        teamBName: rm.teamBName,
        teamBCode: codeB,
        teamBLogo: logoB,
        teamBRuns: bRuns,
        teamBOvers: bOvers,
        isTeamBBatting: rm.isLive && activeInn?.battingTeamId == rm.teamBId,
        isLive: rm.isLive,
        footerText: footerText,
        pulseAnimation: _pulseAnimation,
        isOpening: isOpening,
        onTap: () => _openMatch(rm),
      ),
    );
  }
}
