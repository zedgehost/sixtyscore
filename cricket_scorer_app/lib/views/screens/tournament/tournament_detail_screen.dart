// 60Score / STUMPS - Modernized Tournament Detail Screen
// Pitch Dynamic design system tokens, responsive zero-overflow layout,
// multi-format fixtures, sports telemetry cards, real-time standings,
// qualification engine, and offline-first cPanel auto-sync.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/core/utils/nav_memory.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/share/points_table_share.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';
import 'package:cricket_scorer_app/services/sync/publish_service.dart';
import 'package:cricket_scorer_app/views/screens/draft/draft_screen.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/match_setup_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/fixture_detail_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/nrr_calculator_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/qualification_chances_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournament_stats.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournaments_screen.dart'
    show showTournamentEditDialog;
import 'package:cricket_scorer_app/views/widgets/guest_guard.dart';
import 'package:cricket_scorer_app/views/widgets/player_avatar.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Store store;
  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,
    required this.store,
    required this.tournament,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Store get store => widget.store;
  Tournament get tournament => widget.tournament;

  PlayoffUpdate? _playoffUpdate;

  @override
  void initState() {
    super.initState();
    NavMemory.save('tournament', tournament.id);
    _runPlayoffUpdate();
  }

  @override
  void dispose() {
    NavMemory.clear('tournament', tournament.id);
    super.dispose();
  }

  void _triggerCloudSync() {
    CpanelSyncService(
      store: store,
      apiClient: CpanelApiClient(),
    ).triggerAutoSync();
  }

  Future<void> _runPlayoffUpdate() async {
    final update = await applyPlayoffUpdate(store, tournament.id);
    if (mounted) setState(() => _playoffUpdate = update);
  }

  Set<String> get _qualifierIds {
    final finalQ =
        _playoffUpdate?.finalQualifiers ?? tournament.qualifiedTeamIds;
    if (tournament.qualificationFinalized && finalQ.isNotEmpty) {
      return finalQ.toSet();
    }
    return (_playoffUpdate?.provisionalQualifiers ?? const <String>[]).toSet();
  }

  bool get _qualificationFinal =>
      tournament.qualificationFinalized &&
      ((_playoffUpdate?.finalQualifiers ?? tournament.qualifiedTeamIds)
          .isNotEmpty);

  Future<void> _togglePublish() async {
    final wasPublished = tournament.published;
    final svc = PublishService();
    final err = wasPublished
        ? await svc.unpublish(store, tournament)
        : await svc.publish(store, tournament);

    if (!mounted) return;
    setState(() {});
    _triggerCloudSync();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ??
              (wasPublished
                  ? 'Unpublished — it no longer appears in Search.'
                  : 'Published — anyone can find it in Search (view-only).'),
        ),
      ),
    );
  }

  Future<void> _editTournamentDetails() async {
    final updated = await showTournamentEditDialog(context, store, tournament);
    if (updated != null) {
      final idx = store.tournaments.indexWhere((t) => t.id == updated.id);
      if (idx >= 0) {
        store.tournaments[idx] = updated;
      }
      await store.persistTournamentsOnly();
      _triggerCloudSync();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament details updated successfully!')),
        );
      }
    }
  }

  Future<void> _confirmDeleteTournament() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Tournament?',
          style: TextStyle(
            color: PitchTheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${tournament.name}"? '
          'All fixtures and standings will be removed.',
          style: const TextStyle(color: PitchTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PitchTheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete Tournament'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (tournament.published) {
        PublishService().deletePublishedDoc(tournament.id);
      }
      await store.deleteTournament(tournament.id);
      _triggerCloudSync();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openFixture(Match m) async {
    late final Widget screen;
    final canScore = !AuthService().isRestrictedGuest &&
        m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);

    switch (m.status) {
      case 'live':
        screen = canScore
            ? ScoringScreen(store: store, match: m)
            : ScorecardScreen(store: store, match: m);
        break;
      case 'completed':
        screen = ScorecardScreen(store: store, match: m);
        break;
      default:
        screen = FixtureDetailScreen(store: store, matchId: m.id);
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() {});
    await _runPlayoffUpdate();
  }

  Widget _fixtureCard(Match m, {String? stageOverride}) {
    final title = m.matchTitle.isNotEmpty
        ? m.matchTitle
        : (stageOverride ?? 'League Fixture');

    final subtitle = m.resultText.isNotEmpty
        ? m.resultText
        : '${formatFixtureDate(m.dateIso)}'
            '${m.venue.isNotEmpty ? ' · ${m.venue}' : ''}';

    final teamAName = store.teamName(m.teamAId);
    final teamBName = store.teamName(m.teamBId);

    // Live or completed score summaries if match has innings
    String? teamAScoreText;
    String? teamBScoreText;
    if (m.status == 'live' || m.status == 'completed') {
      if (m.innings.isNotEmpty) {
        final inn1 = m.innings[0];
        final inn1TeamId = inn1.battingTeamId;
        final oversStr = '${inn1.legalBalls ~/ 6}.${inn1.legalBalls % 6}';
        final scoreStr = '${inn1.totalRuns}/${inn1.wickets} ($oversStr)';
        if (inn1TeamId == m.teamAId) {
          teamAScoreText = scoreStr;
        } else {
          teamBScoreText = scoreStr;
        }
      }
      if (m.innings.length > 1) {
        final inn2 = m.innings[1];
        final inn2TeamId = inn2.battingTeamId;
        final oversStr = '${inn2.legalBalls ~/ 6}.${inn2.legalBalls % 6}';
        final scoreStr = '${inn2.totalRuns}/${inn2.wickets} ($oversStr)';
        if (inn2TeamId == m.teamAId) {
          teamAScoreText = scoreStr;
        } else {
          teamBScoreText = scoreStr;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openFixture(m),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stage title and Status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: PitchTheme.secondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMatchStatusPill(m.status),
                  ],
                ),
                const SizedBox(height: 12),

                // Team A vs Team B telemetry
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CaptainAvatar(store: store, teamId: m.teamAId),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamAName.isNotEmpty ? teamAName : 'TBD',
                            style: const TextStyle(
                              color: PitchTheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (teamAScoreText != null)
                            Text(
                              teamAScoreText,
                              style: const TextStyle(
                                color: PitchTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: PitchTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            teamBName.isNotEmpty ? teamBName : 'TBD',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: PitchTheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (teamBScoreText != null)
                            Text(
                              teamBScoreText,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: PitchTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    CaptainAvatar(store: store, teamId: m.teamBId),
                  ],
                ),
                const SizedBox(height: 12),

                // Subtitle or Result Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: m.resultText.isNotEmpty
                        ? PitchTheme.secondaryContainer.withValues(alpha: 0.25)
                        : PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.resultText.isNotEmpty
                            ? Icons.emoji_events_outlined
                            : Icons.schedule_outlined,
                        size: 14,
                        color: m.resultText.isNotEmpty
                            ? PitchTheme.onSecondaryContainer
                            : PitchTheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: m.resultText.isNotEmpty
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: m.resultText.isNotEmpty
                                ? PitchTheme.onSecondaryContainer
                                : PitchTheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'live':
        bg = PitchTheme.error.withValues(alpha: 0.12);
        fg = PitchTheme.error;
        label = 'LIVE';
        break;
      case 'completed':
        bg = PitchTheme.secondaryContainer.withValues(alpha: 0.4);
        fg = PitchTheme.onSecondaryContainer;
        label = 'FINAL';
        break;
      case 'cancelled':
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        label = 'CANCELLED';
        break;
      default:
        bg = PitchTheme.surfaceContainer;
        fg = PitchTheme.primary;
        label = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.toLowerCase() == 'live') ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(
                color: PitchTheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateScheduleDialog() async {
    var teamIds = List<String>.from(tournament.teamIds);

    if (teamIds.length < 2) {
      if (store.teams.length >= 2) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: PitchTheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Enroll Teams', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              'This tournament has ${teamIds.length} teams. '
              'Auto-enroll all ${store.teams.length} registered teams?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Auto-Enroll'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          tournament.teamIds = store.teams.map((t) => t.id).toList();
          await store.persistTournamentsOnly();
          teamIds = tournament.teamIds;
          _triggerCloudSync();
        } else {
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least 2 teams before generating fixtures.'),
          ),
        );
        return;
      }
    }

    var overs = tournament.oversLimit;
    var doubleRoundRobin = false;
    var ballType = tournament.ballType.isNotEmpty ? tournament.ballType : 'Tennis Ball';

    if (!mounted) return;

    final generated = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: PitchTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Generate Fixtures', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.groups, size: 18, color: PitchTheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Participating Teams: ${teamIds.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: overs,
                  decoration: const InputDecoration(
                    labelText: 'Overs per innings',
                    border: OutlineInputBorder(),
                  ),
                  items: [5, 6, 8, 10, 12, 15, 20, 50]
                      .map((o) => DropdownMenuItem(value: o, child: Text('$o overs')))
                      .toList(),
                  onChanged: (v) => setD(() => overs = v ?? 8),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: ballType,
                  decoration: const InputDecoration(
                    labelText: 'Ball type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Tennis Ball', child: Text('Tennis Ball')),
                    DropdownMenuItem(value: 'Leather Ball', child: Text('Leather Ball')),
                    DropdownMenuItem(value: 'Tape Ball', child: Text('Tape Ball')),
                  ],
                  onChanged: (v) => setD(() => ballType = v ?? 'Tennis Ball'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Home & Away (Double Round-Robin)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  value: doubleRoundRobin,
                  activeThumbColor: PitchTheme.secondary,
                  onChanged: (v) => setD(() => doubleRoundRobin = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Generate Fixtures'),
            ),
          ],
        ),
      ),
    );

    if (generated != true) return;

    final fixtures = generateRoundRobinFixtures(
      tournamentId: tournament.id,
      teamIds: teamIds,
      oversLimit: overs,
      ballType: ballType,
      doubleRoundRobin: doubleRoundRobin,
    );

    for (final f in fixtures) {
      await store.upsertMatch(f);
    }
    _triggerCloudSync();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated ${fixtures.length} round-robin fixtures!')),
      );
    }
  }

  Future<void> _generatePlayoffsDialog() async {
    final existingPlayoffs = playoffMatchesOf(tournament.id, store.matches);

    if (existingPlayoffs.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: PitchTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Playoffs Already Exist', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'This tournament already has ${existingPlayoffs.length} playoff fixture(s). '
            'Do you want to add more playoff fixtures?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    var playoffFormat = 'semis';
    var overs = tournament.oversLimit;
    var ballType = tournament.ballType.isNotEmpty ? tournament.ballType : 'Tennis Ball';

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: PitchTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Setup Knockouts / Playoffs', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Playoff Structure:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 10),
                for (final opt in [
                  {
                    'id': 'semis',
                    'title': 'Standard Semifinals & Final',
                    'sub': 'SF1 (1v4), SF2 (2v3), Grand Final',
                  },
                  {
                    'id': 'page',
                    'title': 'IPL / Page Playoff System',
                    'sub': 'Qualifier 1, Eliminator, Qualifier 2, Final',
                  },
                  {
                    'id': 'direct_final',
                    'title': 'Direct Final (Top 2 Teams)',
                    'sub': '1st vs 2nd ranked in points table',
                  },
                ])
                  InkWell(
                    onTap: () => setD(() => playoffFormat = opt['id']!),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: playoffFormat == opt['id']
                            ? PitchTheme.secondaryContainer.withValues(alpha: 0.3)
                            : PitchTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: playoffFormat == opt['id']
                              ? PitchTheme.secondary
                              : PitchTheme.outlineVariant,
                          width: playoffFormat == opt['id'] ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            playoffFormat == opt['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: playoffFormat == opt['id']
                                ? PitchTheme.secondary
                                : PitchTheme.outline,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt['title']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  opt['sub']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PitchTheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: overs,
                  decoration: const InputDecoration(
                    labelText: 'Overs per innings',
                    border: OutlineInputBorder(),
                  ),
                  items: [5, 6, 8, 10, 12, 15, 20, 50]
                      .map((o) => DropdownMenuItem(value: o, child: Text('$o overs')))
                      .toList(),
                  onChanged: (v) => setD(() => overs = v ?? 8),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: ballType,
                  decoration: const InputDecoration(
                    labelText: 'Ball type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Tennis Ball', child: Text('Tennis Ball')),
                    DropdownMenuItem(value: 'Leather Ball', child: Text('Leather Ball')),
                    DropdownMenuItem(value: 'Tape Ball', child: Text('Tape Ball')),
                  ],
                  onChanged: (v) => setD(() => ballType = v ?? 'Tennis Ball'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Create Playoffs'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final now = DateTime.now();
    final fixtures = <Match>[];

    Match buildPlayoffMatch(String stage, String title, int dayOffset) {
      return Match(
        id: 'playoff_${tournament.id}_${stage}_${DateTime.now().millisecondsSinceEpoch}_${fixtures.length}',
        tournamentId: tournament.id,
        teamAId: '',
        teamBId: '',
        xiA: const [],
        xiB: const [],
        oversLimit: overs,
        ballsPerOver: 6,
        venue: tournament.venue,
        dateIso: now.add(Duration(days: dayOffset)).toIso8601String(),
        stage: stage,
        matchTitle: title,
        ballType: ballType,
        status: 'upcoming',
        tossWinnerId: '',
        tossDecision: 'bat',
      );
    }

    if (playoffFormat == 'semis') {
      fixtures.add(buildPlayoffMatch('semifinal1', 'Semi Final 1', 1));
      fixtures.add(buildPlayoffMatch('semifinal2', 'Semi Final 2', 1));
      fixtures.add(buildPlayoffMatch('final', 'Grand Final', 2));
    } else if (playoffFormat == 'page') {
      fixtures.add(buildPlayoffMatch('qualifier1', 'Qualifier 1', 1));
      fixtures.add(buildPlayoffMatch('eliminator', 'Eliminator', 1));
      fixtures.add(buildPlayoffMatch('qualifier2', 'Qualifier 2', 2));
      fixtures.add(buildPlayoffMatch('final', 'Grand Final', 3));
    } else if (playoffFormat == 'direct_final') {
      fixtures.add(buildPlayoffMatch('final', 'Grand Final', 1));
    }

    for (final f in fixtures) {
      await store.upsertMatch(f);
    }

    await _runPlayoffUpdate();
    _triggerCloudSync();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${fixtures.length} playoff fixtures!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = leaguePointsTable(tournament, store.matches);
    final qualifierIds = _qualifierIds;

    final leagueFixtures = store.matches
        .where((m) => m.tournamentId == tournament.id && m.stage == 'league')
        .toList()
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    final playoffFixtures = playoffMatchesOf(tournament.id, store.matches);

    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: PitchTheme.surface,
        appBar: AppBar(
          backgroundColor: PitchTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: PitchTheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            tournament.name,
            style: const TextStyle(
              color: PitchTheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          actions: [
            if (AuthService().isLoggedIn)
              IconButton(
                icon: Icon(
                  tournament.published ? Icons.public : Icons.public_off,
                  color: tournament.published ? PitchTheme.secondary : PitchTheme.outline,
                ),
                tooltip: tournament.published
                    ? 'Published — tap to unpublish'
                    : 'Publish (public, view-only)',
                onPressed: _togglePublish,
              ),
            IconButton(
              icon: const Icon(Icons.groups_outlined, color: PitchTheme.onSurface),
              tooltip: 'Tournament Draft',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DraftListScreen(
                    store: store,
                    initialTournamentId: tournament.id,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: PitchTheme.onSurface),
              tooltip: 'Share points table',
              onPressed: () => sharePointsTableImage(context, store, tournament),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: PitchTheme.onSurface),
              tooltip: 'Edit tournament details',
              onPressed: _editTournamentDetails,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: PitchTheme.error),
              tooltip: 'Delete tournament',
              onPressed: _confirmDeleteTournament,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: PitchTheme.surface,
              child: const TabBar(
                indicatorColor: PitchTheme.primary,
                indicatorWeight: 3,
                labelColor: PitchTheme.primary,
                unselectedLabelColor: PitchTheme.outline,
                labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                tabs: [
                  Tab(text: 'Fixtures'),
                  Tab(text: 'Points Table'),
                  Tab(text: 'Leaderboard Stats'),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: PitchTheme.primary,
          foregroundColor: Colors.white,
          onPressed: () async {
            if (!await requireSignedInAction(context, store,
                actionLabel: 'create tournament fixtures')) {
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchSetupScreen(
                  store: store,
                  tournamentId: tournament.id,
                ),
              ),
            ).then((_) => setState(() {}));
          },
          icon: const Icon(Icons.add),
          label: const Text(
            'New Fixture',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            // Tournament Hero Header Banner
            _buildTournamentHeroBanner(),

            // Tab Bar View
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Fixtures
                  _buildFixturesTab(leagueFixtures, playoffFixtures),

                  // Tab 2: Points Table
                  _buildPointsTableTab(rows, qualifierIds),

                  // Tab 3: Leaderboard Stats
                  TournamentStatsTab(store: store, tournament: tournament),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentHeroBanner() {
    final formatText = tournament.format.isNotEmpty ? tournament.format : 'Round Robin';
    final oversText = '${tournament.oversLimit} Overs';
    final ballText = tournament.ballType.isNotEmpty ? tournament.ballType : 'Tennis Ball';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Tournament Logo / Trophy
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PitchTheme.tertiaryFixed.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PitchTheme.tertiaryFixed.withValues(alpha: 0.6),
                  ),
                ),
                child: tournament.logoBase64.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(tournament.logoBase64),
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(
                            Icons.emoji_events,
                            color: PitchTheme.primary,
                            size: 24,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.emoji_events,
                        color: PitchTheme.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tournament.name,
                            style: const TextStyle(
                              color: PitchTheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tournament.published)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: PitchTheme.secondaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.public, size: 11, color: PitchTheme.onSecondaryContainer),
                                SizedBox(width: 4),
                                Text(
                                  'PUBLIC',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: PitchTheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (tournament.venue.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined, size: 12, color: PitchTheme.outline),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              tournament.venue,
                              style: const TextStyle(color: PitchTheme.outline, fontSize: 11.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.groups_outlined, size: 12, color: PitchTheme.outline),
                        const SizedBox(width: 3),
                        Text(
                          '${tournament.teamIds.length} Teams',
                          style: const TextStyle(color: PitchTheme.outline, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildHeroChip(Icons.military_tech_outlined, formatText),
                const SizedBox(width: 6),
                _buildHeroChip(Icons.timelapse_outlined, oversText),
                const SizedBox(width: 6),
                _buildHeroChip(Icons.sports_baseball_outlined, ballText),
                if (tournament.startDateIso.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildHeroChip(Icons.calendar_today_outlined, tournament.startDateIso),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: PitchTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PitchTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixturesTab(List<Match> leagueFixtures, List<Match> playoffFixtures) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        // Section: League Fixtures
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'League Fixtures',
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${leagueFixtures.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PitchTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.auto_mode, size: 16, color: PitchTheme.secondary),
              label: const Text(
                'Auto Fixtures',
                style: TextStyle(color: PitchTheme.secondary, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _generateScheduleDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (leagueFixtures.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.event_note, size: 40, color: PitchTheme.outline),
                const SizedBox(height: 8),
                const Text(
                  'No league fixtures yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: PitchTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Generate a full round-robin schedule or add fixtures manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: PitchTheme.outline),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: PitchTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.auto_mode, size: 16),
                  label: const Text('Generate Round-Robin Schedule'),
                  onPressed: () => _generateScheduleDialog(),
                ),
              ],
            ),
          ),

        for (final m in leagueFixtures) _fixtureCard(m),

        const SizedBox(height: 12),

        // Section: Playoffs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Knockouts & Playoffs',
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${playoffFixtures.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PitchTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.emoji_events_outlined, size: 16, color: PitchTheme.secondary),
              label: const Text(
                'Auto Knockouts',
                style: TextStyle(color: PitchTheme.secondary, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _generatePlayoffsDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (playoffFixtures.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 40, color: PitchTheme.outline),
                const SizedBox(height: 8),
                const Text(
                  'No playoff fixtures setup',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: PitchTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Setup Semifinals, Grand Final, or IPL-style Page playoffs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: PitchTheme.outline),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: PitchTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: const Text('Setup Knockouts / Playoffs'),
                  onPressed: () => _generatePlayoffsDialog(),
                ),
              ],
            ),
          ),

        for (final m in playoffFixtures)
          _fixtureCard(m, stageOverride: stageLabel(m.stage)),
      ],
    );
  }

  Widget _buildPointsTableTab(List<PointsRow> rows, Set<String> qualifierIds) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        // Action tools row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PitchTheme.primary,
                  side: const BorderSide(color: PitchTheme.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Qualification Scenarios', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QualificationChancesScreen(
                      store: store,
                      initialTournamentId: tournament.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PitchTheme.primary,
                  side: const BorderSide(color: PitchTheme.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.functions_outlined, size: 18),
                label: const Text('NRR Calculator', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NrrCalculatorScreen(
                      store: store,
                      initialTournamentId: tournament.id,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Qualifier notification badge
        if (qualifierIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PitchTheme.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                _qualificationFinal ? const QBadge() : const QBadge(provisional: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _qualificationFinal
                        ? 'Official Qualifiers confirmed for playoffs'
                        : 'Q* = provisional qualification (mathematically guaranteed)',
                    style: const TextStyle(
                      color: PitchTheme.onSecondaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Standings Data Table Container
        Container(
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(PitchTheme.surfaceContainerLow),
                columnSpacing: 14,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: PitchTheme.onSurface,
                  letterSpacing: 0.4,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 13,
                  color: PitchTheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('TEAM')),
                  DataColumn(label: Text('P')),
                  DataColumn(label: Text('W')),
                  DataColumn(label: Text('L')),
                  DataColumn(label: Text('T')),
                  DataColumn(label: Text('NR')),
                  DataColumn(label: Text('PTS')),
                  DataColumn(label: Text('NRR')),
                  DataColumn(label: Text('EDIT')),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      color: qualifierIds.contains(rows[i].teamId)
                          ? WidgetStateProperty.all(
                              PitchTheme.secondaryContainer.withValues(alpha: 0.2),
                            )
                          : null,
                      cells: [
                        DataCell(
                          Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CaptainAvatar(store: store, teamId: rows[i].teamId),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  store.teamName(rows[i].teamId),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (qualifierIds.contains(rows[i].teamId)) ...[
                                const SizedBox(width: 6),
                                _qualificationFinal
                                    ? const QBadge()
                                    : const QBadge(provisional: true),
                              ],
                              if (tournament.pointsTableOverrides.containsKey(rows[i].teamId)) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.edit, size: 14, color: Colors.amber),
                              ],
                            ],
                          ),
                          onTap: () => _editPointsRow(rows[i]),
                        ),
                        DataCell(Text('${rows[i].played}')),
                        DataCell(Text('${rows[i].won}')),
                        DataCell(Text('${rows[i].lost}')),
                        DataCell(Text('${rows[i].tied}')),
                        DataCell(Text('${rows[i].noResult}')),
                        DataCell(
                          Text(
                            '${rows[i].points}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: PitchTheme.secondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            rows[i].nrr >= 0
                                ? '+${rows[i].nrr.toStringAsFixed(3)}'
                                : rows[i].nrr.toStringAsFixed(3),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: rows[i].nrr >= 0
                                  ? PitchTheme.secondary
                                  : PitchTheme.error,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_outlined, size: 20),
                                tooltip: 'Edit points row',
                                onPressed: () => _editPointsRow(rows[i]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.tune_outlined, size: 18),
                                tooltip: 'Custom points adjustment',
                                onPressed: () => _editAdjustment(rows[i].teamId),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Text(
          'NRR calculated according to ICC rules: Aggregate runs per over scored minus conceded across the tournament. Bowled out teams count as having faced full overs.',
          style: TextStyle(fontSize: 11.5, color: PitchTheme.outline),
        ),
      ],
    );
  }

  Future<void> _editPointsRow(PointsRow row) async {
    final teamId = row.teamId;
    final existing = tournament.pointsTableOverrides[teamId];

    final cP = TextEditingController(text: '${row.played}');
    final cW = TextEditingController(text: '${row.won}');
    final cL = TextEditingController(text: '${row.lost}');
    final cT = TextEditingController(text: '${row.tied}');
    final cNR = TextEditingController(text: '${row.noResult}');
    final cPts = TextEditingController(text: '${row.points}');
    final cNrr = TextEditingController(text: row.nrr.toStringAsFixed(3));

    try {
      final action = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: PitchTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit points — ${store.teamName(teamId)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _rowField(cP, 'P (played)'),
                _rowField(cW, 'W (won)'),
                _rowField(cL, 'L (lost)'),
                _rowField(cT, 'T (tied)'),
                _rowField(cNR, 'NR (no result)'),
                _rowField(cPts, 'Pts (points)'),
                _rowField(cNrr, 'NRR (decimal)', decimal: true),
                const SizedBox(height: 8),
                const Text(
                  'Values save as an adjustment delta against auto-computed match statistics. Reset restores natural calculation.',
                  style: TextStyle(fontSize: 11, color: PitchTheme.outline),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'reset'),
                child: const Text('Reset', style: TextStyle(color: PitchTheme.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(c, null),
              child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (action == 'reset') {
        final prev = tournament.pointsTableOverrides[teamId];
        tournament.pointsTableOverrides.remove(teamId);
        final saved = await store.persistTournamentsOnly();
        _triggerCloudSync();

        if (mounted) {
          if (!saved && prev != null) {
            tournament.pointsTableOverrides[teamId] = prev;
          }
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved ? 'Points override removed.' : 'Remove failed — try again.',
              ),
            ),
          );
        }
      } else if (action == 'save') {
        int count(TextEditingController ctrl) {
          final v = int.tryParse(ctrl.text.trim());
          if (v == null || v < 0) return 0;
          return v;
        }

        final nrr = double.tryParse(cNrr.text.trim()) ?? 0;
        final prev = tournament.pointsTableOverrides[teamId];

        PointsRow? computed;
        for (final r in computePointsTable(
          tournament.id,
          tournament.teamIds,
          store.matches.where((m) => m.stage == 'league').toList(),
          pointsAdjustments: tournament.pointsAdjustments,
        )) {
          if (r.teamId == teamId) computed = r;
        }

        final base = computed ?? PointsRow(teamId);

        tournament.pointsTableOverrides[teamId] = PointsTableOverride(
          played: count(cP) - base.played,
          won: count(cW) - base.won,
          lost: count(cL) - base.lost,
          tied: count(cT) - base.tied,
          noResult: count(cNR) - base.noResult,
          points: count(cPts) - base.points,
          nrr: nrr - base.nrr,
        );
        tournament.overridesDeltaMigrated = true;

        final saved = await store.persistTournamentsOnly();
        _triggerCloudSync();

        if (mounted) {
          if (!saved) {
            if (prev != null) {
              tournament.pointsTableOverrides[teamId] = prev;
            } else {
              tournament.pointsTableOverrides.remove(teamId);
            }
          }
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved ? 'Points table override saved.' : 'Points save failed — try again.',
              ),
            ),
          );
        }
      }
    } finally {
      for (final c in [cP, cW, cL, cT, cNR, cPts, cNrr]) {
        c.dispose();
      }
    }
  }

  Widget _rowField(
    TextEditingController ctrl,
    String label, {
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(signed: true, decimal: true)
            : TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _editAdjustment(String teamId) async {
    final ctrl = TextEditingController(
      text: '${tournament.pointsAdjustments[teamId] ?? 0}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Custom points adjustment — ${store.teamName(teamId)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: 'Adjustment (added to earned points)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final v = int.tryParse(ctrl.text) ?? 0;
      final prev = tournament.pointsAdjustments[teamId];

      if (v == 0) {
        tournament.pointsAdjustments.remove(teamId);
      } else {
        tournament.pointsAdjustments[teamId] = v;
      }

      final saved = await store.persistTournamentsOnly();
      _triggerCloudSync();

      if (mounted) {
        if (!saved) {
          if (prev != null) {
            tournament.pointsAdjustments[teamId] = prev;
          } else {
            tournament.pointsAdjustments.remove(teamId);
          }
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'Points adjustment saved.' : 'Adjustment save failed — try again.',
            ),
          ),
        );
      }
    }
  }
}
