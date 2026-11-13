// 60Score / STUMPS - cPanel 2-Way Offline-First Sync Service
// Pushes & pulls ALL 10 app domain entities to/from cPanel MySQL:
// Profile, Players (photos + computed career stats), Teams & Squads, Matches (ball-by-ball,
// wagon wheel, DLS, Super Over), Tournaments (points & player overrides), Registered Players,
// Drafts, Manual Career Stats, and Deletion Tombstones.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

class CpanelSyncService {
  final Store store;
  final CpanelApiClient apiClient;
  bool _isSyncing = false;
  static Timer? _debounceTimer;

  CpanelSyncService({required this.store, required this.apiClient});

  bool get isSyncing => _isSyncing;

  /// Fire-and-forget background sync with 3-second debounce.
  /// Never blocks the UI thread, never lags scoring, completely safe offline.
  void triggerAutoSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      syncNow();
    });
  }

  Map<String, dynamic> _careerStatsToJson(CareerStats s) => {
        'matches': s.matches,
        'innings_batted': s.inningsBatted,
        'not_outs': s.notOuts,
        'runs': s.runs,
        'balls_faced': s.ballsFaced,
        'high_score': s.highScore,
        'hundreds': s.hundreds,
        'fifties': s.fifties,
        'fours': s.fours,
        'sixes': s.sixes,
        'balls_bowled': s.ballsBowled,
        'runs_conceded': s.runsConceded,
        'wickets': s.wickets,
        'best_wickets': s.bestWickets,
        'best_runs': s.bestRuns == (1 << 30) ? 0 : s.bestRuns,
        'catches': s.catches,
        'stumpings': s.stumpings,
        'run_outs': s.runOuts,
        'average': s.battingAverage,
        'strike_rate': s.battingSR,
        'economy': s.economy,
      };

  /// Push ALL local store entities & metrics to cPanel MySQL.
  Future<bool> syncNow() async {
    if (_isSyncing) return false;

    if (apiClient.token == null || apiClient.token!.isEmpty) {
      debugPrint('[CpanelSyncService] No auth token present. Skipping cloud sync.');
      return false;
    }

    _isSyncing = true;
    try {
      // Flush any offline-completed onboarding profile first
      await AuthService().syncPendingOnboardingIfNeeded(apiClient: apiClient);

      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final computedStats = computeCareerStats(store.matches);

      // 1. Complete Matches (preserves ball-by-ball events, wagon wheel shotX/Y, DLS, Super Over, rules)
      final matchPayloads = <Map<String, dynamic>>[
        for (final m in store.matches)
          {
            ...m.toJson(),
            'teamAName': store.teamById(m.teamAId)?.name ?? 'Team A',
            'teamBName': store.teamById(m.teamBId)?.name ?? 'Team B',
            'updatedAtEpoch': nowEpoch,
          },
      ];

      // 2. Complete Unique Players (including photos, jersey numbers, & career stats JSON)
      final playerPayloads = <Map<String, dynamic>>[];
      final processedPlayerIds = <String>{};
      for (final t in store.teams) {
        for (final p in t.players) {
          if (processedPlayerIds.add(p.id)) {
            final stats = computedStats[p.id];
            playerPayloads.add({
              'id': p.id,
              'userCode': p.code,
              'name': p.name,
              'isVerified': p.isVerified,
              'email': p.email,
              'role': p.role,
              'battingStyle': p.battingStyle,
              'bowlingStyle': p.bowlingStyle,
              'jerseyNo': p.jerseyNo,
              'city': p.city,
              'photoBase64': p.photoBase64,
              if (stats != null) 'careerStats': _careerStatsToJson(stats),
              'updatedAtEpoch': nowEpoch,
            });
          }
        }
      }

      // 3. Complete Teams + Squad Player Arrays
      final teamPayloads = <Map<String, dynamic>>[
        for (final t in store.teams)
          {
            ...t.toJson(),
            'shortName': t.name.length > 3
                ? t.name.substring(0, 3).toUpperCase()
                : t.name.toUpperCase(),
            'color': '#00261B',
            'updatedAtEpoch': nowEpoch,
          },
      ];

      // 4. Complete Tournaments (including overrides, logos, playoff qualification)
      final tournamentPayloads = <Map<String, dynamic>>[
        for (final tr in store.tournaments)
          {
            ...tr.toJson(),
            'updatedAtEpoch': nowEpoch,
          },
      ];

      // 5. Registered Players (Registration & Draft Pool)
      final regPlayerPayloads = <Map<String, dynamic>>[
        for (final rp in store.regPlayers)
          {
            ...rp.toJson(),
            'updatedAtEpoch': nowEpoch,
          },
      ];

      // 6. Drafts & Auction Picks
      final draftPayloads = <Map<String, dynamic>>[
        for (final d in store.drafts)
          {
            ...d.toJson(),
            'updatedAtEpoch': nowEpoch,
          },
      ];

      // 7. Manual Career Stats
      final manualStatPayloads = <Map<String, dynamic>>[
        for (final ms in store.manualStats)
          {
            ...ms.toJson(),
            'updatedAtEpoch': nowEpoch,
          },
      ];

      // 8. Tombstones (Deletions)
      final tombstonePayloads = <Map<String, dynamic>>[
        for (final tb in store.tombstones) tb.toJson(),
      ];

      final res = await apiClient.batchSync(
        profile: store.profile?.toJson(),
        matches: matchPayloads,
        players: playerPayloads,
        teams: teamPayloads,
        tournaments: tournamentPayloads,
        regPlayers: regPlayerPayloads,
        drafts: draftPayloads,
        manualStats: manualStatPayloads,
        tombstones: tombstonePayloads,
      );

      if (res['status'] == 'success') {
        debugPrint('[CpanelSyncService] Full batch sync completed: ${res['data']}');
        return true;
      } else {
        final code = res['statusCode'];
        if (code == 401 || code == 403) {
          await AuthService().handleServerRevocation(res['message']?.toString());
        }
        debugPrint('[CpanelSyncService] Batch sync returned error: ${res['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('[CpanelSyncService] Sync failed (device likely offline): $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull ALL user data from cPanel MySQL and merge safely into local Store.
  Future<Map<String, int>?> pullAndMerge() async {
    if (_isSyncing) return null;

    if (apiClient.token == null || apiClient.token!.isEmpty) {
      debugPrint('[CpanelSyncService] No auth token present. Skipping cloud pull.');
      return null;
    }

    _isSyncing = true;
    try {
      final res = await apiClient.pullSync();
      if (res['status'] != 'success' || res['data'] == null) {
        final code = res['statusCode'];
        if (code == 401 || code == 403) {
          await AuthService().handleServerRevocation(res['message']?.toString());
        }
        return null;
      }

      final payload = Map<String, dynamic>.from(res['data'] as Map<String, dynamic>);
      final counts = await store.importJson(payload, merge: true);
      debugPrint('[CpanelSyncService] Cloud pull & merge completed: $counts');
      return counts;
    } catch (e) {
      debugPrint('[CpanelSyncService] Pull failed (device likely offline): $e');
      return null;
    } finally {
      _isSyncing = false;
    }
  }
}
