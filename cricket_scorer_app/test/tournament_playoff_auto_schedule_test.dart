import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void completeSimulatedMatch(
    Match m, {
    required int runsTeamA,
    required int runsTeamB,
    required Store store,
  }) {
    m.status = 'completed';
    m.tossWinnerId = m.teamAId;
    m.tossDecision = 'bat';

    final inn1 = InningsState(
      battingTeamId: m.teamAId,
      bowlingTeamId: m.teamBId,
      battingXI: const [],
      bowlingXI: const [],
      oversLimit: m.oversLimit,
      ballsPerOver: m.ballsPerOver,
    );
    inn1.totalRuns = runsTeamA;
    inn1.wickets = 3;
    inn1.legalBalls = m.oversLimit * m.ballsPerOver;

    final inn2 = InningsState(
      battingTeamId: m.teamBId,
      bowlingTeamId: m.teamAId,
      battingXI: const [],
      bowlingXI: const [],
      oversLimit: m.oversLimit,
      ballsPerOver: m.ballsPerOver,
    );
    inn2.totalRuns = runsTeamB;
    inn2.wickets = 5;
    inn2.target = runsTeamA + 1;
    inn2.legalBalls = m.oversLimit * m.ballsPerOver;

    m.innings = [inn1, inn2];
    computeResult(m, store.teamName);
  }

  group('Tournament Playoff Auto-Scheduling & Progression Tests', () {
    test('Auto-creates SF1 (1v4), SF2 (2v3), and Grand Final when league completes in semis format', () async {
      final store = Store();
      await store.load();

      final teams = [
        Team(id: 't_lahore', name: 'Lahore'),
        Team(id: 't_karachi', name: 'Karachi'),
        Team(id: 't_peshawar', name: 'Peshawar'),
        Team(id: 't_quetta', name: 'Quetta'),
      ];
      for (final t in teams) {
        await store.upsertTeam(t);
      }

      final tournament = Tournament(
        id: 'tourn_semis_test',
        name: 'PSL Semis Test',
        teamIds: teams.map((t) => t.id).toList(),
        format: 'League + Playoffs',
        playoffFormat: 'semis',
        oversLimit: 8,
      );
      await store.upsertTournament(tournament);

      // Generate round-robin fixtures: 4 teams = 6 matches
      final leagueFixtures = generateRoundRobinFixtures(
        tournamentId: tournament.id,
        teamIds: tournament.teamIds,
        oversLimit: tournament.oversLimit,
      );
      for (final f in leagueFixtures) {
        await store.upsertMatch(f);
      }

      // Complete all league matches with deterministic outcomes:
      // Lahore wins all (Rank 1)
      // Karachi wins 2 (Rank 2)
      // Peshawar wins 1 (Rank 3)
      // Quetta wins 0 (Rank 4)
      for (final m in store.matches.where((x) => x.stage == 'league')) {
        if (m.teamAId == 't_lahore' || m.teamBId == 't_lahore') {
          final lIsA = m.teamAId == 't_lahore';
          completeSimulatedMatch(m, runsTeamA: lIsA ? 100 : 70, runsTeamB: lIsA ? 70 : 100, store: store);
        } else if (m.teamAId == 't_karachi' || m.teamBId == 't_karachi') {
          final kIsA = m.teamAId == 't_karachi';
          completeSimulatedMatch(m, runsTeamA: kIsA ? 90 : 80, runsTeamB: kIsA ? 80 : 90, store: store);
        } else {
          // Peshawar vs Quetta -> Peshawar wins
          final pIsA = m.teamAId == 't_peshawar';
          completeSimulatedMatch(m, runsTeamA: pIsA ? 85 : 75, runsTeamB: pIsA ? 75 : 85, store: store);
        }
        await store.upsertMatch(m);
      }

      // No playoffs exist before running update
      expect(playoffMatchesOf(tournament.id, store.matches).isEmpty, isTrue);

      // Run playoff update on finalized league
      final update = await applyPlayoffUpdate(store, tournament.id);
      expect(update.changed, isTrue);

      // Verify that playoffs were AUTO-CREATED
      final playoffs = playoffMatchesOf(tournament.id, store.matches);
      expect(playoffs.length, 3); // SF1, SF2, Grand Final

      final sf1 = playoffs.firstWhere((m) => m.stage == 'semifinal1');
      final sf2 = playoffs.firstWhere((m) => m.stage == 'semifinal2');
      final fin = playoffs.firstWhere((m) => m.stage == 'final');

      // Rank 1 (Lahore) vs Rank 4 (Quetta)
      expect(sf1.teamAId, 't_lahore');
      expect(sf1.teamBId, 't_quetta');

      // Rank 2 (Karachi) vs Rank 3 (Peshawar)
      expect(sf2.teamAId, 't_karachi');
      expect(sf2.teamBId, 't_peshawar');

      // Grand final starts with TBD
      expect(fin.teamAId, '');
      expect(fin.teamBId, '');

      // -------------------------------------------------------------
      // User manual override test: Change SF1 Team B to 't_peshawar'
      // -------------------------------------------------------------
      sf1.teamBId = 't_peshawar';
      await store.upsertMatch(sf1);

      // Re-run applyPlayoffUpdate -> verify manual change is preserved!
      final recheck = await applyPlayoffUpdate(store, tournament.id);
      final refreshedSf1 = store.matchById(sf1.id)!;
      expect(refreshedSf1.teamBId, 't_peshawar'); // Preserved!

      // -------------------------------------------------------------
      // Winner progression test to Grand Final
      // -------------------------------------------------------------
      // SF1: Lahore vs Peshawar -> Lahore wins
      completeSimulatedMatch(sf1, runsTeamA: 110, runsTeamB: 95, store: store);
      await store.upsertMatch(sf1);

      // Run update after SF1
      await applyPlayoffUpdate(store, tournament.id);

      final finAfterSf1 = store.matchById(fin.id)!;
      expect(finAfterSf1.teamAId, 't_lahore'); // Lahore advanced to Grand Final Team A!
      expect(finAfterSf1.teamBId, '');

      // SF2: Karachi vs Peshawar -> Karachi wins
      completeSimulatedMatch(sf2, runsTeamA: 105, runsTeamB: 88, store: store);
      await store.upsertMatch(sf2);

      // Run update after SF2
      await applyPlayoffUpdate(store, tournament.id);

      final finAfterSf2 = store.matchById(fin.id)!;
      expect(finAfterSf2.teamAId, 't_lahore');
      expect(finAfterSf2.teamBId, 't_karachi'); // Karachi advanced to Grand Final Team B!
      expect(finAfterSf2.matchTitle, contains('Lahore vs Karachi'));
    });

    test('Auto-creates IPL Page Playoffs (Q1, Elim, Q2, Final) when page format is selected', () async {
      final store = Store();
      await store.load();

      final teams = [
        Team(id: 't_csk', name: 'CSK'),
        Team(id: 't_mi', name: 'MI'),
        Team(id: 't_rcb', name: 'RCB'),
        Team(id: 't_kkr', name: 'KKR'),
      ];
      for (final t in teams) {
        await store.upsertTeam(t);
      }

      final tournament = Tournament(
        id: 'tourn_page_test',
        name: 'IPL Page Test',
        teamIds: teams.map((t) => t.id).toList(),
        format: 'League + Playoffs',
        playoffFormat: 'page',
      );
      await store.upsertTournament(tournament);

      final leagueFixtures = generateRoundRobinFixtures(
        tournamentId: tournament.id,
        teamIds: tournament.teamIds,
        oversLimit: 8,
      );
      for (final f in leagueFixtures) {
        await store.upsertMatch(f);
      }

      // Complete all league matches: CSK 1st, MI 2nd, RCB 3rd, KKR 4th
      for (final m in store.matches.where((x) => x.stage == 'league')) {
        if (m.teamAId == 't_csk' || m.teamBId == 't_csk') {
          final isA = m.teamAId == 't_csk';
          completeSimulatedMatch(m, runsTeamA: isA ? 100 : 70, runsTeamB: isA ? 70 : 100, store: store);
        } else if (m.teamAId == 't_mi' || m.teamBId == 't_mi') {
          final isA = m.teamAId == 't_mi';
          completeSimulatedMatch(m, runsTeamA: isA ? 90 : 80, runsTeamB: isA ? 80 : 90, store: store);
        } else {
          final isA = m.teamAId == 't_rcb';
          completeSimulatedMatch(m, runsTeamA: isA ? 85 : 75, runsTeamB: isA ? 75 : 85, store: store);
        }
        await store.upsertMatch(m);
      }

      // Run playoff update
      await applyPlayoffUpdate(store, tournament.id);

      final playoffs = playoffMatchesOf(tournament.id, store.matches);
      expect(playoffs.length, 4); // Q1, Eliminator, Q2, Final

      final q1 = playoffs.firstWhere((m) => m.stage == 'qualifier1');
      final elim = playoffs.firstWhere((m) => m.stage == 'eliminator');
      final q2 = playoffs.firstWhere((m) => m.stage == 'qualifier2');
      final fin = playoffs.firstWhere((m) => m.stage == 'final');

      // Q1: 1st (CSK) vs 2nd (MI)
      expect(q1.teamAId, 't_csk');
      expect(q1.teamBId, 't_mi');

      // Eliminator: 3rd (RCB) vs 4th (KKR)
      expect(elim.teamAId, 't_rcb');
      expect(elim.teamBId, 't_kkr');

      // Q2 and Final start empty
      expect(q2.teamAId, '');
      expect(q2.teamBId, '');
      expect(fin.teamAId, '');
      expect(fin.teamBId, '');
    });

    test('Auto-creates Direct Final (1st vs 2nd) when direct_final format is selected', () async {
      final store = Store();
      await store.load();

      final teams = [
        Team(id: 't_1', name: 'Team 1'),
        Team(id: 't_2', name: 'Team 2'),
        Team(id: 't_3', name: 'Team 3'),
      ];
      for (final t in teams) {
        await store.upsertTeam(t);
      }

      final tournament = Tournament(
        id: 'tourn_direct_final_test',
        name: 'Direct Final Test',
        teamIds: teams.map((t) => t.id).toList(),
        format: 'League + Playoffs',
        playoffFormat: 'direct_final',
      );
      await store.upsertTournament(tournament);

      final leagueFixtures = generateRoundRobinFixtures(
        tournamentId: tournament.id,
        teamIds: tournament.teamIds,
        oversLimit: 8,
      );
      for (final f in leagueFixtures) {
        completeSimulatedMatch(f, runsTeamA: 90, runsTeamB: 70, store: store);
        await store.upsertMatch(f);
      }

      await applyPlayoffUpdate(store, tournament.id);

      final playoffs = playoffMatchesOf(tournament.id, store.matches);
      expect(playoffs.length, 1);
      expect(playoffs.first.stage, 'final');
      expect(playoffs.first.teamAId.isNotEmpty, isTrue);
      expect(playoffs.first.teamBId.isNotEmpty, isTrue);
    });

    test('Does NOT create playoffs when playoffFormat is none', () async {
      final store = Store();
      await store.load();

      final teams = [
        Team(id: 't_a', name: 'Team A'),
        Team(id: 't_b', name: 'Team B'),
        Team(id: 't_c', name: 'Team C'),
      ];
      for (final t in teams) {
        await store.upsertTeam(t);
      }

      final tournament = Tournament(
        id: 'tourn_none_test',
        name: 'Round Robin Only',
        teamIds: teams.map((t) => t.id).toList(),
        format: 'Round Robin',
        playoffFormat: 'none',
      );
      await store.upsertTournament(tournament);

      final leagueFixtures = generateRoundRobinFixtures(
        tournamentId: tournament.id,
        teamIds: tournament.teamIds,
        oversLimit: 8,
      );
      for (final f in leagueFixtures) {
        completeSimulatedMatch(f, runsTeamA: 80, runsTeamB: 60, store: store);
        await store.upsertMatch(f);
      }

      await applyPlayoffUpdate(store, tournament.id);

      final playoffs = playoffMatchesOf(tournament.id, store.matches);
      expect(playoffs.isEmpty, isTrue); // No playoffs created
    });
  });
}
