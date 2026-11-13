import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/account_profile.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Player Verification & Unique ID Tests', () {
    test('Manual player creation defaults to unverified with deterministic unique code', () {
      final p1 = Player(id: 'p_101', name: 'Aliyan');
      expect(p1.isVerified, isFalse);
      expect(p1.email, isNull);
      expect(p1.code, startsWith('60S-'));
      expect(p1.code.length, 10); // "60S-" + 6 chars
      expect(p1.code, userCodeForUid('p_101'));

      final p2 = Player(id: 'p_102', name: 'Babar', isVerified: true, email: 'babar@example.com');
      expect(p2.isVerified, isTrue);
      expect(p2.email, 'babar@example.com');
      expect(p2.code, startsWith('60S-'));
      expect(p2.code, isNot(p1.code));
    });

    test('Player JSON round-trip retains verification status and deterministic code', () {
      final player = Player(
        id: 'p_200',
        name: 'Rizwan',
        role: 'Wicket-Keeper',
        battingStyle: 'Right-hand',
        isVerified: true,
        email: 'rizwan@pcb.com',
        city: 'Peshawar',
      );

      final json = player.toJson();
      expect(json['isVerified'], isTrue);
      expect(json['email'], 'rizwan@pcb.com');
      expect(json['city'], 'Peshawar');
      expect(json['userCode'], userCodeForUid('p_200'));

      final restored = Player.fromJson(json);
      expect(restored.id, 'p_200');
      expect(restored.name, 'Rizwan');
      expect(restored.isVerified, isTrue);
      expect(restored.email, 'rizwan@pcb.com');
      expect(restored.city, 'Peshawar');
      expect(restored.code, userCodeForUid('p_200'));
    });

    test('Legacy JSON without isVerified defaults safely to unverified', () {
      final legacyJson = {
        'id': 'legacy_99',
        'name': 'Old Player',
        'jerseyNo': 10,
        'role': 'Bowler',
      };

      final restored = Player.fromJson(legacyJson);
      expect(restored.isVerified, isFalse);
      expect(restored.email, isNull);
      expect(restored.code, userCodeForUid('legacy_99'));
    });

    test('AccountProfile reflects verified vs unverified state', () {
      final verifiedProfile = AccountProfile.create(
        uid: 'user_ver_1',
        displayName: 'Verified Captain',
        contact: 'captain@60score.com',
      );
      expect(verifiedProfile.isVerified, isTrue);
      expect(verifiedProfile.isUnverified, isFalse);
      expect(verifiedProfile.verificationStatusLabel, 'Verified Player');

      final unverifiedProfile = AccountProfile.create(
        uid: 'user_loc_2',
        displayName: 'Local Scorer',
        contact: '',
      );
      expect(unverifiedProfile.isVerified, isFalse);
      expect(unverifiedProfile.isUnverified, isTrue);
      expect(unverifiedProfile.verificationStatusLabel, 'Unverified • Local Profile');
    });
  });

  group('Independent Career Telemetry for Manual Players', () {
    test('Two distinct manual players in same match have isolated independent stats', () async {
      final store = Store();
      await store.load();

      final p1 = Player(id: 'man_aliyan', name: 'Aliyan');
      final p2 = Player(id: 'man_babar', name: 'Babar');

      final teamA = Team(id: 'team_alpha', name: 'Alpha XI', players: [p1]);
      final teamB = Team(id: 'team_beta', name: 'Beta XI', players: [p2]);
      await store.upsertTeam(teamA);
      await store.upsertTeam(teamB);

      // Create a completed match
      final match = Match(
        id: 'match_indep_1',
        matchTitle: 'Alpha vs Beta',
        teamAId: teamA.id,
        teamBId: teamB.id,
        oversLimit: 5,
        status: 'completed',
        tossWinnerId: teamA.id,
        xiA: [p1.id],
        xiB: [p2.id],
      );

      // Innings 1: Team A bats. p1 scores 42 runs in 20 balls. p2 bowls and takes 2 wickets.
      final inn1 = InningsState(
        battingTeamId: teamA.id,
        bowlingTeamId: teamB.id,
        oversLimit: 5,
        battingXI: [p1.id],
        bowlingXI: [p2.id],
      );
      inn1.batting[p1.id] = BatFig()
        ..batted = true
        ..runs = 42
        ..balls = 20
        ..fours = 4
        ..sixes = 2
        ..out = true;
      inn1.bowling[p2.id] = BowlFig()
        ..legalBalls = 12
        ..runs = 18
        ..wickets = 2;
      match.innings.add(inn1);

      // Innings 2: Team B bats. p2 scores 15 runs in 10 balls. p1 bowls and takes 1 wicket.
      final inn2 = InningsState(
        battingTeamId: teamB.id,
        bowlingTeamId: teamA.id,
        oversLimit: 5,
        battingXI: [p2.id],
        bowlingXI: [p1.id],
      );
      inn2.batting[p2.id] = BatFig()
        ..batted = true
        ..runs = 15
        ..balls = 10
        ..fours = 1
        ..sixes = 0
        ..out = true;
      inn2.bowling[p1.id] = BowlFig()
        ..legalBalls = 6
        ..runs = 8
        ..wickets = 1;
      match.innings.add(inn2);

      await store.upsertMatch(match);

      // Verify Player 1 independent stats
      final statsP1 = store.computeStatsForPlayer(p1.id, playerName: p1.name);
      expect(statsP1.matches, 1);
      expect(statsP1.runs, 42);
      expect(statsP1.ballsFaced, 20);
      expect(statsP1.fours, 4);
      expect(statsP1.sixes, 2);
      expect(statsP1.highScore, 42);
      expect(statsP1.wickets, 1);
      expect(statsP1.runsConceded, 8);

      // Verify Player 2 independent stats
      final statsP2 = store.computeStatsForPlayer(p2.id, playerName: p2.name);
      expect(statsP2.matches, 1);
      expect(statsP2.runs, 15);
      expect(statsP2.ballsFaced, 10);
      expect(statsP2.fours, 1);
      expect(statsP2.sixes, 0);
      expect(statsP2.highScore, 15);
      expect(statsP2.wickets, 2);
      expect(statsP2.runsConceded, 18);

      // Verify Profiles resolved by Store
      final prof1 = store.getProfileForPlayer(p1.id);
      expect(prof1.displayName, 'Aliyan');
      expect(prof1.isVerified, isFalse);
      expect(prof1.userCode, userCodeForUid(p1.id));

      final prof2 = store.getProfileForPlayer(p2.id);
      expect(prof2.displayName, 'Babar');
      expect(prof2.isVerified, isFalse);
      expect(prof2.userCode, userCodeForUid(p2.id));
      expect(prof2.userCode, isNot(prof1.userCode));
    });
  });
}
