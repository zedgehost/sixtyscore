import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('cPanel REST API Client & Offline-First Sync Tests', () {
    test('Client manages base URL and token properly', () async {
      final client = CpanelApiClient(baseUrl: 'https://test.60score.com/api');
      await client.init();

      expect(client.baseUrl, 'https://test.60score.com/api');
      expect(client.token, isNull);

      await client.setToken('test_token_12345');
      expect(client.token, 'test_token_12345');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cpanel_api_token'), 'test_token_12345');
    });

    test('Batch sync sends correct offline-scored matches and players', () async {
      bool requestReceived = false;
      Map<String, dynamic> receivedBody = {};

      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/sync/batch')) {
          requestReceived = true;
          receivedBody = jsonDecode(request.body);
          expect(request.headers['Authorization'], 'Bearer mock_secret_token');
          return http.Response(
            jsonEncode({
              'status': 'success',
              'message': 'Offline batch sync processed successfully',
              'data': {
                'synced_matches': ['m_offline_1'],
                'synced_players': ['p_offline_aliyan'],
                'server_time': 1762860000000
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status":"error","message":"Not found"}', 404);
      });

      final apiClient = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.60score.com/api',
      );
      await apiClient.setToken('mock_secret_token');

      final store = Store();
      await store.load();

      // Create local offline team & player
      final player = Player(id: 'p_offline_aliyan', name: 'Aliyan Scorer');
      final team = Team(id: 't_offline_1', name: 'Panthers', players: [player]);
      await store.upsertTeam(team);

      // Create local offline match
      final match = Match(
        id: 'm_offline_1',
        teamAId: team.id,
        teamBId: 't_2',
        xiA: [player.id],
        xiB: [],
        tossWinnerId: team.id,
        oversLimit: 10,
        status: 'completed',
        creatorId: 'user_local_1',
        creatorCode: '60S-XXXXXX',
      );
      await store.upsertMatch(match);

      final syncService = CpanelSyncService(store: store, apiClient: apiClient);
      final success = await syncService.syncNow();

      expect(success, isTrue);
      expect(requestReceived, isTrue);
      expect(receivedBody['matches'], isNotEmpty);
      expect(receivedBody['matches'][0]['id'], 'm_offline_1');
      expect(receivedBody['players'], isNotEmpty);
      expect(receivedBody['players'][0]['id'], 'p_offline_aliyan');
    });

    test('Sync handles offline failure gracefully without crashing', () async {
      final mockHttp = MockClient((request) async {
        throw Exception('Connection refused - no internet on ground');
      });

      final apiClient = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.60score.com/api',
      );
      await apiClient.setToken('mock_secret_token');

      final store = Store();
      await store.load();

      final syncService = CpanelSyncService(store: store, apiClient: apiClient);
      // Must not throw exception
      final result = await syncService.syncNow();
      expect(result, isFalse);
    });

    test('Full 2-way sync pushes tournaments, drafts, regPlayers, manualStats and pulls back cleanly',
        () async {
      Map<String, dynamic> pushedBody = {};

      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/sync/batch')) {
          pushedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'status': 'success', 'data': {'server_time': 123}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/sync/pull')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'app': '60Score',
                'schema': 2,
                'teams': pushedBody['teams'],
                'tournaments': pushedBody['tournaments'],
                'matches': pushedBody['matches'],
                'regPlayers': pushedBody['regPlayers'],
                'drafts': pushedBody['drafts'],
                'manualStats': pushedBody['manualStats'],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status":"error"}', 404);
      });

      final apiClient = CpanelApiClient(
        client: mockHttp,
        baseUrl: 'https://api.careerinpak.com/api',
      );
      await apiClient.setToken('tok_full_sync');

      final store = Store();
      await store.load();
      await store.upsertTeam(Team(
        id: 't_full_1',
        name: 'Lahore Lions',
        players: [Player(id: 'p_1', name: 'Babar', jerseyNo: 56)],
      ));
      await store.upsertTournament(Tournament(
        id: 'tr_1',
        name: 'Super Sixty Cup',
        teamIds: ['t_full_1'],
        oversLimit: 8,
        published: true,
      ));
      await store.upsertRegPlayer(RegPlayer(
        id: 'rp_1',
        name: 'Shaheen',
        role: 'Bowler',
        category: 'Platinum',
      ));
      await store.upsertDraft(Draft(
        id: 'd_1',
        name: 'Season 2 Draft',
        teamIds: ['t_full_1'],
        tournamentId: 'tr_1',
      ));
      await store.addManualStat(ManualStatEntry(
        id: 'ms_1',
        playerId: 'p_1',
        playerName: 'Babar',
        runs: 85,
        balls: 42,
      ));

      final pushOk =
          await CpanelSyncService(store: store, apiClient: apiClient).syncNow();
      expect(pushOk, isTrue);
      expect((pushedBody['tournaments'] as List).length, 1);
      expect((pushedBody['regPlayers'] as List).length, 1);
      expect((pushedBody['drafts'] as List).length, 1);
      expect((pushedBody['manualStats'] as List).length, 1);

      // Now pull into a clean empty Store
      SharedPreferences.setMockInitialValues({});
      final freshStore = Store();
      await freshStore.load();
      expect(freshStore.tournaments, isEmpty);

      final counts =
          await CpanelSyncService(store: freshStore, apiClient: apiClient)
              .pullAndMerge();
      expect(counts, isNotNull);
      expect(freshStore.teams.length, 1);
      expect(freshStore.teams.first.players.first.name, 'Babar');
      expect(freshStore.tournaments.length, 1);
      expect(freshStore.regPlayers.length, 1);
      expect(freshStore.drafts.length, 1);
      expect(freshStore.manualStats.length, 1);
      expect(freshStore.manualStats.first.runs, 85);
    });
  });
}
