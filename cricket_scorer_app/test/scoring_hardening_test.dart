import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';

void main() {
  InningsState freshInnings() {
    final inn = InningsState(
      battingTeamId: 'teamA',
      bowlingTeamId: 'teamB',
      battingXI: ['p1', 'p2', 'p3'],
      bowlingXI: ['b1', 'b2'],
      oversLimit: 2,
      ballsPerOver: 6,
    );
    setOpeners(inn, 'p1', 'p2', 'b1');
    return inn;
  }

  group('Scoring Engine Hardening — No-Ball Extras & Free Hit', () {
    test('no-ball with extraRuns (e.g. overthrows/byes) adds to team runs without unfair bowler penalty', () {
      final inn = freshInnings();
      // No-ball with 1 off the bat and 2 extra runs (total = 1 penalty + 1 bat + 2 extra = 4 runs)
      final applied = applyBall(
        inn,
        BallInput(
          extraType: 'noBall',
          batRuns: 1,
          extraRuns: 2,
        ),
      );
      expect(applied, isTrue);
      expect(inn.totalRuns, equals(4)); // 1 penalty + 1 bat + 2 extras
      expect(inn.noBallRuns, equals(1)); // 1 penalty
      expect(inn.batting['p1']!.runs, equals(1));
      expect(inn.bowling['b1']!.runs, equals(2)); // 1 penalty + 1 bat
      expect(inn.bowling['b1']!.noBalls, equals(1));
      expect(inn.legalBalls, equals(0)); // illegal delivery
      expect(inn.isFreeHit, isTrue); // No-ball triggers Free Hit!
    });

    test('free hit carries over if subsequent delivery is a wide or no-ball', () {
      final inn = freshInnings();
      // Ball 1: No-ball
      applyBall(inn, BallInput(extraType: 'noBall', batRuns: 0));
      expect(inn.isFreeHit, isTrue);

      // Ball 2: Wide
      applyBall(inn, BallInput(extraType: 'wide', extraRuns: 0));
      expect(inn.isFreeHit, isTrue); // Still Free Hit!

      // Ball 3: Another No-ball
      applyBall(inn, BallInput(extraType: 'noBall', batRuns: 2));
      expect(inn.isFreeHit, isTrue); // Still Free Hit!

      // Ball 4: Legal ball (dot)
      applyBall(inn, BallInput(batRuns: 0));
      expect(inn.isFreeHit, isFalse); // Consumed on legal ball!
    });

    test('free hit blocks illegal dismissals (Bowled, Caught, LBW, Stumped, Hit Wicket)', () {
      final inn = freshInnings();
      // Trigger Free Hit
      applyBall(inn, BallInput(extraType: 'noBall'));
      expect(inn.isFreeHit, isTrue);

      // Attempt Bowled dismissal on Free Hit
      final bowledResult = applyBall(
        inn,
        BallInput(
          isWicket: true,
          wicketType: 'bowled',
          outPlayerId: 'p1',
        ),
      );
      expect(bowledResult, isFalse); // Blocked!
      expect(inn.wickets, equals(0));
      expect(inn.isFreeHit, isTrue); // Still Free Hit!

      // Attempt Caught dismissal on Free Hit
      final caughtResult = applyBall(
        inn,
        BallInput(
          isWicket: true,
          wicketType: 'caught',
          outPlayerId: 'p1',
          fielderId: 'b2',
        ),
      );
      expect(caughtResult, isFalse); // Blocked!
      expect(inn.wickets, equals(0));
      expect(inn.isFreeHit, isTrue);
    });

    test('free hit permits legal dismissals (Run Out) and consumes Free Hit', () {
      final inn = freshInnings();
      // Trigger Free Hit
      applyBall(inn, BallInput(extraType: 'noBall'));
      expect(inn.isFreeHit, isTrue);

      // Run Out is allowed on Free Hit!
      final runOutResult = applyBall(
        inn,
        BallInput(
          batRuns: 1,
          isWicket: true,
          wicketType: 'runOut',
          outPlayerId: 'p1',
        ),
      );
      expect(runOutResult, isTrue);
      expect(inn.wickets, equals(1));
      expect(inn.batting['p1']!.out, isTrue);
      expect(inn.isFreeHit, isFalse); // Consumed on legal ball
    });

    test('undo restores previous Free Hit status accurately', () {
      final inn = freshInnings();
      expect(inn.isFreeHit, isFalse);

      // Ball 1: No ball -> sets Free Hit
      applyBall(inn, BallInput(extraType: 'noBall'));
      expect(inn.isFreeHit, isTrue);

      // Ball 2: Legal single -> consumes Free Hit
      applyBall(inn, BallInput(batRuns: 1));
      expect(inn.isFreeHit, isFalse);

      // Undo Ball 2 -> should restore Free Hit to true!
      final undid2 = undoLastBall(inn);
      expect(undid2, isTrue);
      expect(inn.isFreeHit, isTrue);

      // Undo Ball 1 -> should restore Free Hit to false!
      final undid1 = undoLastBall(inn);
      expect(undid1, isTrue);
      expect(inn.isFreeHit, isFalse);
    });
  });

  group('Career Stats Quick Match Fallback', () {
    test('computes player appearances even when xiA and xiB are empty (Quick Match)', () {
      final inn1 = InningsState(
        battingTeamId: 'teamA',
        bowlingTeamId: 'teamB',
        battingXI: [], // empty XI
        bowlingXI: [],
        oversLimit: 5,
      );
      setOpeners(inn1, 'streetPlayer1', 'streetPlayer2', 'streetBowler1');
      applyBall(inn1, BallInput(batRuns: 4));

      final match = Match(
        id: 'qm1',
        teamAId: 'teamA',
        teamBId: 'teamB',
        xiA: [], // empty quick match squads
        xiB: [],
        tossWinnerId: 'teamA',
        status: 'completed',
        innings: [inn1],
      );

      final stats = computeCareerStats([match]);
      expect(stats['streetPlayer1'], isNotNull);
      expect(stats['streetPlayer1']!.matches, equals(1));
      expect(stats['streetPlayer1']!.runs, equals(4));

      expect(stats['streetPlayer2'], isNotNull);
      expect(stats['streetPlayer2']!.matches, equals(1));

      expect(stats['streetBowler1'], isNotNull);
      expect(stats['streetBowler1']!.matches, equals(1));
    });
  });
}
