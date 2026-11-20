// 60Score / STUMPS - Modernized Tournament Detail Screen
// Pitch Dynamic design system tokens, responsive zero-overflow layout,
// multi-format fixtures, sports telemetry cards, real-time standings,
// qualification engine, and offline-first cPanel auto-sync.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/core/utils/nav_memory.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/share/points_table_share.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';
import 'package:cricket_scorer_app/services/sync/publish_service.dart';
import 'package:cricket_scorer_app/services/sync/live_match_telemetry_hub.dart';
import 'package:cricket_scorer_app/views/screens/draft/draft_screen.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/match_setup_screen.dart';
import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/fixture_detail_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/nrr_calculator_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/qualification_chances_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/tournament_stats.dart';
import 'package:cricket_scorer_app/views/screens/teams/teams_screen.dart'
    show TeamDetailScreen;
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
  Timer? _liveTournamentPollTimer;
  bool _isPollingTournament = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStoreChanged);
    NavMemory.save('tournament', tournament.id);
    if (!tournament.published) {
      tournament.published = true;
      store.persistTournamentsOnly();
      _triggerCloudSync();
    }
    _runPlayoffUpdate();
    _startLiveTournamentPolling();
  }

  void _startLiveTournamentPolling() {
    final tMatchIds = store.matches
        .where((m) => m.tournamentId == tournament.id)
        .map((m) => m.id)
        .toList();
    LiveMatchTelemetryHub.instance.watchMatches(tMatchIds, store: store);
    LiveMatchTelemetryHub.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    final tMatchIds = store.matches
        .where((m) => m.tournamentId == tournament.id)
        .map((m) => m.id)
        .toList();
    LiveMatchTelemetryHub.instance.unwatchMatches(tMatchIds);
    LiveMatchTelemetryHub.instance.removeListener(_onStoreChanged);
    _liveTournamentPollTimer?.cancel();
    store.removeListener(_onStoreChanged);
    NavMemory.clear('tournament', tournament.id);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pollTournamentMatches() async {
    if (!mounted || _isPollingTournament) return;
    _isPollingTournament = true;
    try {
      final tMatchIds = store.matches
          .where((m) => m.tournamentId == tournament.id)
          .map((m) => m.id)
          .toList();
      LiveMatchTelemetryHub.instance.watchMatches(tMatchIds, store: store);
    } finally {
      _isPollingTournament = false;
    }
  }

  void _triggerCloudSync() {
    CpanelSyncService.triggerAutoSyncFor(store);
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

  /// Strict ownership check: Only the tournament creator/owner can edit details,
  /// delete tournament, manage teams, edit points table, or generate fixtures.
  bool get isTournamentOwner {
    if (AuthService().isRestrictedGuest) return false;
    final uid = store.effectiveUserId;
    if (tournament.creatorId.isNotEmpty) {
      return uid.isNotEmpty && tournament.creatorId == uid;
    }
    return true;
  }

  Future<void> _editTournamentDetails() async {
    if (!isTournamentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator can edit tournament details.')),
      );
      return;
    }
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
    if (!isTournamentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator can delete this tournament.')),
      );
      return;
    }
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
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          await client.deleteTournament(tournament.id);
        } catch (_) {}
      }());
      _triggerCloudSync();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openFixture(Match m) async {
    final fresh = store.matchById(m.id) ?? m;
    final hasWinnerResult = fresh.resultText.isNotEmpty && fresh.status != 'noResult';
    final hasBothInningsDone = fresh.innings.length >= 2 && fresh.innings[1].isComplete;
    final isMatchCompleted = fresh.status == 'completed' || hasWinnerResult || hasBothInningsDone;

    if (isMatchCompleted && fresh.status != 'completed') {
      fresh.status = 'completed';
      if (fresh.resultText.isEmpty) {
        final res = computeResult(fresh, store.teamName);
        if (res.isNotEmpty) fresh.resultText = res;
      }
      await store.persistMatchesOnly();
      _triggerCloudSync();
    }

    late final Widget screen;
    final canScore = !AuthService().isRestrictedGuest &&
        (isTournamentOwner || fresh.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode));

    if (isMatchCompleted) {
      screen = ScorecardScreen(store: store, match: fresh, isScorer: canScore);
    } else if (fresh.status == 'live') {
      screen = canScore
          ? ScoringScreen(store: store, match: fresh)
          : ScorecardScreen(store: store, match: fresh, isScorer: false);
    } else {
      screen = FixtureDetailScreen(store: store, matchId: fresh.id);
    }

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() {});
    await _runPlayoffUpdate();
  }

  Future<void> _showEditFixtureDialog(Match m) async {
    final canEdit = isTournamentOwner ||
        m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator or match scorer can edit this fixture.')),
      );
      return;
    }
    DateTime selectedDate;
    TimeOfDay selectedTime;
    try {
      if (m.dateIso.contains('T')) {
        final dt = DateTime.parse(m.dateIso);
        selectedDate = DateTime(dt.year, dt.month, dt.day);
        selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      } else if (m.dateIso.isNotEmpty) {
        final dt = DateTime.parse(m.dateIso);
        selectedDate = DateTime(dt.year, dt.month, dt.day);
        selectedTime = const TimeOfDay(hour: 14, minute: 0);
      } else {
        selectedDate = DateTime.now();
        selectedTime = const TimeOfDay(hour: 14, minute: 0);
      }
    } catch (_) {
      selectedDate = DateTime.now();
      selectedTime = const TimeOfDay(hour: 14, minute: 0);
    }

    final venueCtrl = TextEditingController(text: m.venue.isNotEmpty ? m.venue : tournament.venue);
    final titleCtrl = TextEditingController(text: m.matchTitle);

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final formattedCurrent = formatFixtureDate(
            '${selectedDate.year.toString().padLeft(4, '0')}-'
            '${selectedDate.month.toString().padLeft(2, '0')}-'
            '${selectedDate.day.toString().padLeft(2, '0')}T'
            '${selectedTime.hour.toString().padLeft(2, '0')}:'
            '${selectedTime.minute.toString().padLeft(2, '0')}:00',
          );

          return AlertDialog(
            backgroundColor: PitchTheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_calendar, color: PitchTheme.primary, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Fixture Schedule',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${store.teamName(m.teamAId)} vs ${store.teamName(m.teamBId)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: PitchTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Match Title (optional)
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Match Title / Label',
                      hintText: 'e.g. Match 1, League Match, Final',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date & Time Picker Tile
                  const Text(
                    'Scheduled Date & Time',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PitchTheme.outline),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: c,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (pickedDate == null) return;

                      if (!c.mounted) return;
                      final pickedTime = await showTimePicker(
                        context: c,
                        initialTime: selectedTime,
                      );
                      if (pickedTime == null) return;

                      setD(() {
                        selectedDate = pickedDate;
                        selectedTime = pickedTime;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: PitchTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PitchTheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: PitchTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formattedCurrent,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: PitchTheme.outline),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Venue
                  TextField(
                    controller: venueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ground / Venue',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    ),
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
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final iso =
          '${selectedDate.year.toString().padLeft(4, '0')}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}T'
          '${selectedTime.hour.toString().padLeft(2, '0')}:'
          '${selectedTime.minute.toString().padLeft(2, '0')}:00';

      m.dateIso = iso;
      m.venue = venueCtrl.text.trim();
      if (titleCtrl.text.trim().isNotEmpty) {
        m.matchTitle = titleCtrl.text.trim();
      }

      await store.persistMatchesOnly();
      _triggerCloudSync();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fixture schedule updated successfully!')),
        );
      }
    }
  }

  Future<void> _showEndMatchDialog(Match m) async {
    final teamAName = store.teamName(m.teamAId);
    final teamBName = store.teamName(m.teamBId);
    final autoResult = computeResult(m, store.teamName);

    final selected = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: PitchTheme.secondary, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'End Match & Declare Result',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select how this match concludes. This will mark the match as completed and update the tournament standings.',
              style: TextStyle(fontSize: 12.5, color: PitchTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (autoResult.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome, color: PitchTheme.secondary),
                title: Text(autoResult, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Calculated from current innings scores'),
                onTap: () => Navigator.pop(c, 'auto'),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline, color: PitchTheme.primary),
              title: Text('$teamAName Won', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('Opponent conceded / forfeited'),
              onTap: () => Navigator.pop(c, 'teamA'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline, color: PitchTheme.primary),
              title: Text('$teamBName Won', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('Opponent conceded / forfeited'),
              onTap: () => Navigator.pop(c, 'teamB'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.handshake_outlined, color: PitchTheme.outline),
              title: const Text('Match Tied', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('Scores level / mutually agreed tie'),
              onTap: () => Navigator.pop(c, 'tie'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
        ],
      ),
    );

    if (selected != null) {
      if (selected == 'auto' && autoResult.isNotEmpty) {
        m.resultText = autoResult;
      } else if (selected == 'teamA') {
        m.resultText = '$teamAName won by forfeit';
      } else if (selected == 'teamB') {
        m.resultText = '$teamBName won by forfeit';
      } else if (selected == 'tie') {
        m.resultText = 'Match tied';
      }
      m.status = 'completed';
      await store.persistMatchesOnly();
      _triggerCloudSync();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match marked completed: ${m.resultText}')),
        );
      }
      await _runPlayoffUpdate();
    }
  }

  Future<void> _resetMatchToUpcoming(Match m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset to Upcoming?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will clear unbowled innings and return the fixture to UPCOMING status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      m.status = 'upcoming';
      m.innings = [];
      m.superOverInnings = [];
      m.resultText = '';
      m.tossWinnerId = '';
      m.tossDecision = 'bat';
      await store.persistMatchesOnly();
      _triggerCloudSync();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match reset to Upcoming!')),
        );
      }
    }
  }

  Future<void> _markMatchNoResult(Match m) async {
    m.status = 'noResult';
    m.resultText = 'No result';
    await store.persistMatchesOnly();
    _triggerCloudSync();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match marked as No Result.')),
      );
    }
    await _runPlayoffUpdate();
  }

  Widget _fixtureCard(Match rawM, {String? stageOverride}) {
    final m = LiveMatchTelemetryHub.instance.getLiveMatch(rawM.id) ?? store.matchById(rawM.id) ?? rawM;
    final hasWinnerResult = m.resultText.isNotEmpty && m.status != 'noResult';
    final hasBothInningsDone = m.innings.length >= 2 && m.innings[1].isComplete;
    final isMatchCompleted = m.status == 'completed' || hasWinnerResult || hasBothInningsDone;

    if (isMatchCompleted && m.status != 'completed') {
      m.status = 'completed';
      if (m.resultText.isEmpty) {
        final res = computeResult(m, store.teamName);
        if (res.isNotEmpty) m.resultText = res;
      }
      store.persistMatchesOnly();
    }
    final effectiveStatus = isMatchCompleted ? 'completed' : m.status;
    final canScoreThisMatch = !AuthService().isRestrictedGuest &&
        (isTournamentOwner || m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode));

    final title = m.matchTitle.isNotEmpty
        ? m.matchTitle
        : (stageOverride ?? 'League Fixture');

    final subtitle = m.resultText.isNotEmpty
        ? m.resultText
        : (effectiveStatus == 'live'
            ? (m.innings.length >= 2
                ? 'Target: ${m.innings[1].target} runs · In Progress'
                : (m.innings.isNotEmpty
                    ? '1st Innings in progress'
                    : 'Match Live · Tap to score'))
            : '${formatFixtureDate(m.dateIso)}${m.venue.isNotEmpty ? ' · ${m.venue}' : ''}');

    final teamAName = store.teamName(m.teamAId);
    final teamBName = store.teamName(m.teamBId);

    // Live or completed score summaries if match has innings
    String? teamAScoreText;
    String? teamBScoreText;
    if (m.status == 'live' || effectiveStatus == 'completed') {
      InningsState? innA;
      InningsState? innB;

      for (final inn in m.innings) {
        final bId = inn.battingTeamId.trim();
        if (bId.isNotEmpty) {
          if (bId == m.teamAId && innA == null) innA = inn;
          if (bId == m.teamBId && innB == null) innB = inn;
        }
      }

      if (innA == null && innB == null && m.innings.isNotEmpty) {
        final teamABatsFirst = m.battingFirstId == m.teamAId;
        if (teamABatsFirst) {
          innA = m.innings[0];
          if (m.innings.length > 1) innB = m.innings[1];
        } else {
          innB = m.innings[0];
          if (m.innings.length > 1) innA = m.innings[1];
        }
      } else if (innA != null && innB == null && m.innings.length > 1) {
        innB = m.innings.firstWhere((i) => i != innA, orElse: () => m.innings[1]);
      } else if (innB != null && innA == null && m.innings.length > 1) {
        innA = m.innings.firstWhere((i) => i != innB, orElse: () => m.innings[0]);
      }

      if (innA != null) {
        final oversStr = '${innA.legalBalls ~/ 6}.${innA.legalBalls % 6}';
        teamAScoreText = '${innA.totalRuns}/${innA.wickets} ($oversStr)';
      }
      if (innB != null) {
        final oversStr = '${innB.legalBalls ~/ 6}.${innB.legalBalls % 6}';
        teamBScoreText = '${innB.totalRuns}/${innB.wickets} ($oversStr)';
      }

      // If live and one team hasn't batted yet, show "Yet to bat" or "0/0 (0.0)"
      if (m.status == 'live') {
        teamAScoreText ??= m.innings.isEmpty
            ? '0/0 (0.0)'
            : (m.innings.length == 1 ? 'Yet to bat' : '0/0 (0.0)');
        teamBScoreText ??= m.innings.isEmpty
            ? '0/0 (0.0)'
            : (m.innings.length == 1 ? 'Yet to bat' : '0/0 (0.0)');
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
                // Stage title, Status badge, and Edit button
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
                    _buildMatchStatusPill(effectiveStatus),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canScoreThisMatch)
                          IconButton(
                            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                            color: PitchTheme.outline,
                            tooltip: 'Edit fixture schedule & venue',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _showEditFixtureDialog(m),
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: PitchTheme.outline),
                          tooltip: 'Match options',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onSelected: (action) async {
                            if (action == 'edit_schedule') {
                              _showEditFixtureDialog(m);
                            } else if (action == 'resume_score') {
                              _openFixture(m);
                            } else if (action == 'view_scorecard') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScorecardScreen(
                                    store: store,
                                    match: m,
                                    isScorer: canScoreThisMatch,
                                  ),
                                ),
                              );
                            } else if (action == 'end_match') {
                              _showEndMatchDialog(m);
                            } else if (action == 'reset_upcoming') {
                              _resetMatchToUpcoming(m);
                            } else if (action == 'no_result') {
                              _markMatchNoResult(m);
                            }
                          },
                          itemBuilder: (ctx) {
                            if (!canScoreThisMatch) {
                              return const [
                                PopupMenuItem(
                                  value: 'view_scorecard',
                                  child: Row(
                                    children: [
                                      Icon(Icons.table_chart_outlined, size: 17, color: PitchTheme.outline),
                                      SizedBox(width: 8),
                                      Text('View Scorecard'),
                                    ],
                                  ),
                                ),
                              ];
                            }
                            return [
                              const PopupMenuItem(
                                value: 'edit_schedule',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_calendar_outlined, size: 17, color: PitchTheme.outline),
                                    SizedBox(width: 8),
                                    Text('Edit Schedule & Venue'),
                                  ],
                                ),
                              ),
                              if (effectiveStatus == 'live') ...[
                                const PopupMenuItem(
                                  value: 'resume_score',
                                  child: Row(
                                    children: [
                                      Icon(Icons.sports_cricket, size: 17, color: PitchTheme.primary),
                                      SizedBox(width: 8),
                                      Text('Resume Scoring'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'view_scorecard',
                                  child: Row(
                                    children: [
                                      Icon(Icons.table_chart_outlined, size: 17, color: PitchTheme.outline),
                                      SizedBox(width: 8),
                                      Text('View Scorecard'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'end_match',
                                  child: Row(
                                    children: [
                                      Icon(Icons.emoji_events_outlined, size: 17, color: PitchTheme.secondary),
                                      SizedBox(width: 8),
                                      Text('End / Concede Match'),
                                    ],
                                  ),
                                ),
                                if (m.innings.isEmpty || m.innings.every((i) => i.legalBalls == 0))
                                  const PopupMenuItem(
                                    value: 'reset_upcoming',
                                    child: Row(
                                      children: [
                                        Icon(Icons.restart_alt, size: 17, color: PitchTheme.outline),
                                        SizedBox(width: 8),
                                        Text('Reset to Upcoming'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'no_result',
                                  child: Row(
                                    children: [
                                      Icon(Icons.block, size: 17, color: PitchTheme.error),
                                      SizedBox(width: 8),
                                      Text('Declare No Result'),
                                    ],
                                  ),
                                ),
                              ],
                              if (effectiveStatus == 'completed') ...[
                                const PopupMenuItem(
                                  value: 'view_scorecard',
                                  child: Row(
                                    children: [
                                      Icon(Icons.table_chart_outlined, size: 17, color: PitchTheme.outline),
                                      SizedBox(width: 8),
                                      Text('View Scorecard'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'resume_score',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 17, color: PitchTheme.primary),
                                      SizedBox(width: 8),
                                      Text('Reopen for Scoring'),
                                    ],
                                  ),
                                ),
                              ],
                            ];
                          },
                        ),
                      ],
                    ),
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
                      if (effectiveStatus != 'completed')
                        InkWell(
                          onTap: () => _showEditFixtureDialog(m),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(Icons.edit_outlined, size: 14, color: PitchTheme.outline),
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

    final overs = tournament.oversLimit;
    var doubleRoundRobin = false;
    final ballType = tournament.ballType.isNotEmpty ? tournament.ballType : 'Tennis Ball';

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups, size: 18, color: PitchTheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Participating Teams: ${teamIds.length}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.timelapse_outlined, size: 18, color: PitchTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$overs Overs per innings (from tournament)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.sports_baseball_outlined, size: 18, color: PitchTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$ballType (from tournament)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Home & Away (Double Round-Robin)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    'Each team plays against each other twice',
                    style: TextStyle(fontSize: 11.5, color: PitchTheme.outline),
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
      creatorId: store.effectiveUserId,
      creatorName: store.profile?.displayName ?? '',
      creatorCode: store.effectiveUserCode,
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
    final overs = tournament.oversLimit;
    final ballType = tournament.ballType.isNotEmpty ? tournament.ballType : 'Tennis Ball';

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
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: PitchTheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Matches: $overs Overs · $ballType (from tournament specs)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PitchTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    // Reconcile completed status for all tournament fixtures before computing standings
    for (final m in store.matches) {
      if (m.tournamentId == tournament.id) {
        final hasWinnerResult = m.resultText.isNotEmpty && m.status != 'noResult';
        final hasBothInningsDone = m.innings.length >= 2 && m.innings[1].isComplete;
        if ((hasWinnerResult || hasBothInningsDone) && m.status != 'completed') {
          m.status = 'completed';
          if (m.resultText.isEmpty) {
            final res = computeResult(m, store.teamName);
            if (res.isNotEmpty) m.resultText = res;
          }
        }
      }
    }

    final rows = leaguePointsTable(tournament, store.matches);
    final qualifierIds = _qualifierIds;

    final leagueFixtures = store.matches
        .where((m) => m.tournamentId == tournament.id && m.stage == 'league')
        .toList()
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    final playoffFixtures = playoffMatchesOf(tournament.id, store.matches);

    return DefaultTabController(
      length: 5,
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
            if (isTournamentOwner) ...[
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
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: PitchTheme.surface,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: PitchTheme.primary,
                indicatorWeight: 3,
                labelColor: PitchTheme.primary,
                unselectedLabelColor: PitchTheme.outline,
                labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                tabs: [
                  Tab(text: 'Fixtures'),
                  Tab(text: 'Points Table'),
                  Tab(text: 'Teams & Squads'),
                  Tab(text: 'Leaderboards'),
                  Tab(text: 'Overview & Rules'),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: isTournamentOwner
            ? FloatingActionButton.extended(
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
              )
            : null,
        body: TabBarView(
          children: [
            // Tab 1: Fixtures (hero banner is exclusively in this tab)
            _buildFixturesTab(leagueFixtures, playoffFixtures),

            // Tab 2: Points Table
            _buildPointsTableTab(rows, qualifierIds),

            // Tab 3: Teams & Squads
            _buildTeamsTab(),

            // Tab 4: Leaderboard Stats
            TournamentStatsTab(store: store, tournament: tournament),

            // Tab 5: Overview & Specifications
            _buildOverviewTab(leagueFixtures, playoffFixtures),
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
    return RefreshIndicator(
      onRefresh: _pollTournamentMatches,
      color: PitchTheme.primary,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 90),
        children: [
        // Tournament Hero Header Banner (displayed exclusively on Fixtures tab)
        _buildTournamentHeroBanner(),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (isTournamentOwner)
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
                      Text(
                        isTournamentOwner
                            ? 'Generate a full round-robin schedule or add fixtures manually.'
                            : 'No fixtures have been scheduled for this tournament yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: PitchTheme.outline),
                      ),
                      if (isTournamentOwner) ...[
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
                  if (isTournamentOwner)
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
                      Text(
                        isTournamentOwner
                            ? 'Setup Semifinals, Grand Final, or IPL-style Page playoffs.'
                            : 'Playoff stage has not started yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: PitchTheme.outline),
                      ),
                      if (isTournamentOwner) ...[
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
                    ],
                  ),
                ),

              for (final m in playoffFixtures)
                _fixtureCard(m, stageOverride: stageLabel(m.stage)),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPointsTableTab(List<PointsRow> rows, Set<String> qualifierIds) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: const Column(
              children: [
                Icon(Icons.table_chart_outlined, size: 40, color: PitchTheme.outline),
                SizedBox(height: 10),
                Text(
                  'Points Table Empty',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: PitchTheme.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Enroll teams and record matches to see standings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: PitchTheme.outline),
                ),
              ],
            ),
          )
        else
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
                  columnSpacing: 16,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: PitchTheme.onSurface,
                    letterSpacing: 0.4,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 13,
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  columns: const [
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('P')),
                    DataColumn(label: Text('W')),
                    DataColumn(label: Text('L')),
                    DataColumn(label: Text('T')),
                    DataColumn(label: Text('PTS')),
                    DataColumn(label: Text('RUN RATE')),
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
                            onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null,
                          ),
                          DataCell(Text('${rows[i].played}'), onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null),
                          DataCell(Text('${rows[i].won}'), onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null),
                          DataCell(Text('${rows[i].lost}'), onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null),
                          DataCell(Text('${rows[i].tied}'), onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null),
                          DataCell(
                            Text(
                              '${rows[i].points}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: PitchTheme.secondary,
                                fontSize: 14,
                              ),
                            ),
                            onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null,
                          ),
                          DataCell(
                            Text(
                              rows[i].nrr >= 0
                                  ? '+${rows[i].nrr.toStringAsFixed(3)}'
                                  : rows[i].nrr.toStringAsFixed(3),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: rows[i].nrr >= 0
                                    ? PitchTheme.secondary
                                    : PitchTheme.error,
                              ),
                            ),
                            onTap: isTournamentOwner ? () => _editPointsRow(rows[i]) : null,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editPointsRow(PointsRow row) async {
    if (!isTournamentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator can edit the points table.')),
      );
      return;
    }
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
            TextButton(
              onPressed: () {
                Navigator.pop(c, null);
                _editAdjustment(teamId);
              },
              child: const Text('Custom Adjustment', style: TextStyle(color: PitchTheme.secondary)),
            ),
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

  // ---------------------------------------------------------------------------
  // TAB 3: TEAMS & SQUADS MANAGEMENT
  // ---------------------------------------------------------------------------

  Widget _buildTeamsTab() {
    final enrolledTeamIds = tournament.teamIds;
    final enrolledTeams = enrolledTeamIds
        .map((id) => store.teamById(id))
        .whereType<Team>()
        .toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        // Action Header - Responsive zero-overflow layout
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Participating Teams',
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
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
                    '${enrolledTeams.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PitchTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (isTournamentOwner) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PitchTheme.primary,
                        side: const BorderSide(color: PitchTheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.playlist_add, size: 17),
                      label: const Text(
                        'Enroll Teams',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      onPressed: _showEnrollTeamsDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: PitchTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text(
                        'New Team',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      onPressed: _showCreateTeamForTournamentDialog,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        if (enrolledTeams.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_outlined, size: 36, color: PitchTheme.secondary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No teams enrolled yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: PitchTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add existing teams or create new squads to start generating fixtures and tracking standings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: PitchTheme.outline),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: PitchTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.playlist_add, size: 16),
                      label: const Text('Enroll Existing Teams'),
                      onPressed: _showEnrollTeamsDialog,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PitchTheme.primary,
                        side: const BorderSide(color: PitchTheme.outlineVariant),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create New Team'),
                      onPressed: _showCreateTeamForTournamentDialog,
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          ...enrolledTeams.map((team) {
            final matchesCount = store.matches
                .where((m) => m.tournamentId == tournament.id && (m.teamAId == team.id || m.teamBId == team.id))
                .length;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamDetailScreen(store: store, team: team),
                    ),
                  ).then((_) {
                    if (mounted) setState(() {});
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CaptainAvatar(store: store, teamId: team.id),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          team.name,
                                          style: const TextStyle(
                                            color: PitchTheme.onSurface,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: PitchTheme.surfaceContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          team.teamCode,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: PitchTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${team.players.length} Squad Players · $matchesCount Tournament Fixtures',
                                    style: const TextStyle(
                                      color: PitchTheme.outline,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.sports_cricket, size: 14, color: PitchTheme.secondary),
                                SizedBox(width: 4),
                                Text(
                                  'Active Squad',
                                  style: TextStyle(
                                    color: PitchTheme.onSurfaceVariant,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: PitchTheme.secondary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.people_alt_outlined, size: 15),
                                  label: const Text(
                                    'View Squad',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TeamDetailScreen(store: store, team: team),
                                    ),
                                  ).then((_) {
                                    if (mounted) setState(() {});
                                  }),
                                ),
                                if (isTournamentOwner)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(4),
                                    icon: const Icon(Icons.delete_outline, size: 18, color: PitchTheme.error),
                                    tooltip: 'Remove from tournament',
                                    onPressed: () => _removeTeamFromTournament(team),
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
          }),
      ],
    );
  }

  Future<void> _showEnrollTeamsDialog() async {
    if (!isTournamentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator can enroll teams.')),
      );
      return;
    }
    final currentSelected = Set<String>.from(tournament.teamIds);
    String query = '';

    final savedSelected = await showDialog<Set<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final filteredTeams = store.teams.where((t) {
            final q = query.trim().toLowerCase();
            return q.isEmpty ||
                t.name.toLowerCase().contains(q) ||
                t.teamCode.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: PitchTheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enroll Teams',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: PitchTheme.onSurface,
                  ),
                ),
                Text(
                  '${currentSelected.length} Selected',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PitchTheme.secondary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search teams...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      fillColor: PitchTheme.surfaceContainerLow,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setD(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setD(() {
                          currentSelected.addAll(store.teams.map((t) => t.id));
                        }),
                        child: const Text('Select All', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => setD(() {
                          currentSelected.clear();
                        }),
                        child: const Text('Clear All', style: TextStyle(fontSize: 12, color: PitchTheme.error)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: filteredTeams.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No teams registered yet',
                                  style: TextStyle(color: PitchTheme.outline),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(c);
                                    _showCreateTeamForTournamentDialog();
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Create New Team'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredTeams.length,
                            itemBuilder: (_, i) {
                              final tm = filteredTeams[i];
                              final isChecked = currentSelected.contains(tm.id);
                              return CheckboxListTile(
                                value: isChecked,
                                activeColor: PitchTheme.secondary,
                                title: Text(
                                  tm.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                subtitle: Text(
                                  '${tm.players.length} Players • ${tm.teamCode}',
                                  style: const TextStyle(fontSize: 11, color: PitchTheme.outline),
                                ),
                                onChanged: (v) {
                                  setD(() {
                                    if (v == true) {
                                      currentSelected.add(tm.id);
                                    } else {
                                      currentSelected.remove(tm.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, null),
                child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
                onPressed: () => Navigator.pop(c, currentSelected),
                child: const Text('Save Teams'),
              ),
            ],
          );
        },
      ),
    );

    if (savedSelected != null) {
      tournament.teamIds = savedSelected.toList();
      await store.persistTournamentsOnly();
      _triggerCloudSync();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated tournament teams (${tournament.teamIds.length} enrolled)')),
        );
      }
    }
  }

  Future<void> _showCreateTeamForTournamentDialog() async {
    if (!isTournamentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator can add new teams.')),
      );
      return;
    }
    final nameCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create & Enroll New Team',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Team Name *',
                hintText: 'e.g. Lahore Qalandars',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(c, true);
            },
            child: const Text('Create & Enroll'),
          ),
        ],
      ),
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      final newTeam = Team(
        id: 'team_${DateTime.now().millisecondsSinceEpoch}',
        name: nameCtrl.text.trim(),
        players: [],
      );

      await store.upsertTeam(newTeam);
      if (!tournament.teamIds.contains(newTeam.id)) {
        tournament.teamIds.add(newTeam.id);
        await store.persistTournamentsOnly();
      }
      _triggerCloudSync();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team "${newTeam.name}" created and enrolled into tournament!')),
        );
      }
    }
  }

  Future<void> _removeTeamFromTournament(Team team) async {
    if (!isTournamentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the tournament creator can remove teams.')),
      );
      return;
    }
    final matchesInTournament = store.matches
        .where((m) => m.tournamentId == tournament.id && (m.teamAId == team.id || m.teamBId == team.id))
        .length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove ${team.name}?',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          matchesInTournament > 0
              ? 'Warning: This team is involved in $matchesInTournament scheduled or completed match(es) in this tournament. Are you sure you want to remove it?'
              : 'Remove "${team.name}" from this tournament?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PitchTheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove Team'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      tournament.teamIds.remove(team.id);
      await store.persistTournamentsOnly();
      _triggerCloudSync();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${team.name} from tournament.')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 5: OVERVIEW & TOURNAMENT SPECIFICATIONS
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab(List<Match> leagueFixtures, List<Match> playoffFixtures) {
    final totalMatches = leagueFixtures.length + playoffFixtures.length;
    final completedMatches = store.matches
        .where((m) => m.tournamentId == tournament.id && m.status == 'completed')
        .length;
    final liveMatches = store.matches
        .where((m) => m.tournamentId == tournament.id && m.status == 'live')
        .length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      children: [
        // Tournament Progress Telemetry
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 18, color: PitchTheme.secondary),
                  SizedBox(width: 8),
                  Text(
                    'Tournament Progression',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: PitchTheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Total Matches', '$totalMatches', PitchTheme.onSurface),
                  _buildStatColumn('Live Now', '$liveMatches', PitchTheme.error),
                  _buildStatColumn('Completed', '$completedMatches', PitchTheme.secondary),
                  _buildStatColumn('Teams', '${tournament.teamIds.length}', PitchTheme.primary),
                ],
              ),
            ],
          ),
        ),

        // Tournament Rules & Specs Card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.rule_outlined, size: 18, color: PitchTheme.secondary),
                  SizedBox(width: 8),
                  Text(
                    'Competition Specifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: PitchTheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSpecRow('Competition Format', tournament.format.isNotEmpty ? tournament.format : 'Round Robin'),
              _buildSpecRow('Overs Limit', '${tournament.oversLimit} Overs per side'),
              _buildSpecRow('Match Ball', tournament.ballType.isNotEmpty ? tournament.ballType : 'Tennis Ball'),
              _buildSpecRow('Primary Venue', tournament.venue.isNotEmpty ? tournament.venue : 'Official Grounds'),
              if (tournament.startDateIso.isNotEmpty)
                _buildSpecRow('Commencement', tournament.startDateIso),
              _buildSpecRow('Points for Victory', '2 Points'),
              _buildSpecRow('Points for Tie / No Result', '1 Point'),
              _buildSpecRow('Net Run Rate Metric', 'ICC Standard aggregate equation'),
            ],
          ),
        ),

        // Quick Admin Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_outlined, size: 18, color: PitchTheme.secondary),
                  SizedBox(width: 8),
                  Text(
                    'Tournament Management',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: PitchTheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isTournamentOwner) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined, color: PitchTheme.primary),
                  title: const Text('Edit Tournament Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: const Text('Update name, venue, ball type, overs limit', style: TextStyle(fontSize: 11, color: PitchTheme.outline)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: _editTournamentDetails,
                ),
                const Divider(height: 1),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined, color: PitchTheme.primary),
                title: const Text('Player Auction / Draft', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Live bidding & team draft management', style: TextStyle(fontSize: 11, color: PitchTheme.outline)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DraftListScreen(
                      store: store,
                      initialTournamentId: tournament.id,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_outlined, color: PitchTheme.primary),
                title: const Text('Share Points Table', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Export branded PNG standings card', style: TextStyle(fontSize: 11, color: PitchTheme.outline)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => sharePointsTableImage(context, store, tournament),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calculate_outlined, color: PitchTheme.primary),
                title: const Text('Qualification Scenarios', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Mathematical qualification chances & pathways', style: TextStyle(fontSize: 11, color: PitchTheme.outline)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QualificationChancesScreen(
                      store: store,
                      initialTournamentId: tournament.id,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.functions_outlined, color: PitchTheme.primary),
                title: const Text('ICC NRR Calculator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Run rate differential simulator for remaining matches', style: TextStyle(fontSize: 11, color: PitchTheme.outline)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.push(
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
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: PitchTheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: PitchTheme.outline, fontSize: 12.5)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              val,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: PitchTheme.onSurface,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
