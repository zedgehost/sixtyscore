// Tests for Team unique codes (TM-XXXXXX), Team Detail profile metrics,
// and Homepage global multi-category search (Matches, Teams, Players, Tournaments).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/user_code.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/home/home_screen.dart';
import 'package:cricket_scorer_app/views/screens/teams/teams_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Team Unique Codes (TM-XXXXXX)', () {
    test('teamCodeForId generates stable deterministic 9-char code with TM- prefix', () {
      final code1 = teamCodeForId('team_lahore_qalandars');
      final code2 = teamCodeForId('team_lahore_qalandars');
      final codeOther = teamCodeForId('team_karachi_kings');

      expect(code1, startsWith('TM-'));
      expect(code1.length, 9); // TM- + 6 base36 chars
      expect(code1, equals(code2));
      expect(code1, isNot(equals(codeOther)));
    });

    test('Team.teamCode getter returns deterministic code', () {
      final team = Team(id: 'team_peshawar_zalmi', name: 'Peshawar Zalmi');
      expect(team.teamCode, startsWith('TM-'));
      expect(team.teamCode, equals(teamCodeForId('team_peshawar_zalmi')));
    });
  });

  group('Team Detail Screen (Profile & Telemetry)', () {
    testWidgets('Displays Team Name, TM- Code Badge, and Squad', (tester) async {
      final store = Store();
      await store.load();
      final player1 = Player(id: 'p1', name: 'Shaheen Afridi', role: 'Bowler');
      final player2 = Player(id: 'p2', name: 'Fakhar Zaman', role: 'Batter');
      final team = Team(
        id: 'team_lq_test',
        name: 'Lahore Qalandars',
        players: [player1, player2],
      );
      await store.upsertTeam(team);

      await tester.pumpWidget(
        MaterialApp(
          home: TeamDetailScreen(store: store, team: team),
        ),
      );
      await tester.pump();

      expect(find.text('Lahore Qalandars'), findsWidgets);
      expect(find.textContaining('ID: ${team.teamCode}'), findsOneWidget);
      expect(find.text('Shaheen Afridi'), findsOneWidget);
      expect(find.text('Fakhar Zaman'), findsOneWidget);
      expect(find.text('MATCHES'), findsOneWidget);
      expect(find.text('WON'), findsOneWidget);
      expect(find.text('LOST'), findsOneWidget);
    });
  });

  group('Homepage Global Multi-Category Search', () {
    testWidgets('Typing team name or TM- code finds team in search view', (tester) async {
      final store = Store();
      await store.load();
      final team = Team(
        id: 'team_multan_sultans',
        name: 'Multan Sultans',
        players: [Player(id: 'p_rizwan', name: 'Mohammad Rizwan', role: 'Wicket-Keeper')],
      );
      await store.upsertTeam(team);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            onOpenDrawer: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Enter search query "Multan"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'multan');
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TEAMS section and Multan Sultans card appeared
      expect(find.text('SEARCH RESULTS (1)'), findsOneWidget);
      expect(find.text('TEAMS'), findsOneWidget);
      expect(find.text('Multan Sultans'), findsOneWidget);
      expect(find.text(team.teamCode), findsOneWidget);

      // Search by exact TM- code
      await tester.enterText(searchField, team.teamCode.toLowerCase());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Multan Sultans'), findsOneWidget);

      // Clear search
      await tester.tap(find.text('Clear'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('LIVE & RECENT MATCHES'), findsOneWidget);
    });

    testWidgets('Typing player name finds player in search results', (tester) async {
      final store = Store();
      await store.load();
      final player = Player(id: 'p_shadab', name: 'Shadab Khan', role: 'All-Rounder');
      final team = Team(
        id: 'team_islu',
        name: 'Islamabad United',
        players: [player],
      );
      await store.upsertTeam(team);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            onOpenDrawer: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pump();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'shadab');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PLAYERS'), findsOneWidget);
      expect(find.text('Shadab Khan'), findsOneWidget);
    });
  });
}
