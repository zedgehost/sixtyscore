// Match Centre: Summary / Scorecard / Stats / Super Stars / Balls / Info.
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/core/utils/nav_memory.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/export/pdf_export.dart';
import 'package:cricket_scorer_app/services/share/poster_summary.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/share/summary_share.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart' show copyToClipboard, shareBytes;
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_edit_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/super_over_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';
import 'package:cricket_scorer_app/views/widgets/charts.dart';
import 'package:cricket_scorer_app/views/widgets/player_avatar.dart';
import 'package:cricket_scorer_app/views/widgets/potm_picker.dart';
import 'package:cricket_scorer_app/views/screens/teams/profile_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournament_detail_screen.dart';

class ScorecardScreen extends StatefulWidget {
  final Store store;
  final Match match;
  final bool? isScorer;
  const ScorecardScreen({
    super.key,
    required this.store,
    required this.match,
    this.isScorer,
  });

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  Store get store => widget.store;
  late Match match;
  Timer? _liveAutoPollTimer;
  bool _isAutoPolling = false;

  @override
  void initState() {
    super.initState();
    match = widget.store.matchById(widget.match.id) ?? widget.match;
    _startLivePollingIfNeeded();
  }

  void _startLivePollingIfNeeded() {
    _liveAutoPollTimer?.cancel();
    if (match.status == 'live') {
      _liveAutoPollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _autoPollLiveUpdates(),
      );
    }
  }

  Future<void> _autoPollLiveUpdates() async {
    if (!mounted || _isAutoPolling) return;
    _isAutoPolling = true;
    try {
      // 1. Check local store in case another tab or local scoring updated it
      final local = widget.store.matchById(widget.match.id);
      if (local != null && local != match) {
        if (mounted) {
          setState(() {
            match = local;
          });
        }
      }

      // 2. Fetch live match details from cPanel cloud in background
      final client = CpanelApiClient();
      await client.init();
      final res = await client.getMatchDetail(widget.match.id);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final payload = data['payload'];
        if (payload is Map && payload.isNotEmpty) {
          final updated = Match.fromJson(Map<String, dynamic>.from(payload));
          if (widget.store.isRemotePreview) {
            final idx = widget.store.matches.indexWhere((x) => x.id == updated.id);
            if (idx >= 0) {
              widget.store.matches[idx] = updated;
            } else {
              widget.store.matches.add(updated);
            }
          } else {
            await widget.store.upsertMatch(updated);
          }
          if (mounted) {
            setState(() {
              match = updated;
            });
            if (match.status != 'live') {
              _liveAutoPollTimer?.cancel();
            }
          }
        }
      }
    } catch (_) {
      // Silent error: offline-first ensures app never crashes if offline
    } finally {
      _isAutoPolling = false;
    }
  }

  @override
  void dispose() {
    _liveAutoPollTimer?.cancel();
    super.dispose();
  }

  String nameOf(String id) => store.playerName(id);

  String get _tournamentName {
    final tid = match.tournamentId;
    if (tid == null) return '';
    return store.tournamentById(tid)?.name ?? '';
  }

  Future<void> _sharePdf(BuildContext context) async {
    final bytes = await buildScorecardPdf(
      match,
      nameOf,
      store.teamName,
      tournamentName: _tournamentName,
    );
    await shareBytes(
      'scorecard_${match.id}.pdf',
      bytes,
      text: '60Score scorecard',
    );
  }

  void _handleBack(BuildContext context) {
    final tid = match.tournamentId;
    if (tid != null && tid.isNotEmpty) {
      final t = store.tournamentById(tid);
      if (t != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => TournamentDetailScreen(store: store, tournament: t),
          ),
          (route) => route.isFirst,
        );
        return;
      }
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final hasWinnerResult = match.resultText.isNotEmpty && match.status != 'noResult';
    final hasBothInningsDone = match.innings.length >= 2 && match.innings[1].isComplete;
    if ((hasWinnerResult || hasBothInningsDone) && match.status != 'completed') {
      match.status = 'completed';
      if (match.resultText.isEmpty) {
        final res = computeResult(match, store.teamName);
        if (res.isNotEmpty) match.resultText = res;
      }
      store.persistMatchesOnly();
    }

    return _ScorecardNavScope(
      matchId: match.id,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isScorer = widget.isScorer ??
        (!store.isRemotePreview &&
            !AuthService().isRestrictedGuest &&
            store.matches.any((m) => m.id == match.id) &&
            match.canUserScore(store.effectiveUserId,
                userCode: store.effectiveUserCode));
    return PopScope(
      canPop: match.tournamentId == null || match.tournamentId!.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          backgroundColor: PitchTheme.surface,
          appBar: AppBar(
            backgroundColor: PitchTheme.surfaceContainerLowest,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: PitchTheme.primary),
              tooltip: 'Back',
              onPressed: () => _handleBack(context),
            ),
            iconTheme: const IconThemeData(color: PitchTheme.primary),
            titleTextStyle: const TextStyle(
              color: PitchTheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            title: const Text('Match Centre'),
          actions: [
            if (matchIsTied(match) && isScorer)
              IconButton(
                icon: const Icon(Icons.flash_on, color: PitchTheme.secondary),
                tooltip: 'Super Over',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SuperOverScreen(store: store, match: match),
                    ),
                  );
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
            if (match.status == 'completed' && isScorer)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: PitchTheme.primary),
                tooltip: 'Edit scorecard',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScorecardEditScreen(
                        store: store,
                        match: match,
                      ),
                    ),
                  );
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                },
              ),
            if (match.status == 'completed' && isScorer)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: PitchTheme.error),
                tooltip: 'Delete match',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: PitchTheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Delete match?',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      content: const Text(
                        'Delete this match and its scorecard? '
                        'This cannot be undone.',
                        style: TextStyle(color: PitchTheme.onSurfaceVariant),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: PitchTheme.outline),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: PitchTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await store.deleteMatch(match.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: PitchTheme.primary),
              tooltip: 'Copy scorecard as text',
              onPressed: () async {
                await copyToClipboard(
                  scorecardText(match, nameOf, store.teamName),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scorecard copied to clipboard'),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: PitchTheme.primary),
              tooltip: 'Share scorecard PDF',
              onPressed: () => _sharePdf(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: PitchTheme.secondary,
            indicatorWeight: 3,
            labelColor: PitchTheme.primary,
            unselectedLabelColor: PitchTheme.outline,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            dividerColor: PitchTheme.surfaceContainerLow,
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Scorecard'),
              Tab(text: 'Stats'),
              Tab(text: 'Super Stars'),
              Tab(text: 'Balls'),
              Tab(text: 'Info'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (!isScorer)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: PitchTheme.surfaceContainerLow,
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, size: 15, color: PitchTheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Spectator Mode • Scorer: ${match.creatorName.isNotEmpty ? match.creatorName : 'Authorized Scorer'}',
                        style: const TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: PitchTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'READ ONLY',
                        style: TextStyle(
                          color: PitchTheme.tertiaryFixed,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _SummaryTab(store: store, match: match, isScorer: isScorer),
                  _scorecardTab(context),
                  _chartsTab(),
                  _SuperStarsTab(store: store, match: match),
                  _BallsTab(store: store, match: match, isScorer: isScorer),
                  _InfoTab(store: store, match: match),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: (match.status == 'live' || match.status == 'upcoming')
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLowest,
                  boxShadow: PitchTheme.cardShadow,
                  border: Border(top: BorderSide(color: PitchTheme.surfaceContainerLow)),
                ),
                child: SafeArea(
                  child: isScorer
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: PitchTheme.primary,
                            foregroundColor: PitchTheme.tertiaryFixed,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScoringScreen(store: store, match: match),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sports_cricket, size: 20),
                          label: const Text(
                            'Resume Live Ball-by-Ball Scoring',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                          decoration: BoxDecoration(
                            color: PitchTheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: PitchTheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live Telemetry • Auto-Updating',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    color: PitchTheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.wifi_tethering, size: 12, color: PitchTheme.secondary),
                                    SizedBox(width: 4),
                                    Text(
                                      'REALTIME',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: PitchTheme.onSecondaryContainer,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              )
            : null,
      ),
    ));
  }

  // ---------------- Scorecard tab ----------------

  Widget _scorecardTab(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _matchHeaderCard(),
        const SizedBox(height: 14),
        for (var i = 0; i < match.innings.length; i++) ...[
          _inningsCard(match.innings[i], i),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _bigActionButton(
                context,
                icon: Icons.share_rounded,
                title: 'Share Summary',
                subtitle: 'Share match result',
                color: PitchTheme.secondary,
                onTap: () => shareMatchSummaryImage(context, store, match),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigActionButton(
                context,
                icon: Icons.picture_as_pdf_rounded,
                title: 'Export PDF',
                subtitle: 'Download Scorecard',
                color: PitchTheme.primary,
                onTap: () => _sharePdf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bigActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: PitchTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PitchTheme.surfaceContainerLow),
          boxShadow: PitchTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PitchTheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchHeaderCard() {
    final date = match.dateIso.isNotEmpty ? match.dateIso : '';
    final venue = match.venue.isNotEmpty ? match.venue : 'TBD';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CaptainAvatar(store: store, teamId: match.teamAId),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${store.teamName(match.teamAId)} vs ${store.teamName(match.teamBId)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: PitchTheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CaptainAvatar(store: store, teamId: match.teamBId),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (date.isNotEmpty) _metaChip(Icons.calendar_month, date),
              _metaChip(Icons.sports_cricket, '${match.oversLimit} overs'),
              _metaChip(Icons.location_on_outlined, venue),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toss: ${store.teamName(match.tossWinnerId)} chose to ${match.tossDecision} first',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PitchTheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (match.resultText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: PitchTheme.secondaryContainer.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: PitchTheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      match.resultText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PitchTheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: PitchTheme.secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: PitchTheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inningsCard(InningsState inn, int idx) {
    final ordinal = idx == 0
        ? '1st'
        : idx == 1
            ? '2nd'
            : '${idx + 1}th';
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                CaptainAvatar(store: store, teamId: inn.battingTeamId),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.teamName(inn.battingTeamId),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: PitchTheme.onSurface,
                        ),
                      ),
                      Text(
                        '$ordinal Innings',
                        style: const TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: PitchTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${inn.totalRuns}/${inn.wickets} (${oversText(inn.legalBalls, inn.ballsPerOver)} ov)',
                    style: const TextStyle(
                      color: PitchTheme.tertiaryFixed,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _sectionHeader(Icons.sports_cricket, 'Batting'),
          _battingTableNew(inn),
          const SizedBox(height: 6),
          _sectionHeader(Icons.sports_baseball, 'Bowling'),
          _bowlingTableNew(inn),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.handshake_outlined,
                  size: 16,
                  color: PitchTheme.secondary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Partnerships  ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PitchTheme.onSurface,
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: Text(
                    partnerships(inn).isEmpty
                        ? '-'
                        : partnerships(inn)
                            .map(
                              (p) =>
                                  '${nameOf(p.batter1Id)} & ${nameOf(p.batter2Id)}: ${p.runs} (${p.balls})${p.unbroken ? ' *' : ''}',
                            )
                            .join('  \u2022  '),
                    style: const TextStyle(
                      color: PitchTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: PitchTheme.secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: PitchTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderRow(List<String> cols, List<int> flex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < cols.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(
                cols[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: const TextStyle(
                  color: PitchTheme.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _battingTableNew(InningsState inn) {
    final batted = inn.battingXI
        .where((pid) => inn.batting[pid]?.batted ?? false)
        .toList();
    final dnb = inn.battingXI
        .where((pid) => !(inn.batting[pid]?.batted ?? false))
        .map(nameOf)
        .toList();
    return Column(
      children: [
        _tableHeaderRow(
          const ['Batter', 'R', 'B', '4s', '6s', 'SR'],
          const [5, 2, 2, 2, 2, 3],
        ),
        for (final pid in batted) _battingRowNew(inn, pid),
        if (dnb.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 16,
                  color: PitchTheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Did not bat (${dnb.length} players): ${dnb.join(', ')}',
                    style: const TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: [
              const Text(
                'Extras: ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PitchTheme.onSurface,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Text(
                  '${inn.extrasTotal} (wd ${inn.widesRuns}, nb ${inn.noBallRuns}, b ${inn.byeRuns}, lb ${inn.legByeRuns})',
                  style: const TextStyle(
                    color: PitchTheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _battingRowNew(InningsState inn, String pid) {
    final f = inn.batting[pid]!;
    final sr = f.balls == 0
        ? '-'
        : (f.runs * 100 / f.balls).toStringAsFixed(1);
    final pl = store.findPlayer(pid);
    final rowPhoto = store.photoForPlayer(pid);
    final figures = [
      '${f.runs}',
      '${f.balls}',
      '${f.fours}',
      '${f.sixes}',
      sr,
    ];
    return Builder(
      builder: (context) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              store: store,
              playerId: pid,
              playerName: nameOf(pid),
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    PlayerAvatar(
                      photoBase64: rowPhoto.isEmpty ? null : rowPhoto,
                      role: pl?.role ?? 'Batter',
                      name: nameOf(pid),
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nameOf(pid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PitchTheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            batFigStatusText(f, nameOf),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  f.out ? FontWeight.w500 : FontWeight.w700,
                              color: f.out
                                  ? PitchTheme.outline
                                  : PitchTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < figures.length; i++)
                Expanded(
                  flex: i == 4 ? 3 : 2,
                  child: Text(
                    figures[i],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: i == 0
                          ? PitchTheme.onSurface
                          : PitchTheme.onSurfaceVariant,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bowlingTableNew(InningsState inn) {
    final bowlers = inn.bowling.keys
        .where((pid) {
          final f = inn.bowling[pid]!;
          return f.legalBalls > 0 || f.wides > 0 || f.noBalls > 0;
        })
        .toList();
    return Column(
      children: [
        _tableHeaderRow(
          const ['Bowler', 'O', 'M', 'R', 'W', 'Econ'],
          const [5, 2, 2, 2, 2, 3],
        ),
        for (final pid in bowlers) _bowlingRowNew(inn, pid),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _bowlingRowNew(InningsState inn, String pid) {
    final f = inn.bowling[pid]!;
    final econ = f.legalBalls == 0
        ? '-'
        : (f.runs * inn.ballsPerOver / f.legalBalls).toStringAsFixed(2);
    final pl = store.findPlayer(pid);
    final rowPhoto = store.photoForPlayer(pid);
    final figures = [
      oversText(f.legalBalls, inn.ballsPerOver),
      '${f.maidens}',
      '${f.runs}',
      '${f.wickets}',
      econ,
    ];
    return Builder(
      builder: (context) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              store: store,
              playerId: pid,
              playerName: nameOf(pid),
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    PlayerAvatar(
                      photoBase64: rowPhoto.isEmpty ? null : rowPhoto,
                      role: pl?.role ?? 'Bowler',
                      name: nameOf(pid),
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nameOf(pid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PitchTheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < figures.length; i++)
                Expanded(
                  flex: i == 4 ? 3 : 2,
                  child: Text(
                    figures[i],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: i == 3 && f.wickets > 0
                          ? PitchTheme.error
                          : PitchTheme.onSurfaceVariant,
                      fontWeight: i == 3 && f.wickets > 0
                          ? FontWeight.w800
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Stats tab (charts) ----------------

  Widget _chartsTab() {
    if (match.innings.isEmpty) {
      return const Center(
        child: Text(
          'No data yet.',
          style: TextStyle(color: PitchTheme.outline),
        ),
      );
    }
    final i1 = match.innings[0];
    final i2 = match.innings.length > 1 ? match.innings[1] : null;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: PitchTheme.cardShadow,
            border: Border.all(color: PitchTheme.surfaceContainerLow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Runs Comparison (worm)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: PitchTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              WormChart(
                innings1: wormData(i1),
                innings2: i2 != null ? wormData(i2) : const [],
                label1: store.teamName(i1.battingTeamId),
                label2: i2 != null ? store.teamName(i2.battingTeamId) : '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: PitchTheme.cardShadow,
            border: Border.all(color: PitchTheme.surfaceContainerLow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Over Comparison (Manhattan)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: PitchTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ManhattanChart(
                innings1: manhattanData(i1),
                innings2: i2 != null ? manhattanData(i2) : const [],
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.square, size: 12, color: Colors.amber),
                  SizedBox(width: 4),
                  Text(
                    'Innings 1',
                    style: TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 14),
                  Icon(Icons.square, size: 12, color: PitchTheme.secondary),
                  SizedBox(width: 4),
                  Text(
                    'Innings 2',
                    style: TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: PitchTheme.cardShadow,
            border: Border.all(color: PitchTheme.surfaceContainerLow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wagon Wheel',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: PitchTheme.onSurface,
                ),
              ),
              for (final inn in match.innings) ...[
                const SizedBox(height: 12),
                Text(
                  store.teamName(inn.battingTeamId),
                  style: const TextStyle(
                    color: PitchTheme.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                _WagonForInnings(inn: inn, nameOf: nameOf),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ---------------- Summary tab ----------------

class _SummaryTab extends StatelessWidget {
  final Store store;
  final Match match;
  final bool isScorer;
  const _SummaryTab({
    required this.store,
    required this.match,
    this.isScorer = true,
  });

  String nameOf(String id) => store.playerName(id);

  @override
  Widget build(BuildContext context) {
    final result = match.resultText.isNotEmpty
        ? match.resultText
        : computeResult(match, store.teamName);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (match.matchTitle.isNotEmpty)
          Text(
            match.matchTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: PitchTheme.secondary,
            ),
          ),
        Text(
          '${store.teamName(match.teamAId)} vs ${store.teamName(match.teamBId)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: PitchTheme.onSurface,
          ),
        ),
        if (match.tournamentId != null &&
            store.tournamentById(match.tournamentId!) != null) ...[
          const SizedBox(height: 2),
          Text(
            store.tournamentById(match.tournamentId!)!.name,
            style: const TextStyle(
              color: PitchTheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (final inn in match.innings) ...[
          _inningsCard(inn),
          const SizedBox(height: 12),
        ],
        if (result.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PitchTheme.secondaryContainer.withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: PitchTheme.onSecondaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: PitchTheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (match.manOfMatchId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PitchTheme.cardShadow,
              border: Border.all(color: PitchTheme.surfaceContainerLow),
            ),
            padding: const EdgeInsets.all(14),
            child: Builder(builder: (context) {
              final pid = match.manOfMatchId;
              final pl = store.findPlayer(pid);
              final potmPhoto = store.photoForPlayer(pid);
              var runs = 0, balls = 0, wkts = 0;
              for (final inn in match.innings) {
                final bf = inn.batting[pid];
                if (bf != null && bf.batted) {
                  runs += bf.runs;
                  balls += bf.balls;
                }
                final wf = inn.bowling[pid];
                if (wf != null && wf.legalBalls > 0) wkts += wf.wickets;
              }
              var teamName = '';
              for (final t in store.teams) {
                if (t.players.any((p) => p.id == pid)) {
                  teamName = t.name;
                  break;
                }
              }
              final figLine = [
                if (runs > 0 || balls > 0) '$runs ($balls)',
                if (wkts > 0) '$wkts wkt${wkts == 1 ? '' : 's'}',
              ].join('  •  ');
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            store: store,
                            playerId: pid,
                            playerName: nameOf(pid),
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          PlayerAvatar(
                            photoBase64: potmPhoto.isEmpty ? null : potmPhoto,
                            role: pl?.role ?? 'Batter',
                            name: nameOf(pid),
                            radius: 34,
                            fallbackIcon: Icons.person,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'PLAYER OF THE MATCH',
                                  style: TextStyle(
                                    color: PitchTheme.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nameOf(pid),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: PitchTheme.onSurface,
                                  ),
                                ),
                                if (teamName.isNotEmpty)
                                  Text(
                                    teamName,
                                    style: const TextStyle(
                                      color: PitchTheme.outline,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (figLine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PitchTheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      figLine,
                                      style: const TextStyle(
                                        color: PitchTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isScorer)
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: PitchTheme.outline,
                      ),
                      tooltip: 'Change Player of the Match',
                      onPressed: () async {
                        final picked = await showPotmPickerDialog(
                          context,
                          store,
                          match,
                        );
                        if (picked != null && picked.isNotEmpty) {
                          match.manOfMatchId = picked;
                          await store.persistMatchesOnly();
                          if (context.mounted) {
                            (context as Element).markNeedsBuild();
                          }
                        }
                      },
                    ),
                ],
              );
            }),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: PitchTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final tid = match.tournamentId;
                  final tname = tid == null
                      ? ''
                      : (store.tournamentById(tid)?.name ?? '');
                  final bytes = await buildScorecardPdf(
                    match,
                    nameOf,
                    store.teamName,
                    tournamentName: tname,
                  );
                  await shareBytes(
                    'scorecard_${match.id}.pdf',
                    bytes,
                    text: '60Score match report',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text(
                  'Share Report',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PitchTheme.primary,
                  side: const BorderSide(color: PitchTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => shareMatchSummaryImage(context, store, match),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text(
                  'Summary Image',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        if (matchHasPosterFigures(match)) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: PitchTheme.secondary,
                side: const BorderSide(color: PitchTheme.secondary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => shareMatchPosterImage(context, store, match),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text(
                'Share Poster Summary',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _inningsCard(InningsState inn) {
    final batters = inn.batting.entries.where((e) => e.value.batted).toList()
      ..sort((a, b) => b.value.runs.compareTo(a.value.runs));
    final bowlers =
        inn.bowling.entries.where((e) => e.value.legalBalls > 0).toList()
          ..sort((a, b) {
            if (b.value.wickets != a.value.wickets) {
              return b.value.wickets.compareTo(a.value.wickets);
            }
            return a.value.runs.compareTo(b.value.runs);
          });
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  store.teamName(inn.battingTeamId).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: PitchTheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PitchTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${inn.totalRuns}/${inn.wickets} (${oversText(inn.legalBalls, inn.ballsPerOver)})',
                  style: const TextStyle(
                    color: PitchTheme.tertiaryFixed,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: PitchTheme.surfaceContainerLow),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in batters.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nameOf(e.key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PitchTheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${e.value.runs}${e.value.out ? '' : '*'} (${e.value.balls})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: PitchTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in bowlers.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nameOf(e.key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PitchTheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${e.value.wickets}-${e.value.runs}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: e.value.wickets > 0
                                    ? PitchTheme.error
                                    : PitchTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- Super Stars tab ----------------

class _SuperStarsTab extends StatelessWidget {
  final Store store;
  final Match match;
  const _SuperStarsTab({required this.store, required this.match});

  String nameOf(String id) => store.playerName(id);

  String _teamOf(String playerId) {
    for (final t in store.teams) {
      if (t.players.any((p) => p.id == playerId)) return t.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final runs = <String, int>{};
    final balls = <String, int>{};
    final wkts = <String, int>{};
    final bowlRuns = <String, int>{};
    for (final inn in match.innings) {
      inn.batting.forEach((pid, f) {
        if (!f.batted) return;
        runs[pid] = (runs[pid] ?? 0) + f.runs;
        balls[pid] = (balls[pid] ?? 0) + f.balls;
      });
      inn.bowling.forEach((pid, f) {
        if (f.legalBalls == 0) return;
        wkts[pid] = (wkts[pid] ?? 0) + f.wickets;
        bowlRuns[pid] = (bowlRuns[pid] ?? 0) + f.runs;
      });
    }
    final topBat = runs.keys.toList()
      ..sort((a, b) => runs[b]!.compareTo(runs[a]!));
    final topBowl = wkts.keys.toList()
      ..sort((a, b) {
        if (wkts[b] != wkts[a]) return wkts[b]!.compareTo(wkts[a]!);
        return bowlRuns[a]!.compareTo(bowlRuns[b]!);
      });

    Widget starCard(int rank, String pid, String figure, String sub) {
      final medalColors = [
        const Color(0xFFFFD700), // Gold
        const Color(0xFF90A4AE), // Silver
        const Color(0xFFB87333), // Bronze
      ];
      final rankColor = rank <= 3 ? medalColors[rank - 1] : PitchTheme.surfaceContainerLow;
      final rankTextColor = rank <= 3 ? Colors.white : PitchTheme.primary;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PitchTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: PitchTheme.cardShadow,
          border: Border.all(color: PitchTheme.surfaceContainerLow),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: rankColor,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameOf(pid),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PitchTheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${_teamOf(pid)}${sub.isNotEmpty ? '  •  $sub' : ''}',
                    style: const TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              figure,
              style: const TextStyle(
                color: PitchTheme.secondary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Top Batters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: PitchTheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        if (topBat.isEmpty)
          const Text(
            'No batting yet.',
            style: TextStyle(color: PitchTheme.outline),
          ),
        for (var i = 0; i < topBat.take(3).length; i++)
          starCard(
            i + 1,
            topBat[i],
            '${runs[topBat[i]]} (${balls[topBat[i]]})',
            balls[topBat[i]]! > 0
                ? 'SR ${(runs[topBat[i]]! * 100 / balls[topBat[i]]!).toStringAsFixed(1)}'
                : '',
          ),
        const SizedBox(height: 16),
        const Text(
          'Top Bowlers',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: PitchTheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        if (topBowl.isEmpty)
          const Text(
            'No bowling yet.',
            style: TextStyle(color: PitchTheme.outline),
          ),
        for (var i = 0; i < topBowl.take(3).length; i++)
          starCard(
            i + 1,
            topBowl[i],
            '${wkts[topBowl[i]]} wkts',
            '${bowlRuns[topBowl[i]]} runs conceded',
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------- Balls tab (commentary) ----------------

class _BallsTab extends StatefulWidget {
  final Store store;
  final Match match;
  final bool isScorer;
  const _BallsTab({
    required this.store,
    required this.match,
    this.isScorer = true,
  });

  @override
  State<_BallsTab> createState() => _BallsTabState();
}

class _BallsTabState extends State<_BallsTab> {
  int inningsIdx = 0;
  int? overIdx;

  Store get store => widget.store;
  Match get match => widget.match;
  String nameOf(String id) => store.playerName(id);

  @override
  Widget build(BuildContext context) {
    if (match.innings.isEmpty) {
      return const Center(
        child: Text(
          'No balls recorded yet.',
          style: TextStyle(color: PitchTheme.outline),
        ),
      );
    }
    if (inningsIdx >= match.innings.length) inningsIdx = 0;
    final inn = match.innings[inningsIdx];
    final bpo = inn.ballsPerOver;
    final totalOvers = inn.legalBalls == 0
        ? 0
        : ((inn.legalBalls - 1) ~/ bpo) + 1;
    final selOver =
        (overIdx == null || overIdx! >= totalOvers || overIdx! < 0)
            ? totalOvers - 1
            : overIdx!;

    var legalBefore = 0;
    final numbered = <_NumberedBall>[];
    for (final e in inn.events) {
      final overNo = legalBefore ~/ bpo;
      final ballNo = legalBefore % bpo + 1;
      numbered.add(_NumberedBall(e, overNo, ballNo));
      if (e.legalBall) legalBefore++;
    }
    final overEvents = numbered.where((n) => n.overNo == selOver).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (match.innings.length > 1)
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i < match.innings.length; i++)
                ButtonSegment(
                  value: i,
                  label: Text('${i + 1}${i == 0 ? 'st' : 'nd'} Innings'),
                ),
            ],
            selected: {inningsIdx},
            onSelectionChanged: (s) => setState(() {
              inningsIdx = s.first;
              overIdx = null;
            }),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return PitchTheme.primaryContainer;
                }
                return PitchTheme.surfaceContainerLowest;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return PitchTheme.tertiaryFixed;
                }
                return PitchTheme.onSurface;
              }),
            ),
          )
        else
          Text(
            'Innings 1 - ${store.teamName(inn.battingTeamId)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: PitchTheme.onSurface,
            ),
          ),
        const SizedBox(height: 12),
        if (totalOvers > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PitchTheme.cardShadow,
              border: Border.all(color: PitchTheme.surfaceContainerLow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Over',
                      style: TextStyle(
                        color: PitchTheme.outline,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: PitchTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selOver,
                          dropdownColor: PitchTheme.surfaceContainerLowest,
                          style: const TextStyle(
                            color: PitchTheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          items: [
                            for (var o = 0; o < totalOvers; o++)
                              DropdownMenuItem(
                                value: o,
                                child: Text('Over $o'),
                              ),
                          ],
                          onChanged: (v) => setState(() => overIdx = v),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PitchTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${inn.totalRuns}/${inn.wickets} (${oversText(inn.legalBalls, bpo)})',
                        style: const TextStyle(
                          color: PitchTheme.tertiaryFixed,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final n in overEvents) _ballChip(n.event)],
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (widget.isScorer)
          const Text(
            'Tap a ball to edit or delete it (later balls are replayed).',
            style: TextStyle(color: PitchTheme.outline, fontSize: 11),
          )
        else
          const Text(
            'Ball-by-ball commentary and timeline feed.',
            style: TextStyle(color: PitchTheme.outline, fontSize: 11),
          ),
        const SizedBox(height: 12),
        const Text(
          'Commentary',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: PitchTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        for (final (idx, n) in numbered.indexed.toList().reversed)
          _commentaryRow(n, idx, inningsIdx),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _ballChip(BallEvent e) {
    final bool outlined = e.extraType == 'wide' || e.extraType == 'noBall';
    final Color fill;
    final Color textColor;
    if (e.isWicket) {
      fill = PitchTheme.error;
      textColor = Colors.white;
    } else if (outlined) {
      fill = Colors.transparent;
      textColor = PitchTheme.secondary;
    } else if (e.batRuns == 6) {
      fill = PitchTheme.primary;
      textColor = Colors.white;
    } else if (e.batRuns == 4) {
      fill = PitchTheme.secondary;
      textColor = Colors.white;
    } else {
      fill = PitchTheme.surfaceContainerLow;
      textColor = PitchTheme.onSurface;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: outlined ? Border.all(color: PitchTheme.secondary) : null,
      ),
      child: Text(
        e.display,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _commentaryRow(_NumberedBall n, int eventIdx, int innIdx) {
    final e = n.event;
    return InkWell(
      onTap: widget.isScorer ? () => _editBall(innIdx, eventIdx) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Text(
                '${n.overNo}.${n.ballNo}',
                style: const TextStyle(
                  color: PitchTheme.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _ballChip(e),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_first(nameOf(e.bowlerId))} to ${_first(nameOf(e.strikerId))}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: PitchTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _commentaryText(e),
                    style: const TextStyle(
                      color: PitchTheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isScorer)
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: PitchTheme.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBall(int innIdx, int eventIdx) async {
    final inn = match.innings[innIdx];
    if (eventIdx < 0 || eventIdx >= inn.events.length) return;
    final result = await showDialog<_BallEditResult>(
      context: context,
      builder: (_) => _BallEditDialog(
        inn: inn,
        event: inn.events[eventIdx],
        nameOf: nameOf,
      ),
    );
    if (result == null || !mounted) return;
    final edited = List.of(inn.events);
    if (result.delete) {
      edited.removeAt(eventIdx);
    } else {
      edited[eventIdx] = result.event;
    }
    final replayed = replayInningsBalls(inn, edited);
    if (replayed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This edit cannot be replayed (it breaks the recorded '
            'balls) — nothing was changed.',
          ),
        ),
      );
      return;
    }
    if (match.status == 'completed' && !replayed.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This edit would reopen a completed innings — refused. '
            'Nothing was changed.',
          ),
        ),
      );
      return;
    }
    final origResult = match.resultText.isNotEmpty
        ? match.resultText
        : computeResult(match, store.teamName);
    final origWinner = _winnerOf(origResult);
    final origTarget2 =
        match.innings.length > 1 ? match.innings[1].target : 0;
    final origResultText = match.resultText;
    match.innings[innIdx] = replayed;
    if (innIdx == 0 && match.innings.length > 1) {
      if (origTarget2 == inn.totalRuns + 1 || origTarget2 == 0) {
        match.innings[1].target = replayed.totalRuns + 1;
      }
    }
    final newResult = computeResult(match, store.teamName);
    final newWinner = _winnerOf(newResult);
    if (match.status == 'completed' &&
        origWinner != null &&
        newWinner != null &&
        origWinner != newWinner) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: PitchTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Change match winner?',
            style: TextStyle(
              color: PitchTheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This edit changes the match winner from '
            '${store.teamName(origWinner)} to ${store.teamName(newWinner)}.\n\n'
            'Do you want to confirm this scorebook correction? '
            'Tournament standings and playoffs will be updated.',
            style: const TextStyle(color: PitchTheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PitchTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm change'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        match.innings[innIdx] = inn;
        if (innIdx == 0 && match.innings.length > 1) {
          match.innings[1].target = origTarget2;
        }
        return;
      }
    }
    if (match.status == 'completed') match.resultText = newResult;
    final saved = await store.persistMatchesOnly();
    if (!saved) {
      match.innings[innIdx] = inn;
      if (innIdx == 0 && match.innings.length > 1) {
        match.innings[1].target = origTarget2;
      }
      match.resultText = origResultText;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ball edit could not be saved — try again.'),
        ),
      );
      return;
    }
    if (mounted) setState(() {});
  }

  String? _winnerOf(String result) {
    if (result.contains(' won by ')) {
      return result.split(' won by ').first.trim();
    }
    final lower = result.toLowerCase();
    if (lower.contains('tied') || lower == 'tie') return 'tie';
    return null;
  }

  String _first(String name) => name.split(' ').first;

  String _commentaryText(BallEvent e) {
    final batter = _first(nameOf(e.strikerId));
    if (e.isWicket) {
      String tail;
      switch (e.wicketType) {
        case 'bowled':
          tail = 'Bowled him! $batter departs.';
          break;
        case 'caught':
          tail = 'Caught! ${_first(nameOf(e.fielderId))} takes it.';
          break;
        case 'lbw':
          tail = 'LBW! Big appeal and the finger goes up.';
          break;
        case 'stumped':
          tail = 'Stumped! Beaten in the flight.';
          break;
        case 'runOut':
          tail = 'Run out! Sharp work in the field.';
          break;
        case 'hitWicket':
          tail = 'Hit wicket! Unlucky for $batter.';
          break;
        default:
          tail = 'Wicket falls.';
      }
      if (e.batRuns > 0) tail += ' ${e.batRuns} run(s) completed.';
      return tail;
    }
    switch (e.extraType) {
      case 'wide':
        return e.extraRuns > 0
            ? 'Wide, plus ${e.extraRuns} extra.'
            : 'Wide ball.';
      case 'noBall':
        return e.batRuns > 0
            ? 'No ball, ${e.batRuns} off the bat.'
            : 'No ball.';
      case 'bye':
        return '${e.batRuns} bye(s).';
      case 'legBye':
        return '${e.batRuns} leg bye(s).';
    }
    switch (e.batRuns) {
      case 6:
        return "Huge. It's a six!";
      case 4:
        return 'Cracked away for four.';
      case 0:
        return 'Dot ball.';
      case 1:
        return 'One run.';
      case 2:
        return 'Two runs.';
      case 3:
        return 'Three runs.';
      default:
        return '${e.batRuns} runs.';
    }
  }
}

class _BallEditResult {
  final BallEvent event;
  final bool delete;
  const _BallEditResult({required this.event, this.delete = false});
}

class _BallEditDialog extends StatefulWidget {
  final InningsState inn;
  final BallEvent event;
  final String Function(String) nameOf;
  const _BallEditDialog({
    required this.inn,
    required this.event,
    required this.nameOf,
  });

  @override
  State<_BallEditDialog> createState() => _BallEditDialogState();
}

class _BallEditDialogState extends State<_BallEditDialog> {
  static const _extraLabels = {
    'none': 'No extra',
    'wide': 'Wide',
    'noBall': 'No ball',
    'bye': 'Bye',
    'legBye': 'Leg bye',
  };
  static const _wicketLabels = {
    'bowled': 'Bowled',
    'caught': 'Caught',
    'lbw': 'LBW',
    'stumped': 'Stumped',
    'hitWicket': 'Hit wicket',
    'runOut': 'Run out',
    'mankad': 'Mankad',
    'retiredOut': 'Retired out',
    'obstructing': 'Obstructing',
    'hitTwice': 'Hit twice',
    'timedOut': 'Timed out',
  };

  static List<String> _allowedWickets(String extraType) {
    switch (extraType) {
      case 'noBall':
        return ['runOut', 'retiredOut', 'obstructing'];
      case 'wide':
        return ['stumped', 'runOut'];
      case 'bye':
      case 'legBye':
        return ['runOut'];
      default:
        return [
          'bowled',
          'caught',
          'lbw',
          'stumped',
          'hitWicket',
          'runOut',
          'mankad',
          'retiredOut',
          'obstructing',
          'hitTwice',
          'timedOut',
        ];
    }
  }

  late String _extraType;
  late TextEditingController _runs;
  late String _wicketType;
  late String _outPlayerId;
  late String _fielderId;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _extraType = e.extraType;
    _runs = TextEditingController(
      text: '${_extraType == 'wide' ? e.extraRuns : e.batRuns}',
    );
    _wicketType = e.isWicket ? e.wicketType : '';
    _outPlayerId = e.outPlayerId.isNotEmpty ? e.outPlayerId : e.strikerId;
    _fielderId = e.fielderId.isNotEmpty ? e.fielderId : e.bowlerId;
  }

  @override
  void dispose() {
    _runs.dispose();
    super.dispose();
  }

  bool get _hasWicket => _wicketType.isNotEmpty;

  void _onExtraChanged(String? v) {
    if (v == null) return;
    setState(() {
      _extraType = v == 'none' ? '' : v;
      if (_hasWicket && !_allowedWickets(_extraType).contains(_wicketType)) {
        _wicketType = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inn = widget.inn;
    final runsLabel = _extraType == 'wide'
        ? 'Extra runs (beyond wide penalty)'
        : _extraType == 'noBall'
            ? 'Runs off bat'
            : _extraType == 'bye' || _extraType == 'legBye'
                ? 'Bye runs'
                : 'Runs';
    return AlertDialog(
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Edit ball',
        style: TextStyle(
          color: PitchTheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Extra',
                style: TextStyle(
                  color: PitchTheme.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _extraType.isEmpty ? 'none' : _extraType,
                  isExpanded: true,
                  dropdownColor: PitchTheme.surfaceContainerLowest,
                  style: const TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  items: _extraLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: _onExtraChanged,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _runs,
              decoration: InputDecoration(
                labelText: runsLabel,
                labelStyle: const TextStyle(color: PitchTheme.outline),
                filled: true,
                fillColor: PitchTheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Wicket',
                style: TextStyle(
                  color: PitchTheme.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _wicketType,
                  isExpanded: true,
                  dropdownColor: PitchTheme.surfaceContainerLowest,
                  style: const TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No wicket'),
                    ),
                    ..._allowedWickets(_extraType).map((w) => DropdownMenuItem(
                          value: w,
                          child: Text(_wicketLabels[w] ?? w),
                        )),
                  ],
                  onChanged: (v) => setState(() => _wicketType = v ?? ''),
                ),
              ),
            ),
            if (_hasWicket) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Who is out?',
                  style: TextStyle(
                    color: PitchTheme.outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: inn.battingXI.contains(_outPlayerId)
                        ? _outPlayerId
                        : null,
                    hint: const Text('Select player'),
                    isExpanded: true,
                    dropdownColor: PitchTheme.surfaceContainerLowest,
                    style: const TextStyle(
                      color: PitchTheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    items: inn.battingXI
                        .map((id) => DropdownMenuItem(
                              value: id,
                              child: Text(widget.nameOf(id)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _outPlayerId = v ?? _outPlayerId),
                  ),
                ),
              ),
              if (_wicketType != 'mankad') ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fielder',
                    style: TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: inn.bowlingXI.contains(_fielderId)
                          ? _fielderId
                          : null,
                      hint: const Text('Select player'),
                      isExpanded: true,
                      dropdownColor: PitchTheme.surfaceContainerLowest,
                      style: const TextStyle(
                        color: PitchTheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      items: inn.bowlingXI
                          .map((id) => DropdownMenuItem(
                                value: id,
                                child: Text(widget.nameOf(id)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _fielderId = v ?? _fielderId),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            const Text(
              'Later balls are replayed from their recorded context, '
              'so totals, figures and fall of wickets follow this edit.',
              style: TextStyle(color: PitchTheme.outline, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: PitchTheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Delete ball?',
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: const Text(
                  'This ball is removed and later balls are replayed. '
                  'This cannot be undone.',
                  style: TextStyle(color: PitchTheme.onSurfaceVariant),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: PitchTheme.outline),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: PitchTheme.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              Navigator.pop(
                context,
                _BallEditResult(event: widget.event, delete: true),
              );
            }
          },
          child: const Text(
            'Delete ball',
            style: TextStyle(color: PitchTheme.error, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: PitchTheme.outline, fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PitchTheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final runs = int.tryParse(_runs.text.trim()) ?? 0;
            final e = widget.event;
            Navigator.pop(
              context,
              _BallEditResult(
                event: BallEvent(
                  strikerId: e.strikerId,
                  nonStrikerId: e.nonStrikerId,
                  bowlerId: e.bowlerId,
                  extraType: _extraType,
                  batRuns: _extraType == 'wide' ? 0 : runs,
                  extraRuns: _extraType == 'wide' ? runs : 0,
                  isWicket: _hasWicket,
                  wicketType: _wicketType,
                  outPlayerId: _hasWicket ? _outPlayerId : '',
                  fielderId: _hasWicket ? _fielderId : '',
                  zone: e.zone,
                  shotX: e.shotX,
                  shotY: e.shotY,
                  totalRuns: 0,
                  legalBall: false,
                ),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _NumberedBall {
  final BallEvent event;
  final int overNo;
  final int ballNo;
  _NumberedBall(this.event, this.overNo, this.ballNo);
}

// ---------------- Info tab ----------------

class _InfoTab extends StatefulWidget {
  final Store store;
  final Match match;
  const _InfoTab({required this.store, required this.match});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  int section = 0;

  Store get store => widget.store;
  Match get match => widget.match;
  String nameOf(String id) => store.playerName(id);

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('INFO')),
            ButtonSegment(value: 1, label: Text('SQUAD')),
            ButtonSegment(value: 2, label: Text('COMPARE')),
            ButtonSegment(value: 3, label: Text('H2H')),
          ],
          selected: {section},
          onSelectionChanged: (s) => setState(() => section = s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return PitchTheme.primaryContainer;
              }
              return PitchTheme.surfaceContainerLowest;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return PitchTheme.tertiaryFixed;
              }
              return PitchTheme.onSurface;
            }),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (section == 0) _infoSection(),
        if (section == 1) _squadSection(),
        if (section == 2) _compareSection(),
        if (section == 3) _h2hSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: const TextStyle(
              color: PitchTheme.outline,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: PitchTheme.onSurface,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoSection() {
    final tid = match.tournamentId;
    final tname = tid == null
        ? 'Friendly'
        : (store.tournamentById(tid)?.name ?? 'Friendly');
    final perSide = match.xiA.length >= match.xiB.length
        ? match.xiA.length
        : match.xiB.length;
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Tournament', tname),
          const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          if (match.matchTitle.isNotEmpty) ...[
            _row('Match Title', match.matchTitle),
            const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          ],
          _row('Format', 'T${match.oversLimit}'),
          const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          _row('Ball Type', match.ballType),
          const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          if (match.season.isNotEmpty) ...[
            _row('Season', match.season),
            const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          ],
          _row('Playing', '$perSide Per Side'),
          const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          _row('Overs', '${match.oversLimit}'),
          const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          if (match.venue.isNotEmpty) ...[
            _row('Venue', match.venue),
            const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          ],
          if (match.dateIso.isNotEmpty) ...[
            _row('Date', match.dateIso),
            const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          ],
          _row('Toss Won By', store.teamName(match.tossWinnerId)),
          const Divider(height: 1, color: PitchTheme.surfaceContainerLow),
          _row(
            'Chose to',
            match.tossDecision == 'bat' ? 'Bat first' : 'Bowl first',
          ),
        ],
      ),
    );
  }

  Widget _squadSection() {
    Widget teamXi(String label, List<String> xi) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: PitchTheme.primary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: PitchTheme.cardShadow,
            border: Border.all(color: PitchTheme.surfaceContainerLow),
          ),
          child: Column(
            children: [
              for (var i = 0; i < xi.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: PitchTheme.surfaceContainerLow,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: PitchTheme.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    nameOf(xi[i]),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PitchTheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
    return Column(
      children: [
        teamXi(store.teamName(match.teamAId), match.xiA),
        teamXi(store.teamName(match.teamBId), match.xiB),
      ],
    );
  }

  Widget _compareSection() {
    final stats = computeTeamStats(store.matches);
    final a = stats[match.teamAId];
    final b = stats[match.teamBId];
    Widget row(String label, String va, String vb) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              va,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: PitchTheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PitchTheme.outline,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              vb,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: PitchTheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  store.teamName(match.teamAId),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: PitchTheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'vs',
                style: TextStyle(
                  color: PitchTheme.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  store.teamName(match.teamBId),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: PitchTheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: PitchTheme.surfaceContainerLow),
          row('Played', '${a?.played ?? 0}', '${b?.played ?? 0}'),
          row('Won', '${a?.won ?? 0}', '${b?.won ?? 0}'),
          row('Lost', '${a?.lost ?? 0}', '${b?.lost ?? 0}'),
          row(
            'Win %',
            '${(a?.winPct ?? 0).toStringAsFixed(0)}%',
            '${(b?.winPct ?? 0).toStringAsFixed(0)}%',
          ),
          row(
            'Bat-first wins',
            '${a?.wonBattingFirst ?? 0}/${a?.battedFirst ?? 0}',
            '${b?.wonBattingFirst ?? 0}/${b?.battedFirst ?? 0}',
          ),
          row(
            'Chase wins',
            '${a?.wonChasing ?? 0}/${a?.chased ?? 0}',
            '${b?.wonChasing ?? 0}/${b?.chased ?? 0}',
          ),
          row('Toss won', '${a?.tossWon ?? 0}', '${b?.tossWon ?? 0}'),
        ],
      ),
    );
  }

  Widget _h2hSection() {
    final h = headToHead(store.matches, match.teamAId, match.teamBId);
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            'Total Played: ${h.played}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: PitchTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${store.teamName(match.teamAId)} wins: ${h.aWins}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: PitchTheme.primary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${store.teamName(match.teamBId)} wins: ${h.bWins}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: PitchTheme.secondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tied: ${h.tied}  •  No result: ${h.noResult}',
            style: const TextStyle(color: PitchTheme.outline, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------- Wagon wheel (per-batter picker) ----------------

class _WagonForInnings extends StatefulWidget {
  final InningsState inn;
  final String Function(String) nameOf;
  const _WagonForInnings({required this.inn, required this.nameOf});

  @override
  State<_WagonForInnings> createState() => _WagonForInningsState();
}

class _WagonForInningsState extends State<_WagonForInnings> {
  String? batterId;
  static const _wholeTeam = '__whole_team__';

  @override
  Widget build(BuildContext context) {
    final batters = widget.inn.batting.entries
        .where((e) => e.value.batted)
        .map((e) => e.key)
        .toList();
    batterId ??= batters.isNotEmpty ? batters.first : null;
    if (batterId == null) {
      return const Text(
        'No batting data.',
        style: TextStyle(color: PitchTheme.outline),
      );
    }
    if (batterId != _wholeTeam && !batters.contains(batterId)) {
      batterId = batters.first;
    }
    final isWholeTeam = batterId == _wholeTeam;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: batterId,
              isExpanded: true,
              dropdownColor: PitchTheme.surfaceContainerLowest,
              style: const TextStyle(
                color: PitchTheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              items: [
                const DropdownMenuItem(
                  value: _wholeTeam,
                  child: Text('Whole Team (Poori Team)'),
                ),
                ...batters.map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(widget.nameOf(id)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => batterId = v),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PitchTheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Center(
                child: WagonWheel(
                  shots: isWholeTeam
                      ? wagonWheelShotsTeam(widget.inn)
                      : wagonWheelShots(widget.inn, batterId!),
                ),
              ),
              const SizedBox(height: 10),
              const WagonLegend(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScorecardNavScope extends StatefulWidget {
  final String matchId;
  final Widget child;
  const _ScorecardNavScope({required this.matchId, required this.child});

  @override
  State<_ScorecardNavScope> createState() => _ScorecardNavScopeState();
}

class _ScorecardNavScopeState extends State<_ScorecardNavScope> {
  @override
  void initState() {
    super.initState();
    NavMemory.save('scorecard', widget.matchId);
  }

  @override
  void dispose() {
    NavMemory.clear('scorecard', widget.matchId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
