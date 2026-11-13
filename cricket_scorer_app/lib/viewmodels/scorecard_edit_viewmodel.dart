import 'package:flutter/foundation.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';

/// ViewModel for post-match scorecard corrections in MVVM architecture.
/// Ensures DLS targets are preserved (GAP-15) and winner alterations
/// are explicitly confirmed rather than hard-blocked (GAP-20).
class ScorecardEditViewModel extends ChangeNotifier {
  final Store store;
  final Match match;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  ScorecardEditViewModel({
    required this.store,
    required this.match,
  });

  String get originalWinner {
    final res = match.resultText.isNotEmpty
        ? match.resultText
        : computeResult(match, store.teamName);
    return res;
  }

  /// Recomputes totals from figures and saves matches only.
  Future<bool> saveInningsEdits(List<InningsState> editedInnings) async {
    _isSaving = true;
    notifyListeners();

    try {
      for (var i = 0; i < editedInnings.length; i++) {
        final inn = editedInnings[i];
        recomputeInningsTotals(inn);
        inn.undoStack = [];
      }

      // GAP-15: Preserve DLS / custom target if it was not standard chase
      if (editedInnings.length > 1) {
        final origTarget = match.innings.length > 1 ? match.innings[1].target : 0;
        final origInn0Total = match.innings.isNotEmpty ? match.innings[0].totalRuns : 0;
        if (origTarget == 0 || origTarget == origInn0Total + 1) {
          editedInnings[1].target = editedInnings[0].totalRuns + 1;
        } else {
          editedInnings[1].target = origTarget;
        }
      }

      match.innings = editedInnings;
      final text = computeResult(match, store.teamName);
      if (text.isNotEmpty) match.resultText = text;

      final saved = await store.persistMatchesOnly();
      if (!saved) return false;

      // Update playoffs if applicable
      final tid = match.tournamentId;
      if (tid != null) {
        try {
          await applyPlayoffUpdate(store, tid);
        } catch (_) {}
      }
      return true;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
