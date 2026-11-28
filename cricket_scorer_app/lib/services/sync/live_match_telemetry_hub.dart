// 60Score / STUMPS - Real-Time Live Match Telemetry Hub
// Centralized background service managing real-time live score distribution,
// offline-to-online auto-reconnection, pending telemetry outbox, and zero-refresh UI hydration.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

class LiveMatchTelemetryHub extends ChangeNotifier {
  static final LiveMatchTelemetryHub instance = LiveMatchTelemetryHub._internal();

  LiveMatchTelemetryHub._internal();

  static const String _kOutboxPrefKey = 'stumps_live_outbox_queue_v1';

  Store? _store;
  final CpanelApiClient _apiClient = CpanelApiClient();

  String? _focusedMatchId;
  String? _activeScoringMatchId;
  final Set<String> _watchedMatchIds = {};

  final Map<String, int> _lastRevisions = {};
  final Map<String, int> _lastEventsCounts = {};
  final Map<String, int> _lastEpochs = {};
  final Map<String, Match> _liveMatches = {};

  final Map<String, Map<String, dynamic>> _offlineOutbox = {};
  bool _isFlushingOutbox = false;
  bool _isPollingFocused = false;
  bool _isPollingWatched = false;
  bool _isOnline = true;

  Timer? _focusedPollTimer;
  Timer? _backgroundPollTimer;
  Timer? _heartbeatTimer;

  bool get isOnline => _isOnline;
  int get pendingOutboxCount => _offlineOutbox.length;
  Match? getLiveMatch(String id) => _liveMatches[id];
  List<Match> get allLiveMatches => _liveMatches.values.toList();
  String? get activeScoringMatchId => _activeScoringMatchId;

  /// Authoritative Scorer Seam: Marks the match currently being scored locally.
  /// Background polling and cloud merges MUST NEVER overwrite this match.
  void setActiveScoringMatch(String matchId) {
    _activeScoringMatchId = matchId;
  }

  void clearActiveScoringMatch([String? matchId]) {
    if (matchId == null || _activeScoringMatchId == matchId) {
      _activeScoringMatchId = null;
    }
  }

  bool isActivelyScoring(String matchId) => _activeScoringMatchId == matchId;

  /// Initialize the telemetry hub with the root store and restore any pending offline outbox
  Future<void> init(Store store) async {
    _store = store;
    await _apiClient.init();
    await _loadPersistedOutbox();
    _startNetworkHeartbeat();

    final localLive = store.matches.where((m) => m.status == 'live').map((m) => m.id).toList();
    if (localLive.isNotEmpty) {
      _watchedMatchIds.addAll(localLive);
      _startBackgroundPolling();
    }
  }

  // ---------------------------------------------------------------------------
  // SCORER FLOW: Real-Time Ball Transmission & Offline Outbox
  // ---------------------------------------------------------------------------

