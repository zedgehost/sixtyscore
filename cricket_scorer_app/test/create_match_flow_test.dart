import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/views/screens/tournament/fixture_detail_screen.dart';

void main() {
  group('Create Match Flow & Tournament Stage Tests', () {
    test('MatchDraft.toUpcomingFixture creates upcoming scheduled match', () {
      final draft = MatchDraft(
        teamAId: 'team_a',
        teamBId: 'team_b',
        oversLimit: 20,
        ballsPerOver: 6,
        venue: 'Gaddafi Stadium',
        dateIso: '2026-11-20T15:00:00',
        matchTitle: 'PSL Qualifier 1',
        ballType: 'Leather',
        stage: 'qualifier1',
      );

      final upcoming = draft.toUpcomingFixture();
      expect(upcoming.status, 'upcoming');
      expect(upcoming.stage, 'qualifier1');
      expect(upcoming.teamAId, 'team_a');
      expect(upcoming.teamBId, 'team_b');
      expect(upcoming.oversLimit, 20);
      expect(upcoming.venue, 'Gaddafi Stadium');
      expect(upcoming.matchTitle, 'PSL Qualifier 1');
      expect(upcoming.ballType, 'Leather');
      expect(upcoming.innings, isEmpty);
    });

    test('MatchDraft.toMatch creates live match with stage and toss', () {
      final draft = MatchDraft(
        teamAId: 'team_a',
        teamBId: 'team_b',
        oversLimit: 10,
        stage: 'final',
        tossWinnerId: 'team_b',
        tossDecision: 'bowl',
        xiA: ['p1', 'p2', 'p3'],
        xiB: ['p4', 'p5', 'p6'],
      );

      final liveMatch = draft.toMatch();
      expect(liveMatch.status, 'live');
      expect(liveMatch.stage, 'final');
      expect(liveMatch.tossWinnerId, 'team_b');
      expect(liveMatch.tossDecision, 'bowl');
      expect(liveMatch.xiA, ['p1', 'p2', 'p3']);
      expect(liveMatch.xiB, ['p4', 'p5', 'p6']);
    });

    test('MatchDraft.fromMatch reconstructs draft from scheduled fixture', () {
      final existingFixture = Match(
        id: 'fixture_123',
        tournamentId: 'tourn_99',
        teamAId: 'alpha',
        teamBId: 'bravo',
        xiA: const [],
        xiB: const [],
        oversLimit: 8,
        venue: 'Islamabad Club',
        dateIso: '2026-12-01T10:00:00',
        stage: 'semifinal1',
        matchTitle: 'Semi Final Clash',
        ballType: 'Tape Ball',
        status: 'upcoming',
        tossWinnerId: '',
        tossDecision: 'bat',
      );

      final draft = MatchDraft.fromMatch(existingFixture);
      expect(draft.existingMatch?.id, 'fixture_123');
      expect(draft.tournamentId, 'tourn_99');
      expect(draft.teamAId, 'alpha');
      expect(draft.teamBId, 'bravo');
      expect(draft.oversLimit, 8);
      expect(draft.stage, 'semifinal1');
      expect(draft.matchTitle, 'Semi Final Clash');
      expect(draft.ballType, 'Tape Ball');

      // Now simulating conducting toss and starting match
      draft.tossWinnerId = 'alpha';
      draft.tossDecision = 'bat';
      draft.xiA = ['a1', 'a2'];
      draft.xiB = ['b1', 'b2'];

      final startedMatch = draft.toMatch();
      expect(startedMatch.id, 'fixture_123'); // in-place update, never duplicate
      expect(startedMatch.status, 'live');
      expect(startedMatch.stage, 'semifinal1');
      expect(startedMatch.tossWinnerId, 'alpha');
      expect(startedMatch.tossDecision, 'bat');
    });

    test('stageLabel correctly formats all tournament stages and friendly types', () {
      expect(stageLabel('league'), 'League Fixture');
      expect(stageLabel('qualifier1'), 'Qualifier 1');
      expect(stageLabel('eliminator'), 'Eliminator');
      expect(stageLabel('qualifier2'), 'Qualifier 2');
      expect(stageLabel('semifinal1'), 'Semi Final 1');
      expect(stageLabel('semifinal2'), 'Semi Final 2');
      expect(stageLabel('final'), 'Grand Final');
      expect(stageLabel('playoff'), 'Playoff Match');
      expect(stageLabel('friendly'), 'Friendly Match');
      expect(stageLabel('unknown_stage'), 'League Fixture');
    });

    test('Standalone match defaults to friendly stage without tournamentId', () {
      final standaloneDraft = MatchDraft(
        teamAId: 'team_x',
        teamBId: 'team_y',
        oversLimit: 20,
        stage: 'friendly',
        tournamentId: null,
      );

      final fixture = standaloneDraft.toUpcomingFixture();
      expect(fixture.tournamentId, isNull);
      expect(fixture.stage, 'friendly');

      final liveMatch = standaloneDraft.toMatch();
      expect(liveMatch.tournamentId, isNull);
      expect(liveMatch.stage, 'friendly');
    });
    test('InningsState.effectiveMaxWickets handles empty or single-player XI safely without premature completion', () {
      final emptyXiInn = InningsState(
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        battingXI: const [],
        bowlingXI: const [],
        oversLimit: 20,
      );
      // Previously evaluated to -1 which made isComplete true at 0 wickets!
      expect(emptyXiInn.effectiveMaxWickets, 10);
      expect(emptyXiInn.isComplete, isFalse);

      final singleXiInn = InningsState(
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        battingXI: const ['p1'],
        bowlingXI: const ['p2'],
        oversLimit: 20,
      );
      expect(singleXiInn.effectiveMaxWickets, 10);
      expect(singleXiInn.isComplete, isFalse);

      final fiveXiInn = InningsState(
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        battingXI: const ['p1', 'p2', 'p3', 'p4', 'p5'],
        bowlingXI: const ['b1', 'b2', 'b3', 'b4', 'b5'],
        oversLimit: 5,
      );
      expect(fiveXiInn.effectiveMaxWickets, 4);

      fiveXiInn.maxWickets = 3;
      expect(fiveXiInn.effectiveMaxWickets, 3);
    });

    test('Match.battingFirstId correctly defaults to teamAId when tossWinnerId is empty', () {
      final preTossMatch = Match(
        id: 'm1',
        teamAId: 'team_alpha',
        teamBId: 'team_beta',
        xiA: const [],
        xiB: const [],
        oversLimit: 20,
        tossWinnerId: '',
        tossDecision: 'bat',
      );
      // Previously, tossWinnerId == teamAId was false (''), falling through to teamBId!
      expect(preTossMatch.battingFirstId, 'team_alpha');
      expect(preTossMatch.battingSecondId, 'team_beta');

      preTossMatch.tossWinnerId = 'team_beta';
      preTossMatch.tossDecision = 'bat';
      expect(preTossMatch.battingFirstId, 'team_beta');
      expect(preTossMatch.battingSecondId, 'team_alpha');

      preTossMatch.tossWinnerId = 'team_beta';
      preTossMatch.tossDecision = 'bowl';
      expect(preTossMatch.battingFirstId, 'team_alpha');
      expect(preTossMatch.battingSecondId, 'team_beta');
    });

    test('playoffMatchesOf orders qualifier1, eliminator, semifinal1, semifinal2, final correctly', () {
      final matches = [
        Match(id: 'm_final', tournamentId: 't1', teamAId: 'a', teamBId: 'b', xiA: const [], xiB: const [], tossWinnerId: '', stage: 'final'),
        Match(id: 'm_elim', tournamentId: 't1', teamAId: 'a', teamBId: 'b', xiA: const [], xiB: const [], tossWinnerId: '', stage: 'eliminator'),
        Match(id: 'm_q1', tournamentId: 't1', teamAId: 'a', teamBId: 'b', xiA: const [], xiB: const [], tossWinnerId: '', stage: 'qualifier1'),
        Match(id: 'm_sf1', tournamentId: 't1', teamAId: 'a', teamBId: 'b', xiA: const [], xiB: const [], tossWinnerId: '', stage: 'semifinal1'),
        Match(id: 'm_league', tournamentId: 't1', teamAId: 'a', teamBId: 'b', xiA: const [], xiB: const [], tossWinnerId: '', stage: 'league'),
      ];

      final ordered = playoffMatchesOf('t1', matches);
      expect(ordered.map((m) => m.stage).toList(), [
        'qualifier1',
        'eliminator',
        'semifinal1',
        'final',
      ]);
    });

    test('UndoStep preserves and restores endedEarly status on undo', () {
      final inn = InningsState(
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        battingXI: const ['b1', 'b2'],
        bowlingXI: const ['w1'],
        oversLimit: 5,
      );
      setOpeners(inn, 'b1', 'b2', 'w1');

      // Record 1 ball
      applyBall(inn, BallInput(batRuns: 1));
      expect(inn.endedEarly, isFalse);
      expect(inn.isComplete, isFalse);

      // End innings early
      inn.endedEarly = true;
      expect(inn.isComplete, isTrue);

      // Applying an undo step should restore endedEarly back to false
      final ok = undoLastBall(inn);
      expect(ok, isTrue);
      expect(inn.endedEarly, isFalse);
      expect(inn.isComplete, isFalse);
    });
  });
}
