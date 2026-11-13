import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';

void main() {
  group('GAP-13: DLS Target Result Inversion Fix', () {
    test('Team 2 chasing DLS target lower than Team 1 total is declared winner', () {
      final m = Match(
        id: 'm1',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: List.generate(11, (i) => 'a$i'),
        xiB: List.generate(11, (i) => 'b$i'),
        tossWinnerId: 'teamA',
        tossDecision: 'bat',
        oversLimit: 20,
      );

      // Innings 1: Team A scores 160 in 20 overs
      final inn1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: m.xiA,
        bowlingXI: m.xiB,
        oversLimit: 20,
      );
      inn1.totalRuns = 160;
      inn1.wickets = 5;
      inn1.legalBalls = 120;
      inn1.endedEarly = true; // Complete

      // Innings 2: DLS reduced target to 95 in 10 overs
      final inn2 = InningsState(
        battingTeamId: 'teamB',
        bowlingTeamId: 'teamA',
        battingXI: m.xiB,
        bowlingXI: m.xiA,
        oversLimit: 10,
      );
      inn2.target = 95;
      inn2.totalRuns = 95; // Target achieved
      inn2.wickets = 3;
      inn2.legalBalls = 56; // 9.2 overs

      m.innings = [inn1, inn2];
      m.status = 'live';

      final res = computeResult(m, (id) => id == 'teamA' ? 'Lions' : 'Tigers');

      // Crucial verification: Tigers must win, NOT Lions!
      expect(res, contains('Tigers won by 7 wickets'));
      expect(res, contains('(DLS method)'));
      expect(m.status, 'completed');
    });

    test('Team 2 failing DLS target by 5 runs declares Team 1 winner by 5 runs', () {
      final m = Match(
        id: 'm2',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: List.generate(11, (i) => 'a$i'),
        xiB: List.generate(11, (i) => 'b$i'),
        tossWinnerId: 'teamA',
        tossDecision: 'bat',
        oversLimit: 20,
      );

      final inn1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: m.xiA,
        bowlingXI: m.xiB,
        oversLimit: 20,
      );
      inn1.totalRuns = 160;
      inn1.wickets = 5;
      inn1.legalBalls = 120;
      inn1.endedEarly = true;

      // DLS target 95. Team 2 scores 90 in full 10 overs (quota used)
      final inn2 = InningsState(
        battingTeamId: 'teamB',
        bowlingTeamId: 'teamA',
        battingXI: m.xiB,
        bowlingXI: m.xiA,
        oversLimit: 10,
      );
      inn2.target = 95;
      inn2.totalRuns = 90;
      inn2.wickets = 6;
      inn2.legalBalls = 60; // Quota reached

      m.innings = [inn1, inn2];
      final res = computeResult(m, (id) => id == 'teamA' ? 'Lions' : 'Tigers');

      // Margin is (95 - 1) - 90 = 4 runs
      expect(res, contains('Lions won by 4 runs'));
      expect(res, contains('(DLS method)'));
    });
  });

  group('GAP-14: Playoff Grand Finalist Assignment Stalling on Super Over', () {
    test('matchWinnerId returns Super Over winner when regular innings are tied', () {
      final m = Match(
        id: 'sf1',
        tournamentId: 'tourney1',
        stage: 'semifinal1',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: List.generate(11, (i) => 'a$i'),
        xiB: List.generate(11, (i) => 'b$i'),
        tossWinnerId: 'teamA',
        tossDecision: 'bat',
        status: 'completed',
      );

      final inn1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: m.xiA,
        bowlingXI: m.xiB,
        oversLimit: 20,
      );
      inn1.totalRuns = 150;
      inn1.legalBalls = 120;

      final inn2 = InningsState(
        battingTeamId: 'teamB',
        bowlingTeamId: 'teamA',
        battingXI: m.xiB,
        bowlingXI: m.xiA,
        oversLimit: 20,
      );
      inn2.totalRuns = 150; // Tied!
      inn2.legalBalls = 120;

      // Super Over Innings
      final so1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: m.xiA,
        bowlingXI: m.xiB,
        oversLimit: 1,
      );
      so1.totalRuns = 16;
      so1.legalBalls = 6;

      final so2 = InningsState(
        battingTeamId: 'teamB',
        bowlingTeamId: 'teamA',
        battingXI: m.xiB,
        bowlingXI: m.xiA,
        oversLimit: 1,
      );
      so2.totalRuns = 10;
      so2.legalBalls = 6;

      m.innings = [inn1, inn2];
      m.superOverInnings = [so1, so2];

      // matchWinnerId must return teamA
      expect(matchWinnerId(m), 'teamA');
    });
  });

  group('GAP-16: ICC DLS NRR Regulation Compliance', () {
    test('computePointsTable credits Team 1 with DLS par runs and allocated overs', () {
      final m = Match(
        id: 'm_dls',
        tournamentId: 't1',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: List.generate(11, (i) => 'a$i'),
        xiB: List.generate(11, (i) => 'b$i'),
        tossWinnerId: 'teamA',
        tossDecision: 'bat',
        status: 'completed',
        dateIso: '2026-11-07',
      );

      // Team A made 160 in 20 overs (120 balls)
      final inn1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: m.xiA,
        bowlingXI: m.xiB,
        oversLimit: 20,
      );
      inn1.totalRuns = 160;
      inn1.legalBalls = 120;

      // Team B chased DLS target 95 in 10 overs (60 balls). Team B scored 95 in 50 balls.
      final inn2 = InningsState(
        battingTeamId: 'teamB',
        bowlingTeamId: 'teamA',
        battingXI: m.xiB,
        bowlingXI: m.xiA,
        oversLimit: 10,
      );
      inn2.target = 95;
      inn2.totalRuns = 95;
      inn2.legalBalls = 50;

      m.innings = [inn1, inn2];

      final table = computePointsTable('t1', ['teamA', 'teamB'], [m]);

      final rowA = table.firstWhere((r) => r.teamId == 'teamA');
      final rowB = table.firstWhere((r) => r.teamId == 'teamB');

      // Team B won -> 2 points, Team A lost -> 0 points
      expect(rowB.won, 1);
      expect(rowB.points, 2);
      expect(rowA.lost, 1);
      expect(rowA.points, 0);

      // Under ICC Clause 16.10.2:
      // Team A runsFor = Target - 1 = 94, ballsFor = 60 (10 overs)
      expect(rowA.runsFor, 94);
      expect(rowA.ballsFor, 60);

      // Team B runsAgainst = 94, ballsAgainst = 60
      expect(rowB.runsAgainst, 94);
      expect(rowB.ballsAgainst, 60);

      // Team B runsFor = 95, ballsFor = 50
      expect(rowB.runsFor, 95);
      expect(rowB.ballsFor, 50);
    });
  });

  group('GAP-18: Bowler Incapacitation Mid-Over', () {
    test('replaceCurrentBowler allows another bowler to finish the over without consecutive violation', () {
      final inn = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: ['a1', 'a2', 'a3'],
        bowlingXI: ['b1', 'b2', 'b3'],
        oversLimit: 5,
      );

      inn.strikerId = 'a1';
      inn.nonStrikerId = 'a2';
      inn.lastBowlerId = 'b1'; // bowled previous over

      // Bowler b2 starts the over
      expect(setBowler(inn, 'b2'), isTrue);
      expect(inn.currentBowlerId, 'b2');

      // Bowler b2 bowls 1 legal ball
      applyBall(inn, BallInput(batRuns: 1));
      expect(inn.bowling['b2']!.runs, 1);
      expect(inn.bowling['b2']!.legalBalls, 1);

      // Bowler b2 is injured! Try to replace with b1 (previous bowler - disallowed!)
      expect(replaceCurrentBowler(inn, 'b1'), isFalse);

      // Replace with b3 (fresh bowler)
      expect(replaceCurrentBowler(inn, 'b3'), isTrue);
      expect(inn.currentBowlerId, 'b3');

      // Bowler b3 bowls next ball
      applyBall(inn, BallInput(batRuns: 2));
      expect(inn.bowling['b3']!.runs, 2);
      expect(inn.bowling['b3']!.legalBalls, 1);
      // Bowler b2 figures remain intact
      expect(inn.bowling['b2']!.runs, 1);
      expect(inn.bowling['b2']!.legalBalls, 1);
    });
  });
}
