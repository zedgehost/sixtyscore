import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/models/remote_match_summary.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/home/home_screen.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Homepage Live & Recent Matches Server Feed', () {
    test('RemoteMatchSummary parses innings_summary cleanly', () {
      final rm = RemoteMatchSummary.fromJson({
        'id': 'm_srv_1',
        'team_a_id': 't_a',
        'team_b_id': 't_b',
        'team_a_name': 'Karachi Kings',
        'team_b_name': 'Lahore Qalandars',
        'overs_limit': 8,
        'balls_per_over': 6,
        'status': 'live',
        'creator_name': 'Aliyan',
        'innings_summary': [
          {
            'batting_team_id': 't_a',
            'total_runs': 96,
            'wickets': 3,
            'legal_balls': 38,
            'overs_text': '6.2',
            'crr': 15.16,
            'target': 0,
          }
        ],
      });

      expect(rm.id, 'm_srv_1');
      expect(rm.isLive, isTrue);
      expect(rm.innings.length, 1);
      expect(rm.innings.first.totalRuns, 96);
      expect(rm.innings.first.oversText, '6.2');
    });

    testWidgets(
        'HomeScreen fetches server feed, renders real scores, and hides fake sample cards',
        (tester) async {
      final mockHttp = MockClient((req) async {
        if (req.url.path.endsWith('/matches/feed')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'live_count': 1,
                'live': [
                  {
                    'id': 'm_srv_live_1',
                    'team_a_id': 't_lah',
                    'team_b_id': 't_isl',
                    'team_a_name': 'Lahore Strikers',
                    'team_b_name': 'Islamabad Hawks',
                    'overs_limit': 8,
                    'balls_per_over': 6,
                    'status': 'live',
                    'creator_name': 'Aliyan',
                    'innings_summary': [
                      {
                        'batting_team_id': 't_lah',
                        'total_runs': 74,
                        'wickets': 2,
                        'legal_balls': 30,
                        'overs_text': '5.0',
                        'crr': 14.8,
                        'target': 0,
                      }
                    ],
                  }
                ],
                'recent': [
                  {
                    'id': 'm_srv_done_1',
                    'team_a_id': 't_psh',
                    'team_b_id': 't_qta',
                    'team_a_name': 'Peshawar Panthers',
                    'team_b_name': 'Quetta Eagles',
                    'overs_limit': 8,
                    'balls_per_over': 6,
                    'status': 'completed',
                    'result_text': 'Peshawar Panthers won by 12 runs',
                    'innings_summary': [],
                  }
                ],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status":"error"}', 404);
      });

      final client = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      final store = Store();
      await store.load();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            onOpenDrawer: () {},
            onSelectTab: (_) {},
            apiClient: client,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LIVE (1)'), findsOneWidget);
      expect(find.text('Lahore Strikers'), findsOneWidget);
      expect(find.text('Islamabad Hawks'), findsOneWidget);
      expect(find.text('74/2 (5.0)'), findsOneWidget);
      expect(find.text('Peshawar Panthers'), findsOneWidget);

      // Ensure fake hardcoded sample teams are completely gone
      expect(find.text('Middlesex Lions'), findsNothing);
      expect(find.text('Falcon CC won by 4 wkts'), findsNothing);
    });

    testWidgets('HomeScreen shows clean empty state when offline with 0 matches',
        (tester) async {
      final mockHttp = MockClient((req) async {
        throw Exception('No internet');
      });

      final client = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      final store = Store();
      await store.load();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            onOpenDrawer: () {},
            onSelectTab: (_) {},
            apiClient: client,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LIVE (0)'), findsOneWidget);
      expect(find.text('No Live or Recent Matches'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets(
        'Tapping remote server match fetches detail and opens ScorecardScreen',
        (tester) async {
      final mockHttp = MockClient((req) async {
        if (req.url.path.endsWith('/matches/feed')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'live_count': 1,
                'live': [
                  {
                    'id': 'm_remote_tap',
                    'team_a_id': 't_a1',
                    'team_b_id': 't_b1',
                    'team_a_name': 'Multan Sultans',
                    'team_b_name': 'Karachi Kings',
                    'overs_limit': 8,
                    'balls_per_over': 6,
                    'status': 'live',
                    'creator_name': 'ScorerX',
                    'innings_summary': [
                      {
                        'batting_team_id': 't_a1',
                        'total_runs': 45,
                        'wickets': 1,
                        'legal_balls': 18,
                        'overs_text': '3.0',
                        'crr': 15.0,
                        'target': 0,
                      }
                    ],
                  }
                ],
                'recent': [],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/matches/m_remote_tap')) {
          final m = Match(
            id: 'm_remote_tap',
            teamAId: 't_a1',
            teamBId: 't_b1',
            xiA: ['p_rizwan'],
            xiB: ['p_amir'],
            oversLimit: 8,
            tossWinnerId: 't_a1',
            status: 'live',
            creatorId: 'other_scorer',
            creatorName: 'ScorerX',
          );
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'id': 'm_remote_tap',
                'payload': m.toJson(),
                'teams': [
                  {
                    'id': 't_a1',
                    'name': 'Multan Sultans',
                    'players': [
                      {'id': 'p_rizwan', 'name': 'M. Rizwan'}
                    ]
                  },
                  {
                    'id': 't_b1',
                    'name': 'Karachi Kings',
                    'players': [
                      {'id': 'p_amir', 'name': 'M. Amir'}
                    ]
                  },
                ],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status":"error"}', 404);
      });

      final client = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      final store = Store();
      await store.load();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            store: store,
            onOpenDrawer: () {},
            onSelectTab: (_) {},
            apiClient: client,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Multan Sultans'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScorecardScreen), findsOneWidget);
      expect(find.textContaining('Multan Sultans'), findsWidgets);
    });
  });
}
