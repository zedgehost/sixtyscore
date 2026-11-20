import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/account_profile.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/viewmodels/scorecard_edit_viewmodel.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Security & Rules Audit Suite', () {
    late Store store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = Store();
      await store.activateIdentity('user_alice_123');
      store.profile = AccountProfile.create(
        uid: 'user_alice_123',
        displayName: 'Alice Scorer',
      );
    });

    test('Case 1: ScorecardEditViewModel prevents unauthorized non-scorer from saving edits', () async {
      final match = Match(
        id: 'm_foreign_1',
        creatorId: 'user_bob_456',
        teamAId: 'team_a',
        teamBId: 'team_b',
        xiA: ['p1', 'p2'],
        xiB: ['p3', 'p4'],
        tossWinnerId: 'team_a',
        oversLimit: 10,
        ballsPerOver: 6,
        status: 'completed',
      );
      match.innings = [
        InningsState(
          battingTeamId: 'team_a',
          bowlingTeamId: 'team_b',
          battingXI: ['p1', 'p2'],
          bowlingXI: ['p3', 'p4'],
          oversLimit: 10,
        )..totalRuns = 80,
      ];
      store.matches = [match];

      final vm = ScorecardEditViewModel(store: store, match: match);

      // Alice tries to edit Bob's match
      final editedInnings = [
        InningsState(
          battingTeamId: 'team_a',
          bowlingTeamId: 'team_b',
          battingXI: ['p1', 'p2'],
          bowlingXI: ['p3', 'p4'],
          oversLimit: 10,
        )..totalRuns = 99,
      ];

      final success = await vm.saveInningsEdits(editedInnings);
      expect(success, isFalse, reason: 'Alice should be forbidden from modifying Bob match');
      expect(match.innings[0].totalRuns, 80, reason: 'Match score must remain unaltered');
    });

    test('Case 2: ScorecardEditViewModel allows tournament owner to edit scorecard of match in their tournament', () async {
      // Alice owns tournament 'tourn_alice_1'
      final tournament = Tournament(
        id: 'tourn_alice_1',
        name: 'Super League',
        venue: 'Main Ground',
        creatorId: 'user_alice_123',
      );
      store.tournaments = [tournament];

      // Bob scored the match, but it belongs to Alice's tournament
      final match = Match(
        id: 'm_in_tourn_1',
        creatorId: 'user_bob_456',
        tournamentId: 'tourn_alice_1',
        teamAId: 'team_a',
        teamBId: 'team_b',
        xiA: ['p1', 'p2'],
        xiB: ['p3', 'p4'],
        tossWinnerId: 'team_a',
        oversLimit: 10,
        ballsPerOver: 6,
        status: 'completed',
      );
      match.innings = [
        InningsState(
          battingTeamId: 'team_a',
          bowlingTeamId: 'team_b',
          battingXI: ['p1', 'p2'],
          bowlingXI: ['p3', 'p4'],
          oversLimit: 10,
        )..totalRuns = 80,
        InningsState(
          battingTeamId: 'team_b',
          bowlingTeamId: 'team_a',
          battingXI: ['p3', 'p4'],
          bowlingXI: ['p1', 'p2'],
          oversLimit: 10,
        )..totalRuns = 70,
      ];
      store.matches = [match];

      final vm = ScorecardEditViewModel(store: store, match: match);

      final editedInnings = [
        InningsState(
          battingTeamId: 'team_a',
          bowlingTeamId: 'team_b',
          battingXI: ['p1', 'p2'],
          bowlingXI: ['p3', 'p4'],
          oversLimit: 10,
        )..batting['p1'] = (BatFig()..batted = true..runs = 85),
        InningsState(
          battingTeamId: 'team_b',
          bowlingTeamId: 'team_a',
          battingXI: ['p3', 'p4'],
          bowlingXI: ['p1', 'p2'],
          oversLimit: 10,
        )..batting['p3'] = (BatFig()..batted = true..runs = 70),
      ];

      final success = await vm.saveInningsEdits(editedInnings);
      expect(success, isTrue, reason: 'Tournament owner Alice must be authorized to edit scorecard');
      expect(match.innings[0].totalRuns, 85);
    });

    test('Case 3: Restricted guest is rejected from saving scorecard edits even on their own matches', () async {
      await AuthService().setGuestMode();

      final match = Match(
        id: 'm_guest_1',
        creatorId: 'user_alice_123',
        teamAId: 'team_a',
        teamBId: 'team_b',
        xiA: ['p1', 'p2'],
        xiB: ['p3', 'p4'],
        tossWinnerId: 'team_a',
        oversLimit: 10,
        ballsPerOver: 6,
        status: 'completed',
      );
      match.innings = [
        InningsState(
          battingTeamId: 'team_a',
          bowlingTeamId: 'team_b',
          battingXI: ['p1', 'p2'],
          bowlingXI: ['p3', 'p4'],
          oversLimit: 10,
        )..totalRuns = 50,
      ];
      store.matches = [match];

      final vm = ScorecardEditViewModel(store: store, match: match);
      final success = await vm.saveInningsEdits(match.innings);
      expect(success, isFalse, reason: 'Restricted guest should not be allowed to persist edits');

      await AuthService().signOut();
    });

    test('Case 4: ICC 16.10 NRR all-out rule correctly penalizes all-out teams with full quota balls', () {
      final innAllOut = InningsState(
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        battingXI: List.generate(11, (i) => 'p$i'),
        bowlingXI: List.generate(11, (i) => 'b$i'),
        oversLimit: 20,
        ballsPerOver: 6,
      );
      // Team A bowled out for 100 in only 10.0 overs (60 balls)
      innAllOut.totalRuns = 100;
      innAllOut.legalBalls = 60;
      innAllOut.wickets = 10;

      expect(innAllOut.wickets >= innAllOut.effectiveMaxWickets, isTrue);

      final match = Match(
        id: 'm_nrr_test_1',
        tournamentId: 't_nrr',
        teamAId: 'team_a',
        teamBId: 'team_b',
        xiA: List.generate(11, (i) => 'p$i'),
        xiB: List.generate(11, (i) => 'b$i'),
        tossWinnerId: 'team_a',
        oversLimit: 20,
        ballsPerOver: 6,
        status: 'completed',
      );
      final innChase = InningsState(
        battingTeamId: 'team_b',
        bowlingTeamId: 'team_a',
        battingXI: List.generate(11, (i) => 'b$i'),
        bowlingXI: List.generate(11, (i) => 'p$i'),
        oversLimit: 20,
        ballsPerOver: 6,
      );
      // Team B chased 101 in 10 overs without losing all wickets
      innChase.totalRuns = 101;
      innChase.legalBalls = 60;
      innChase.wickets = 2;
      innChase.target = 101;

      match.innings = [innAllOut, innChase];

      final table = computePointsTable('t_nrr', ['team_a', 'team_b'], [match]);
      final rowA = table.firstWhere((r) => r.teamId == 'team_a');
      final rowB = table.firstWhere((r) => r.teamId == 'team_b');

      // Team A: bowled out in 60 balls, but assessed 120 balls (20.0 overs)
      expect(rowA.ballsFor, 120, reason: 'All-out Team A must be assessed full 120 balls');
      expect(rowA.runsFor, 100);
      expect(rowA.ballsAgainst, 60, reason: 'Team B chased in 60 balls, so Team A conceded 60 balls');
      expect(rowA.runsAgainst, 101);

      // Team B: chased in 60 balls (10.0 overs), faced 60 balls
      expect(rowB.ballsFor, 60, reason: 'Winning chase only counts actual balls faced');
      expect(rowB.runsFor, 101);
      expect(rowB.ballsAgainst, 120, reason: 'Team B bowled Team A out, credited with full 120 balls');
      expect(rowB.runsAgainst, 100);

      // Team A NRR: (100 / 20.0) - (101 / 10.0) = 5.0 - 10.1 = -5.10
      expect(rowA.nrr, closeTo(-5.10, 0.001));

      // Team B NRR: (101 / 10.0) - (100 / 20.0) = 10.1 - 5.0 = +5.10
      expect(rowB.nrr, closeTo(5.10, 0.001));
    });

    test('Case 5: ICC Clause 16.10.2 DLS par adjustment in computePointsTable', () {
      final match = Match(
        id: 'm_dls_nrr_1',
        tournamentId: 't_dls',
        teamAId: 'team_a',
        teamBId: 'team_b',
        xiA: List.generate(11, (i) => 'p$i'),
        xiB: List.generate(11, (i) => 'b$i'),
        tossWinnerId: 'team_a',
        oversLimit: 20,
        ballsPerOver: 6,
        status: 'completed',
      );
      final inn1 = InningsState(
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        battingXI: List.generate(11, (i) => 'p$i'),
        bowlingXI: List.generate(11, (i) => 'b$i'),
        oversLimit: 20,
        ballsPerOver: 6,
      );
      inn1.totalRuns = 160;
      inn1.legalBalls = 120;
      inn1.wickets = 6;

      final inn2 = InningsState(
        battingTeamId: 'team_b',
        bowlingTeamId: 'team_a',
        battingXI: List.generate(11, (i) => 'b$i'),
        bowlingXI: List.generate(11, (i) => 'p$i'),
        oversLimit: 15, // Rain reduced to 15 overs
        ballsPerOver: 6,
      );
      inn2.totalRuns = 135;
      inn2.legalBalls = 90;
      inn2.wickets = 5;
      inn2.target = 140; // DLS revised target != 160 + 1

      match.innings = [inn1, inn2];

      final table = computePointsTable('t_dls', ['team_a', 'team_b'], [match]);
      final rowA = table.firstWhere((r) => r.teamId == 'team_a');

      // Team 1 is credited with (Target - 1) = 139 runs off the 15 overs (90 balls) allocated to Team 2
      expect(rowA.runsFor, 139);
      expect(rowA.ballsFor, 90);
    });
  });
}
