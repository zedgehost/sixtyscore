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
    final teamAName = store.teamName(m.teamAId);
    final teamBName = store.teamName(m.teamBId);
    final isLive = m.status == 'live';

    String scoreA = 'Yet to bat';
    String scoreB = 'Yet to bat';
    if (m.innings.isNotEmpty) {
      final inn1 = m.innings[0];
      final s = '${inn1.totalRuns}/${inn1.wickets} (${inn1.legalBalls ~/ 6}.${inn1.legalBalls % 6})';
      if (inn1.battingTeamId == m.teamAId) {
        scoreA = s;
      } else {
        scoreB = s;
      }
    }
    if (m.innings.length > 1) {
      final inn2 = m.innings[1];
      final s = '${inn2.totalRuns}/${inn2.wickets} (${inn2.legalBalls ~/ 6}.${inn2.legalBalls % 6})';
      if (inn2.battingTeamId == m.teamAId) {
        scoreA = s;
      } else {
        scoreB = s;
      }
    }

    final isCreator = !AuthService().isRestrictedGuest &&
        m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive
              ? PitchTheme.secondary.withValues(alpha: 0.4)
              : PitchTheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMatch(m),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status Badge, Title & Creator indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLive) ...[
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) => Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: PitchTheme.error.withValues(alpha: _pulseAnimation.value),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: PitchTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'LIVE • ${m.oversLimit} Ov',
                              style: const TextStyle(
                                color: PitchTheme.tertiaryFixed,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: PitchTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'RESULT • ${m.oversLimit} Ov',
                              style: const TextStyle(
                                color: PitchTheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        if (isCreator) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PitchTheme.secondaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'My Match',
                              style: TextStyle(
                                color: PitchTheme.onSecondaryContainer,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Flexible(
                      child: Text(
                        m.venue.isNotEmpty ? m.venue : (m.matchTitle.isNotEmpty ? m.matchTitle : 'Match'),
                        style: const TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Team A Row
                _buildTeamRow(
                  name: teamAName,
                  scoreText: scoreA,
                  isLive: isLive && m.innings.isNotEmpty && m.innings.last.battingTeamId == m.teamAId,
                ),
                const SizedBox(height: 8),

                // Team B Row
                _buildTeamRow(
                  name: teamBName,
                  scoreText: scoreB,
                  isLive: isLive && m.innings.isNotEmpty && m.innings.last.battingTeamId == m.teamBId,
                ),
                const SizedBox(height: 10),

                // Footer Divider
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: PitchTheme.surfaceContainerLow,
                ),
                const SizedBox(height: 8),

                // Footer Row: Match result or CRR info & Action hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m.resultText.isNotEmpty
                            ? m.resultText
                            : (isLive
                                ? (m.innings.length > 1
                                    ? 'Target: ${m.innings[1].target} · 2nd Innings'
                                    : '1st Innings in progress')
                                : 'Match Concluded'),
                        style: TextStyle(
                          color: m.resultText.isNotEmpty
                              ? PitchTheme.secondary
                              : (isLive ? PitchTheme.primary : PitchTheme.onSurfaceVariant),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isCreator && isLive ? 'Score / Manage' : 'View Match',
                          style: TextStyle(
                            color: isCreator && isLive ? PitchTheme.secondary : PitchTheme.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: isCreator && isLive ? PitchTheme.secondary : PitchTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteMatchCard(RemoteMatchSummary rm) {
    final innA = rm.inningsForTeam(rm.teamAId) ??
        (rm.innings.isNotEmpty ? rm.innings.first : null);
    final innB = rm.inningsForTeam(rm.teamBId) ??
        (rm.innings.length > 1 ? rm.innings[1] : null);

    final scoreA = innA != null
        ? '${innA.totalRuns}/${innA.wickets} (${innA.oversText})'
        : 'Yet to bat';
    final scoreB = innB != null
        ? '${innB.totalRuns}/${innB.wickets} (${innB.oversText})'
        : 'Yet to bat';

    final activeInn = rm.innings.isNotEmpty ? rm.innings.last : null;
    final isOpening = _openingMatchId == rm.id;

    final footerText = rm.isLive
        ? (activeInn != null && activeInn.target > 0
            ? 'Target ${activeInn.target} • CRR ${activeInn.crr.toStringAsFixed(2)}'
            : (activeInn != null
                ? 'CRR ${activeInn.crr.toStringAsFixed(2)}'
                : 'Live on 60Score'))
        : (rm.resultText.isNotEmpty ? rm.resultText : 'Match Concluded');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rm.isLive
              ? PitchTheme.secondary.withValues(alpha: 0.3)
              : PitchTheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMatch(rm),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status Badge, Title & Creator indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rm.isLive) ...[
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) => Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: PitchTheme.error.withValues(alpha: _pulseAnimation.value),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: PitchTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'LIVE • ${rm.oversLimit} Ov',
                              style: const TextStyle(
                                color: PitchTheme.tertiaryFixed,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: PitchTheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'RESULT • ${rm.oversLimit} Ov',
                              style: const TextStyle(
                                color: PitchTheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        if (rm.creatorName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PitchTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'By ${rm.creatorName}',
                              style: const TextStyle(
                                color: PitchTheme.outline,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isOpening)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PitchTheme.secondary,
                        ),
                      )
                    else
                      Flexible(
                        child: Text(
                          rm.venue.isNotEmpty
                              ? rm.venue
                              : (rm.matchTitle.isNotEmpty ? rm.matchTitle : 'Public Match'),
                          style: const TextStyle(
                            color: PitchTheme.outline,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Team A Row
                _buildTeamRow(
                  name: rm.teamAName,
                  scoreText: scoreA,
                  isLive: rm.isLive && activeInn?.battingTeamId == rm.teamAId,
                ),
                const SizedBox(height: 8),

                // Team B Row
                _buildTeamRow(
                  name: rm.teamBName,
                  scoreText: scoreB,
                  isLive: rm.isLive && activeInn?.battingTeamId == rm.teamBId,
                ),
                const SizedBox(height: 10),

                // Footer Divider
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: PitchTheme.surfaceContainerLow,
                ),
                const SizedBox(height: 8),

                // Footer Row: Match result / Telemetry & View link
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        footerText,
                        style: TextStyle(
                          color: rm.resultText.isNotEmpty
                              ? PitchTheme.secondary
                              : (rm.isLive ? PitchTheme.primary : PitchTheme.onSurfaceVariant),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Spectate',
                          style: TextStyle(
                            color: PitchTheme.secondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 11,
                          color: PitchTheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow({
    required String name,
    required String scoreText,
    required bool isLive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isLive ? PitchTheme.primaryContainer : PitchTheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLive
                        ? PitchTheme.secondary.withValues(alpha: 0.5)
                        : PitchTheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                  style: TextStyle(
                    color: isLive ? PitchTheme.tertiaryFixed : PitchTheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: isLive ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          scoreText,
          style: TextStyle(
            color: isLive ? PitchTheme.primary : PitchTheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}
