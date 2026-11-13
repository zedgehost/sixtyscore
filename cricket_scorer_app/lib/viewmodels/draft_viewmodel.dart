import 'package:flutter/foundation.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/draft/draft.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

/// ViewModel for Player Draft / Auction in MVVM architecture.
/// Resolves custom round index shifting (GAP-25) and skipped pick quota exhaustion (GAP-26).
class DraftViewModel extends ChangeNotifier {
  final Store store;
  final Draft draft;

  DraftViewModel({
    required this.store,
    required this.draft,
  });

  /// Squad count excluding placeholder skipped turns (GAP-26 Fix).
  int realSquadCount(String teamId) =>
      draft.picks.where((p) => p.teamId == teamId && p.playerId.isNotEmpty).length;

  /// Effective turn order for the current turn with proper within-round indexing (GAP-25 Fix).
  DraftTurn? get currentTurn {
    if (draft.teamIds.isEmpty) return null;
    final idx = draft.picks.length;
    if (idx >= draft.totalPicks) return null;
    final teamsPerRound = draft.teamIds.length;
    final round = idx ~/ teamsPerRound + 1;
    final order = orderForRound(draft, round);
    if (order.isEmpty) return null;

    final roundStart = (round - 1) * teamsPerRound;
    final roundIdx = idx - roundStart;
    return DraftTurn(round, idx + 1, order[roundIdx % order.length]);
  }

  /// Draft a registered player to the current team.
  Future<bool> pickPlayer(RegPlayer player) async {
    final turn = currentTurn;
    if (turn == null) return false;
    if (draftedPlayerIds(draft).contains(player.id)) return false;
    if (realSquadCount(turn.teamId) >= draft.squadSize) return false;

    draft.picks.add(
      DraftPick(
        round: turn.round,
        pickNo: turn.pickNo,
        teamId: turn.teamId,
        playerId: player.id,
        playerName: player.name,
      ),
    );

    if (draft.isComplete) draft.status = 'completed';
    await store.persist();
    notifyListeners();
    return true;
  }

  /// Skip current turn without consuming the squad quota (GAP-26 Fix).
  Future<bool> skipCurrentTurn() async {
    final turn = currentTurn;
    if (turn == null) return false;

    draft.picks.add(
      DraftPick(
        round: turn.round,
        pickNo: turn.pickNo,
        teamId: turn.teamId,
        playerId: '', // Empty marker
        playerName: '— Skipped —',
      ),
    );

    if (draft.isComplete) draft.status = 'completed';
    await store.persist();
    notifyListeners();
    return true;
  }

  /// Undo the last pick or skip.
  Future<bool> undoLastPick() async {
    final ok = undoPick(draft);
    if (!ok) return false;
    await store.persist();
    notifyListeners();
    return true;
  }
}
