import 'package:flutter/foundation.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart' as engine;
import 'package:cricket_scorer_app/domain/scoring/scoring.dart' show BallInput;
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';
import 'package:cricket_scorer_app/services/audio/tts_service.dart';

/// ViewModel for live match scoring in MVVM architecture.
/// Manages innings state, delivery recording, strike rotation,
/// bowler incapacitation (Law 17.8), undo history, and DLS target integration.
class ScoringViewModel extends ChangeNotifier {
  final Store store;
  final Match match;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _lastError;
  String? get lastError => _lastError;

  ScoringViewModel({
    required this.store,
    required this.match,
  });

  InningsState get currentInnings =>
      match.innings.isEmpty ? throw StateError('No innings') : match.innings.last;

  int get inningsIndex => match.innings.length - 1;
  bool get isFirstInnings => match.innings.length == 1;
  bool get isSecondInnings => match.innings.length == 2;

  String playerName(String id) => store.playerName(id);
  String teamName(String id) => store.teamName(id);

  /// Apply one delivery to the live innings.
  Future<bool> recordBall(BallInput input) async {
    final inn = currentInnings;
    if (inn.isComplete) return false;

    final strikerBefore = inn.strikerId;
    final runsBefore = inn.batting[strikerBefore]?.runs ?? 0;
    final legalBefore = inn.legalBalls;

    final ok = engine.applyBall(inn, input);
    if (!ok) return false;

    await _afterChange();
    _triggerTtsVoice(input, strikerBefore, runsBefore, legalBefore);
    notifyListeners();
    return true;
  }

  /// Undo the last delivery.
  Future<bool> undoLastBall() async {
    final inn = currentInnings;
    final ok = engine.undoLastBall(inn);
    if (!ok) return false;

    await _afterChange();
    notifyListeners();
    return true;
  }

  /// Choose next bowler for a new over.
  Future<bool> chooseBowler(String bowlerId) async {
    final inn = currentInnings;
    final ok = engine.setBowler(inn, bowlerId);
    if (!ok) return false;

    await _afterChange();
    notifyListeners();
    return true;
  }

  /// Replace bowler mid-over (MCC Law 17.8 — bowler incapacitation).
  Future<bool> replaceInjuredBowler(String newBowlerId) async {
    final inn = currentInnings;
    final ok = engine.replaceCurrentBowler(inn, newBowlerId);
    if (!ok) return false;

    await _afterChange();
    notifyListeners();
    return true;
  }

  /// Apply DLS revised target.
  Future<void> applyDlsTarget(int target) async {
    final inn = currentInnings;
    inn.target = target;
    await _afterChange();
    notifyListeners();
  }

  /// End current innings early (e.g. declaration or rain).
  Future<void> endInningsEarly() async {
    final inn = currentInnings;
    inn.endedEarly = true;
    await _afterChange();
    notifyListeners();
  }

  /// Mark match as no result.
  Future<void> markNoResult() async {
    match.status = 'noResult';
    match.resultText = 'No result';
    await store.persistMatchesOnly();
    final tid = match.tournamentId;
    if (tid != null && tid.isNotEmpty) {
      await applyPlayoffUpdate(store, tid);
    }
    notifyListeners();
  }

  Future<void> _afterChange() async {
    _isSaving = true;
    try {
      engine.computeResult(match, store.teamName);
      final saved = await store.persistMatchesOnly();
      if (!saved) {
        _lastError = 'Ball could not be saved to local disk.';
      }
      final tid = match.tournamentId;
      if (tid != null && tid.isNotEmpty && match.status == 'completed') {
        try {
          await applyPlayoffUpdate(store, tid);
        } catch (_) {}
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isSaving = false;
    }
  }

  void _triggerTtsVoice(BallInput input, String strikerBefore, int runsBefore, int legalBefore) {
    final tts = TtsService.instance;
    if (!tts.enabled) return;
    final s = currentInnings;
    final phrases = <String>[];

    if (input.isWicket && s.events.isNotEmpty) {
      phrases.add(ttsWicket(
        batsmanName: playerName(s.events.last.outPlayerId),
        teamName: teamName(s.battingTeamId),
        runs: s.totalRuns,
        wickets: s.wickets,
      ));
    }

    if (strikerBefore.isNotEmpty) {
      final runsAfter = s.batting[strikerBefore]?.runs ?? 0;
      if ((runsBefore < 50 && runsAfter >= 50) || (runsBefore < 100 && runsAfter >= 100)) {
        phrases.add(ttsMilestone(
          batsmanName: playerName(strikerBefore),
          runs: runsAfter,
        ));
      }
    }

    if (s.legalBalls > legalBefore && s.legalBalls % s.ballsPerOver == 0) {
      phrases.add(ttsOverSummary(
        teamName: teamName(s.battingTeamId),
        runs: s.totalRuns,
        wickets: s.wickets,
        oversText: oversText(s.legalBalls, s.ballsPerOver),
        target: s.target > 0 ? s.target : null,
        ballsBowled: s.legalBalls,
        ballsTotal: s.oversLimit * s.ballsPerOver,
      ));
    }

    // GAP-23: Concatenate phrases to avoid TTS truncation on over boundaries
    if (phrases.isNotEmpty) {
      tts.speak(phrases.join(' ... '));
    }
  }
}
