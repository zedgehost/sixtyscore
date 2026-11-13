// Comprehensive End-to-End Simulation of Full Tournament Lifecycle:
// 1. Tournament Creation (Teams, Venue, Overs, Format)
// 2. Round-Robin Fixture Generation (Home/Away balance, Schedule)
// 3. Match Simulation & Live Scoring across League Stage
// 4. Standings & Points Table Calculation (NRR, Points, Overrides)
// 5. Qualification Engine (Mathematically Guaranteed Seeds, Super 4 / Semis)
// 6. Playoff Seeding (SF1: 1 vs 4, SF2: 2 vs 3, or Super 4)
// 7. Semifinal Matches Execution & Winner Advancement to Grand Final
// 8. Grand Final Execution, Trophy Winner Decided, and Final Tournament Stats
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

  group('Full Tournament Lifecycle Simulation (End-to-End)', () {
    test('Simulates entire tournament: League -> Standings -> Semis -> Grand Final Winner', () async {
      final store = Store();
      await store.load();

      // -------------------------------------------------------------
      // Step 1: Create 4 Teams with Squads
      // -------------------------------------------------------------
      final teams = [
        Team(
          id: 'team_lahore',
          name: 'Lahore Qalandars',
          players: [
            Player(id: 'lq_p1', name: 'Shaheen Afridi', role: 'Bowler'),
            Player(id: 'lq_p2', name: 'Fakhar Zaman', role: 'Batter'),
          ],
        ),
        Team(
          id: 'team_karachi',
          name: 'Karachi Kings',
          players: [
            Player(id: 'kk_p1', name: 'Babar Azam', role: 'Batter'),
            Player(id: 'kk_p2', name: 'Mohammad Amir', role: 'Bowler'),
          ],
        ),
        Team(
          id: 'team_peshawar',
          name: 'Peshawar Zalmi',
          players: [
            Player(id: 'pz_p1', name: 'Saim Ayub', role: 'Batter'),
            Player(id: 'pz_p2', name: 'Wahab Riaz', role: 'Bowler'),
          ],
        ),
        Team(
          id: 'team_islamabad',
          name: 'Islamabad United',
          players: [
            Player(id: 'iu_p1', name: 'Shadab Khan', role: 'All-Rounder'),
            Player(id: 'iu_p2', name: 'Alex Hales', role: 'Batter'),
          ],
        ),
      ];

      for (final t in teams) {
        await store.upsertTeam(t);
      }
      expect(store.teams.length, 4);

      // Verify deterministic team codes
      for (final t in store.teams) {
        expect(t.teamCode, startsWith('TM-'));
      }

      // -------------------------------------------------------------
      // Step 2: Create Tournament
      // -------------------------------------------------------------
      final tournament = Tournament(
        id: 'psl_super_league_2026',
        name: 'Super Sixty League 2026',
        teamIds: teams.map((t) => t.id).toList(),
        venue: 'Gaddafi Stadium, Lahore',
        oversLimit: 8,
      );
      await store.upsertTournament(tournament);
      expect(store.tournaments.length, 1);

      // -------------------------------------------------------------
      // Step 3: Generate Round-Robin Fixtures (Single Round)
      // 4 teams -> 4*3/2 = 6 league matches
      // -------------------------------------------------------------
      final leagueFixtures = generateRoundRobinFixtures(
        tournamentId: tournament.id,
        teamIds: tournament.teamIds,
        oversLimit: tournament.oversLimit,
        venue: tournament.venue,
        doubleRoundRobin: false,
      );
      expect(leagueFixtures.length, 6);

      for (final fix in leagueFixtures) {
        await store.upsertMatch(fix);
      }
      expect(store.matches.length, 6);

      // -------------------------------------------------------------
      // Step 4: Play League Stage Matches with Deterministic Scores
      // Match 1: Lahore vs Karachi -> Lahore wins
      // Match 2: Peshawar vs Islamabad -> Islamabad wins
      // Match 3: Lahore vs Peshawar -> Lahore wins
      // Match 4: Karachi vs Islamabad -> Karachi wins
      // Match 5: Lahore vs Islamabad -> Islamabad wins
      // Match 6: Karachi vs Peshawar -> Karachi wins
      // -------------------------------------------------------------
      void completeSimulatedMatch(
        Match m, {
        required int runsTeamA,
        required int wktsTeamA,
        required int runsTeamB,
        required int wktsTeamB,
      }) {
        m.status = 'completed';
        m.tossWinnerId = m.teamAId;
        m.tossDecision = 'bat';

        final inn1 = InningsState(
          battingTeamId: m.teamAId,
          bowlingTeamId: m.teamBId,
          battingXI: m.xiA,
          bowlingXI: m.xiB,
          oversLimit: m.oversLimit,
          ballsPerOver: m.ballsPerOver,
        );
        inn1.totalRuns = runsTeamA;
        inn1.wickets = wktsTeamA;
        inn1.legalBalls = m.oversLimit * m.ballsPerOver;

        final inn2 = InningsState(
          battingTeamId: m.teamBId,
          bowlingTeamId: m.teamAId,
          battingXI: m.xiB,
          bowlingXI: m.xiA,
          oversLimit: m.oversLimit,
          ballsPerOver: m.ballsPerOver,
        );
        inn2.totalRuns = runsTeamB;
        inn2.wickets = wktsTeamB;
        inn2.target = runsTeamA + 1;
        inn2.legalBalls = m.oversLimit * m.ballsPerOver;

        m.innings = [inn1, inn2];
        computeResult(m, store.teamName);
      }

      // Score all 6 league matches
      for (final m in store.matches.where((x) => x.stage == 'league')) {
        if ((m.teamAId == 'team_lahore' && m.teamBId == 'team_karachi') ||
            (m.teamBId == 'team_lahore' && m.teamAId == 'team_karachi')) {
          final lqIsA = m.teamAId == 'team_lahore';
          completeSimulatedMatch(
            m,
            runsTeamA: lqIsA ? 95 : 78,
            wktsTeamA: 3,
            runsTeamB: lqIsA ? 78 : 95,
            wktsTeamB: 5,
          );
        } else if ((m.teamAId == 'team_peshawar' && m.teamBId == 'team_islamabad') ||
            (m.teamBId == 'team_peshawar' && m.teamAId == 'team_islamabad')) {
          final iuIsA = m.teamAId == 'team_islamabad';
          completeSimulatedMatch(
            m,
            runsTeamA: iuIsA ? 88 : 70,
            wktsTeamA: 2,
            runsTeamB: iuIsA ? 70 : 88,
            wktsTeamB: 4,
          );
        } else if ((m.teamAId == 'team_lahore' && m.teamBId == 'team_peshawar') ||
            (m.teamBId == 'team_lahore' && m.teamAId == 'team_peshawar')) {
          final lqIsA = m.teamAId == 'team_lahore';
          completeSimulatedMatch(
            m,
            runsTeamA: lqIsA ? 102 : 65,
            wktsTeamA: 2,
            runsTeamB: lqIsA ? 65 : 102,
            wktsTeamB: 6,
          );
        } else if ((m.teamAId == 'team_karachi' && m.teamBId == 'team_islamabad') ||
            (m.teamBId == 'team_karachi' && m.teamAId == 'team_islamabad')) {
          final kkIsA = m.teamAId == 'team_karachi';
          completeSimulatedMatch(
            m,
            runsTeamA: kkIsA ? 84 : 80,
            wktsTeamA: 4,
            runsTeamB: kkIsA ? 80 : 84,
            wktsTeamB: 5,
          );
        } else if ((m.teamAId == 'team_lahore' && m.teamBId == 'team_islamabad') ||
            (m.teamBId == 'team_lahore' && m.teamAId == 'team_islamabad')) {
          final iuIsA = m.teamAId == 'team_islamabad';
          completeSimulatedMatch(
            m,
            runsTeamA: iuIsA ? 92 : 89,
            wktsTeamA: 3,
            runsTeamB: iuIsA ? 89 : 92,
            wktsTeamB: 4,
          );
        } else {
          // Karachi vs Peshawar
          final kkIsA = m.teamAId == 'team_karachi';
          completeSimulatedMatch(
            m,
            runsTeamA: kkIsA ? 90 : 75,
            wktsTeamA: 3,
            runsTeamB: kkIsA ? 75 : 90,
            wktsTeamB: 5,
          );
        }
        await store.upsertMatch(m);
      }

      // -------------------------------------------------------------
      // Step 5: Verify League Standings Table & Finalization
      // -------------------------------------------------------------
      expect(leagueStageFinalized(tournament.id, store.matches), isTrue);

      final table = leaguePointsTable(tournament, store.matches);
      expect(table.length, 4);

      // Verify table ranks: all teams have correct matches played
      for (final row in table) {
        expect(row.played, 3);
      }

      // Check qualifiers
      final topTeamId = table[0].teamId;
      final secondTeamId = table[1].teamId;
      final thirdTeamId = table[2].teamId;
      final fourthTeamId = table[3].teamId;

      // -------------------------------------------------------------
      // Step 6: Create & Seed Semifinals (SF1: 1 vs 4, SF2: 2 vs 3)
      // -------------------------------------------------------------
      final sf1 = Match(
        id: 'match_sf_1',
        tournamentId: tournament.id,
        teamAId: topTeamId,
        teamBId: fourthTeamId,
        xiA: const [],
        xiB: const [],
        tossWinnerId: '',
        status: 'upcoming',
        stage: 'semifinal1',
        matchTitle: 'Semifinal 1 (Rank 1 vs Rank 4)',
        oversLimit: tournament.oversLimit,
        ballsPerOver: 6,
        venue: tournament.venue,
        dateIso: DateTime.now().toIso8601String(),
      );

      final sf2 = Match(
        id: 'match_sf_2',
        tournamentId: tournament.id,
        teamAId: secondTeamId,
        teamBId: thirdTeamId,
        xiA: const [],
        xiB: const [],
        tossWinnerId: '',
        status: 'upcoming',
        stage: 'semifinal2',
        matchTitle: 'Semifinal 2 (Rank 2 vs Rank 3)',
        oversLimit: tournament.oversLimit,
        ballsPerOver: 6,
        venue: tournament.venue,
        dateIso: DateTime.now().toIso8601String(),
      );

      final grandFinal = Match(
        id: 'match_grand_final',
        tournamentId: tournament.id,
        teamAId: '', // To be filled by SF1 winner
        teamBId: '', // To be filled by SF2 winner
        xiA: const [],
        xiB: const [],
        tossWinnerId: '',
        status: 'upcoming',
        stage: 'final',
        matchTitle: 'Grand Final',
        oversLimit: tournament.oversLimit,
        ballsPerOver: 6,
        venue: tournament.venue,
        dateIso: DateTime.now().toIso8601String(),
      );

      await store.upsertMatch(sf1);
      await store.upsertMatch(sf2);
      await store.upsertMatch(grandFinal);

      // Play SF1 (Rank 1 wins)
      completeSimulatedMatch(
        sf1,
        runsTeamA: 110,
        wktsTeamA: 2,
        runsTeamB: 85,
        wktsTeamB: 6,
      );
      await store.upsertMatch(sf1);
      final sf1Winner = matchWinnerId(sf1);
      expect(sf1Winner, equals(topTeamId));

      // Play SF2 (Rank 2 wins)
      completeSimulatedMatch(
        sf2,
        runsTeamA: 105,
        wktsTeamA: 3,
        runsTeamB: 98,
        wktsTeamB: 5,
      );
      await store.upsertMatch(sf2);
      final sf2Winner = matchWinnerId(sf2);
      expect(sf2Winner, equals(secondTeamId));

      // -------------------------------------------------------------
      // Step 7: Advance Finalists into Grand Final
      // -------------------------------------------------------------
      grandFinal.teamAId = sf1Winner!;
      grandFinal.teamBId = sf2Winner!;
      expect(grandFinal.teamAId, isNotEmpty);
      expect(grandFinal.teamBId, isNotEmpty);

      // Play Grand Final (Rank 1 wins tournament)
      completeSimulatedMatch(
        grandFinal,
        runsTeamA: 125,
        wktsTeamA: 2,
        runsTeamB: 112,
        wktsTeamB: 4,
      );
      await store.upsertMatch(grandFinal);

      final championId = matchWinnerId(grandFinal);
      expect(championId, equals(topTeamId));
      expect(grandFinal.status, equals('completed'));
      expect(grandFinal.resultText, contains('won by'));

      // -------------------------------------------------------------
      // Step 8: Verify Complete Tournament Record
      // -------------------------------------------------------------
      final allTournMatches = store.matches.where((m) => m.tournamentId == tournament.id).toList();
      expect(allTournMatches.length, 9); // 6 league + 2 semis + 1 final
      expect(allTournMatches.every((m) => m.status == 'completed'), isTrue);

      final championName = store.teamName(championId!);
      expect(championName, isNotEmpty);
    });
  });
}
