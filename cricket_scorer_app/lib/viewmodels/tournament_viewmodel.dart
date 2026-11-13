import 'package:flutter/foundation.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';

/// ViewModel for Tournament management in MVVM architecture.
/// Manages league points table, net run rate, playoff seeding, and manual adjustments.
class TournamentViewModel extends ChangeNotifier {
  final Store store;
  final String tournamentId;

  List<PointsRow> _pointsTable = [];
  List<PointsRow> get pointsTable => _pointsTable;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _message;
  String? get message => _message;

  TournamentViewModel({
    required this.store,
    required this.tournamentId,
  }) {
    refresh();
  }

  Tournament? get tournament => store.tournamentById(tournamentId);

  void refresh() {
    final t = tournament;
    if (t == null) return;
    _pointsTable = leaguePointsTable(t, store.matches);
    notifyListeners();
  }

  /// Recalculate playoff fixtures (GAP-14, GAP-19).
  Future<PlayoffUpdate> updatePlayoffs({bool force = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final update = await applyPlayoffUpdate(store, tournamentId, force: force);
      _message = update.message;
      refresh();
      return update;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adjust points for a team.
  Future<void> adjustPoints(String teamId, int delta) async {
    final t = tournament;
    if (t == null) return;
    final current = t.pointsAdjustments[teamId] ?? 0;
    t.pointsAdjustments[teamId] = current + delta;
    await store.persistTournamentsOnly();
    refresh();
  }

  /// Save points table override.
  Future<void> setOverride(String teamId, PointsTableOverride override) async {
    final t = tournament;
    if (t == null) return;
    t.pointsTableOverrides[teamId] = override;
    await store.persistTournamentsOnly();
    refresh();
  }
}
