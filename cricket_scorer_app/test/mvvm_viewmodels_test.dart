import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/viewmodels/scoring_viewmodel.dart';
import 'package:cricket_scorer_app/viewmodels/tournament_viewmodel.dart';
import 'package:cricket_scorer_app/viewmodels/scorecard_edit_viewmodel.dart';
import 'package:cricket_scorer_app/viewmodels/draft_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MVVM: ScoringViewModel Tests', () {
    test('ScoringViewModel records ball and handles bowler replacement mid-over', () async {
      final store = Store();
      final match = Match(
        id: 'm_vm',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: ['a1', 'a2', 'a3'],
        xiB: ['b1', 'b2', 'b3'],
        tossWinnerId: 'teamA',
        tossDecision: 'bat',
      );

      final inn = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: match.xiA,
        bowlingXI: match.xiB,
        oversLimit: 5,
      );
      inn.strikerId = 'a1';
      inn.nonStrikerId = 'a2';
      inn.currentBowlerId = 'b1';

      match.innings = [inn];

      final vm = ScoringViewModel(store: store, match: match);

      expect(vm.currentInnings.totalRuns, 0);

      // Record 1 run
      final recorded = await vm.recordBall(BallInput(batRuns: 1));
      expect(recorded, isTrue);
      expect(vm.currentInnings.totalRuns, 1);
      expect(vm.currentInnings.strikerId, 'a2'); // Rotated

      // Replace injured bowler mid-over (GAP-18)
      final replaced = await vm.replaceInjuredBowler('b2');
      expect(replaced, isTrue);
      expect(vm.currentInnings.currentBowlerId, 'b2');

      // Undo last ball
      final undone = await vm.undoLastBall();
      expect(undone, isTrue);
      expect(vm.currentInnings.totalRuns, 0);
    });
  });

  group('MVVM: TournamentViewModel Tests', () {
    test('TournamentViewModel adjusts points and manages league points table', () async {
      final store = Store();
      final t = Tournament(
        id: 't_vm',
        name: 'Super Cup',
        teamIds: ['team1', 'team2'],
      );
      store.tournaments.add(t);

      final vm = TournamentViewModel(store: store, tournamentId: 't_vm');
      expect(vm.pointsTable.length, 2);

      await vm.adjustPoints('team1', 2);
      expect(t.pointsAdjustments['team1'], 2);
    });
  });

  group('MVVM: ScorecardEditViewModel Tests', () {
    test('ScorecardEditViewModel preserves DLS target on edit save (GAP-15)', () async {
      final store = Store();
      final match = Match(
        id: 'm_edit_vm',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: ['a1', 'a2'],
        xiB: ['b1', 'b2'],
        tossWinnerId: 'teamA',
        status: 'completed',
      );

      final inn1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: match.xiA,
        bowlingXI: match.xiB,
        oversLimit: 20,
      );
      inn1.totalRuns = 160;

      final inn2 = InningsState(
        battingTeamId: 'teamB',
        bowlingTeamId: 'teamA',
        battingXI: match.xiB,
        bowlingXI: match.xiA,
        oversLimit: 10,
      );
      inn2.target = 95; // DLS target
      inn2.totalRuns = 95;

      match.innings = [inn1, inn2];

      final vm = ScorecardEditViewModel(store: store, match: match);

      // Save an edit to inn1 (e.g. bowler runs correction)
      final ok = await vm.saveInningsEdits([inn1, inn2]);
      expect(ok, isTrue);

      // DLS target must remain 95, NOT reverted to 161!
      expect(match.innings[1].target, 95);
    });
  });

  group('MVVM: DraftViewModel Tests', () {
    test('DraftViewModel properly computes squad size without counting skipped picks (GAP-26)', () async {
      final store = Store();
      final draft = Draft(
        id: 'd1',
        name: 'Premier Draft',
        tournamentId: 't1',
        teamIds: ['team1', 'team2'],
        squadSize: 3,
      );

      final vm = DraftViewModel(store: store, draft: draft);

      final reg1 = RegPlayer(id: 'p1', name: 'Player 1');

      // Team 1 picks Player 1
      await vm.pickPlayer(reg1);
      expect(vm.realSquadCount('team1'), 1);

      // Team 2 skips their turn
      await vm.skipCurrentTurn();
      expect(vm.realSquadCount('team2'), 0); // Skipped turn does not consume real player count!

      // Team 1 can pick another player
      final reg2 = RegPlayer(id: 'p2', name: 'Player 2');
      await vm.pickPlayer(reg2);
      expect(vm.realSquadCount('team1'), 2);
    });
  });
}