  /// Called on Scorer device after every ball, boundary, wicket, extra, or over end.
  /// Dispatches immediately to cPanel if online, or buffers in offline outbox if offline.
  Future<void> onMatchScored(Match match) async {
    _liveMatches[match.id] = match;
    notifyListeners();
    if (_store == null) return;

    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    int eventsCount = 0;
    for (final inn in match.innings) {
      eventsCount += inn.events.length;
    }

    final prevRev = _lastRevisions[match.id] ?? 0;
    final revision = max(prevRev + 1, eventsCount);
    _lastRevisions[match.id] = revision;
    _lastEventsCounts[match.id] = eventsCount;
    _lastEpochs[match.id] = nowEpoch;

    final teamA = _store!.teamById(match.teamAId);
    final teamB = _store!.teamById(match.teamBId);
    final teamAName = teamA?.name ?? _store!.teamName(match.teamAId);
    final teamBName = teamB?.name ?? _store!.teamName(match.teamBId);

    final payloadMap = <String, dynamic>{
      'id': match.id,
      'status': match.status,
      'stage': match.stage,
      'result_text': match.resultText,
      'tournament_id': match.tournamentId,
      'team_a_id': match.teamAId,
      'team_b_id': match.teamBId,
      'team_a_name': teamAName,
      'team_b_name': teamBName,
      'overs_limit': match.oversLimit,
      'balls_per_over': match.ballsPerOver,
      'venue': match.venue,
      'date_iso': match.dateIso,
      'toss_winner_id': match.tossWinnerId,
      'toss_decision': match.tossDecision,
      'match_title': match.matchTitle,
      'ball_type': match.ballType,
      'revision': revision,
      'events_count': eventsCount,
      'updated_at_epoch': nowEpoch,
      'teams': [
        if (teamA != null) teamA.toJson(),
        if (teamB != null) teamB.toJson(),
      ],
      'payload': {
        ...match.toJson(),
        'teamAName': teamAName,
        'teamBName': teamBName,
        'teamALogo': teamA?.logo ?? '',
        'teamBLogo': teamB?.logo ?? '',
        'teamACode': teamA?.shortCode ?? '',
        'teamBCode': teamB?.shortCode ?? '',
        'revision': revision,
        'eventsCount': eventsCount,
        'updatedAtEpoch': nowEpoch,
      },
    };

    // Attempt instant live transmission in background (zero UI lag)
    unawaited(() async {
      try {
        await _apiClient.init();
        if (_apiClient.token == null || _apiClient.token!.isEmpty) {
          return;
        }

        final res = await _apiClient.pushLiveScore(match.id, payloadMap).timeout(
          const Duration(seconds: 4),
          onTimeout: () => {'status': 'timeout'},
        );

        if (res['status'] == 'success') {
          _isOnline = true;
          _offlineOutbox.remove(match.id);
          await _persistOutbox();
        } else {
          // Push failed or timed out: buffer in offline queue
          _queueOfflinePush(match.id, payloadMap);
        }
      } catch (_) {
        // Network unreachable: buffer in offline queue
        _queueOfflinePush(match.id, payloadMap);
      }
    }());
  }

  void _queueOfflinePush(String matchId, Map<String, dynamic> payload) {
    _offlineOutbox[matchId] = payload;
    _persistOutbox();
  }

  Future<void> _loadPersistedOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kOutboxPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            _offlineOutbox[entry.key] = Map<String, dynamic>.from(entry.value as Map);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_offlineOutbox.isEmpty) {
        await prefs.remove(_kOutboxPrefKey);
      } else {
        await prefs.setString(_kOutboxPrefKey, jsonEncode(_offlineOutbox));
      }
    } catch (_) {}
  }

  /// Automatically flushes all pending offline match scores as soon as connection is available
  Future<void> flushOfflineOutbox() async {
    if (_isFlushingOutbox || _offlineOutbox.isEmpty) return;
    _isFlushingOutbox = true;

    try {
      await _apiClient.init();
      if (_apiClient.token == null || _apiClient.token!.isEmpty) {
        return;
      }

      final keysToFlush = List<String>.from(_offlineOutbox.keys);
      for (final mid in keysToFlush) {
        final payload = _offlineOutbox[mid];
        if (payload == null) continue;

        try {
          final res = await _apiClient.pushLiveScore(mid, payload).timeout(
            const Duration(seconds: 5),
            onTimeout: () => {'status': 'timeout'},
          );

          if (res['status'] == 'success') {
            _offlineOutbox.remove(mid);
            _isOnline = true;
            debugPrint('[LiveMatchTelemetryHub] Flushed offline match: $mid');
          } else {
            // Keep in queue and wait for next heartbeat
            break;
          }
        } catch (_) {
          break;
        }
      }
      await _persistOutbox();
    } finally {
      _isFlushingOutbox = false;
    }
  }

  // ---------------------------------------------------------------------------
  // SPECTATOR FLOW: Focus Match & Background Multi-Match Polling
  // ---------------------------------------------------------------------------

  /// Called when a spectator opens the Match Scorecard screen.
  /// Accelerates polling to 2.0s heartbeat for ultra-smooth real-time ball updates.
  void setFocusedMatch(String matchId, {required Store store}) {
    _store = store;
    _focusedMatchId = matchId;
    _startFocusedPolling();
    // Fire immediate poll
    pollMatch(matchId);
  }

  /// Called when spectator leaves the Match Scorecard screen.
  void clearFocusedMatch(String matchId) {
    if (_focusedMatchId == matchId) {
      _focusedMatchId = null;
      _focusedPollTimer?.cancel();
      _focusedPollTimer = null;
    }
  }

  /// Called by Tournament or Public Matches screens to track multiple live fixtures
  void watchMatches(List<String> matchIds, {required Store store}) {
    _store = store;
    _watchedMatchIds.addAll(matchIds.where((id) => id.isNotEmpty));
    _startBackgroundPolling();
    // Fire immediate poll for all
    _pollWatchedMatches();
  }

  void unwatchMatches(List<String> matchIds) {
    _watchedMatchIds.removeAll(matchIds);
    if (_watchedMatchIds.isEmpty) {
      _backgroundPollTimer?.cancel();
      _backgroundPollTimer = null;
    }
  }

  /// Removes a match permanently from memory and clears polling state
  void removeLiveMatch(String matchId) {
    _liveMatches.remove(matchId);
    _watchedMatchIds.remove(matchId);
    _lastRevisions.remove(matchId);
    _lastEventsCounts.remove(matchId);
    _lastEpochs.remove(matchId);
    _offlineOutbox.remove(matchId);
    if (_focusedMatchId == matchId) {
      _focusedMatchId = null;
      _focusedPollTimer?.cancel();
      _focusedPollTimer = null;
    }
    notifyListeners();
  }

  void _startFocusedPolling() {
    _focusedPollTimer?.cancel();
    _focusedPollTimer = Timer.periodic(const Duration(milliseconds: 5000), (_) {
      if (_focusedMatchId != null) {
        pollMatch(_focusedMatchId!);
      }
    });
  }

  void _startBackgroundPolling() {
    _backgroundPollTimer?.cancel();
    _backgroundPollTimer = Timer.periodic(const Duration(milliseconds: 15000), (_) {
      _pollWatchedMatches();
    });
  }

  Future<void> _pollWatchedMatches() async {
    if (_isPollingWatched || _watchedMatchIds.isEmpty) return;
    _isPollingWatched = true;
    try {
      for (final mid in _watchedMatchIds.toList()) {
        // Scorer is authoritative author: NEVER poll locally active scoring match
        if (mid == _activeScoringMatchId) continue;
        await pollMatch(mid);
      }
    } finally {
      _isPollingWatched = false;
    }
  }

  /// Polls single match with deterministic delta checks (revision + events count + epoch)
  Future<bool> pollMatch(String matchId) async {
    if (_store == null) return false;
    // Local scorer is the sole source of truth; never fetch from server while scoring
    if (matchId == _activeScoringMatchId) return false;
    if (_focusedMatchId == matchId && _isPollingFocused) return false;

    if (_focusedMatchId == matchId) _isPollingFocused = true;

    try {
      await _apiClient.init();
      final res = await _apiClient.getLiveState(
        matchId,
        since: _lastEpochs[matchId],
        revision: _lastRevisions[matchId],
        eventsCount: _lastEventsCounts[matchId],
      );

      final isSuccess = res['status'] == 'success' || res['success'] == true;
      if (!isSuccess || res['data'] == null || res['data'] is! Map) {
        return false;
      }

      final data = Map<String, dynamic>.from(res['data'] as Map);

      // Server indicates client already has the latest state
      if (data['modified'] == false) {
        _isOnline = true;
        return false;
      }

      _isOnline = true;
      _lastEpochs[matchId] = (data['updated_at_epoch'] as num?)?.toInt() ?? (_lastEpochs[matchId] ?? 0);
      _lastRevisions[matchId] = (data['revision'] as num?)?.toInt() ?? (_lastRevisions[matchId] ?? 0);
      _lastEventsCounts[matchId] = (data['events_count'] as num?)?.toInt() ?? (_lastEventsCounts[matchId] ?? 0);

      final payloadCandidate = data['payload'];
      final rawPayload = payloadCandidate is Map && payloadCandidate.isNotEmpty
          ? Map<String, dynamic>.from(payloadCandidate)
          : Map<String, dynamic>.from(data);

      if (rawPayload.isNotEmpty) {
        // Enforce top-level server status and result_text to guarantee completed state sync
        if (data['status'] != null) {
          rawPayload['status'] = data['status'];
        }
        if (data['result_text'] != null && (data['result_text'] as String).isNotEmpty) {
          rawPayload['resultText'] = data['result_text'];
        }
        final updated = Match.fromJson(rawPayload);

        // Hydrate squads and player names into store
        final teamsData = data['teams'];
        if (teamsData is List) {
          for (final tItem in teamsData) {
            if (tItem is Map) {
              final tMap = Map<String, dynamic>.from(tItem);
              final tId = (tMap['id'] ?? '').toString();
              final tName = (tMap['name'] ?? '').toString();
              final tLogo = (tMap['logo'] ?? tMap['logo_base64'] ?? '').toString();
              final tCode = (tMap['shortCode'] ?? tMap['short_name'] ?? '').toString();
              final existingTeam = _store!.teamById(tId);
              if (existingTeam != null) {
                if (tLogo.isNotEmpty) existingTeam.logo = tLogo;
                if (tCode.isNotEmpty) existingTeam.shortCode = tCode;
              }
              final squad = <Player>[];
              if (tMap['players'] is List) {
                for (final pItem in (tMap['players'] as List)) {
                  if (pItem is Map) {
                    final pMap = Map<String, dynamic>.from(pItem);
                    final pId = (pMap['id'] ?? '').toString();
                    final pName = (pMap['name'] ?? 'Player').toString();
                    final player = Player(
                      id: pId,
                      name: pName,
                      jerseyNo: (pMap['jerseyNo'] as num?)?.toInt() ?? 0,
                      role: (pMap['role'] ?? 'Batter').toString(),
                      battingStyle: (pMap['battingStyle'] ?? 'Right-hand').toString(),
                      bowlingStyle: (pMap['bowlingStyle'] ?? 'None').toString(),
                      photoBase64: (pMap['photoBase64'] ?? pMap['photo_base64'] ?? '').toString(),
                      userCode: (pMap['userCode'] ?? '').toString(),
                      isVerified: pMap['isVerified'] == true,
                    );
                    squad.add(player);
                    if (existingTeam != null && existingTeam.playerById(pId) == null) {
                      existingTeam.players.add(player);
                    }
                  }
                }
              }
              if (existingTeam == null && tId.isNotEmpty) {
                _store!.teams.add(Team(
                  id: tId,
                  name: tName,
                  players: squad,
                  logo: tLogo,
                  shortCode: tCode,
                ));
              }
            }
          }
        }

        _liveMatches[updated.id] = updated;

        // Apply to Store
        if (_store!.isRemotePreview) {
          final idx = _store!.matches.indexWhere((x) => x.id == updated.id);
          if (idx >= 0) {
            _store!.matches[idx] = updated;
          } else {
            _store!.matches.add(updated);
          }
        } else {
          // Zero Main-Thread Lag: update in-memory and write matches key only (never re-encode the whole DB)
          final idx = _store!.matches.indexWhere((x) => x.id == updated.id);
          if (idx >= 0) {
            _store!.matches[idx] = updated;
          } else {
            _store!.matches.insert(0, updated);
          }
          await _store!.persistMatchesOnly(skipSync: true);
        }

        // Notify all UI screens (Scorecard, Tournament, Home) to re-render automatically
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Offline-first: silent handling
    } finally {
      if (_focusedMatchId == matchId) _isPollingFocused = false;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // NETWORK HEARTBEAT: Auto-Detect Reconnect & Auto-Flush
  // ---------------------------------------------------------------------------

  void _startNetworkHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final connected = await _apiClient.checkNetworkConnectivity();
      final wasOffline = !_isOnline;
      _isOnline = connected;

      if (connected) {
        // If connection just restored or outbox has pending items, flush immediately
        if (wasOffline || _offlineOutbox.isNotEmpty) {
          await flushOfflineOutbox();
        }
      }
    });
  }

  @override
  void dispose() {
    _focusedPollTimer?.cancel();
    _backgroundPollTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
