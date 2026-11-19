// 60Score / STUMPS - cPanel REST API Client
// Secure, resilient HTTP client communicating with the cPanel PHP Backend.
// Injects Bearer tokens, manages timeouts, and provides typed JSON operations.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CpanelApiClient {
  static const String _defaultBaseUrl = 'https://api.careerinpak.com/api';
  static const String _tokenPrefKey = 'cpanel_api_token';
  static const String _baseUrlPrefKey = 'cpanel_api_base_url';

  static String? _cachedToken;
  static String? _cachedBaseUrl;

  final http.Client _client;
  String _baseUrl;
  String? _token;

  CpanelApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _cachedBaseUrl ?? _defaultBaseUrl,
        _token = _cachedToken;

  String get baseUrl => _baseUrl;
  String? get token => _token ?? _cachedToken;

  /// Load persisted credentials from local preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenPrefKey);
    _cachedToken = _token;
    final customUrl = prefs.getString(_baseUrlPrefKey);
    if (customUrl != null && customUrl.isNotEmpty) {
      _baseUrl = customUrl;
      _cachedBaseUrl = customUrl;
    }
  }

  /// Update base URL (e.g. when connecting to your live cPanel domain)
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    _cachedBaseUrl = _baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlPrefKey, _baseUrl);
  }

  /// Store authentication token locally
  Future<void> setToken(String? token) async {
    _token = token;
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_tokenPrefKey, token);
    } else {
      await prefs.remove(_tokenPrefKey);
    }
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ---------------- AUTHENTICATION ----------------

  Future<Map<String, dynamic>> signInWithGoogle({
    String? idToken,
    String? accessToken,
  }) async {
    final res = await _post('/auth/google', {
      if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
      if (accessToken != null && accessToken.isNotEmpty)
        'access_token': accessToken,
    });
    if (res['data']?['token'] != null) {
      await setToken(res['data']['token'] as String);
    }
    return res;
  }

  Future<Map<String, dynamic>> completeOnboarding({
    required String name,
    required String cricketRole,
    String battingStyle = 'Right-hand bat',
    String bowlingStyle = 'Right-arm fast-medium',
    int jerseyNumber = 7,
    String city = '',
    String contact = '',
  }) async {
    return _post('/auth/complete-onboarding', {
      'name': name,
      'cricket_role': cricketRole,
      'batting_style': battingStyle,
      'bowling_style': bowlingStyle,
      'jersey_number': jerseyNumber,
      'city': city,
      'contact': contact,
    });
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? cricketRole,
    String? battingStyle,
    String? bowlingStyle,
    int? jerseyNumber,
    String? city,
    String? contact,
  }) async {
    final payload = <String, dynamic>{'name': name};
    if (cricketRole != null) payload['cricket_role'] = cricketRole;
    if (battingStyle != null) payload['batting_style'] = battingStyle;
    if (bowlingStyle != null) payload['bowling_style'] = bowlingStyle;
    if (jerseyNumber != null) payload['jersey_number'] = jerseyNumber;
    if (city != null) payload['city'] = city;
    if (contact != null) payload['contact'] = contact;
    return _post('/auth/profile', payload);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? city,
    String? contact,
  }) async {
    final res = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'city': city ?? '',
      'contact': contact ?? '',
    });
    if (res['data']?['token'] != null) {
      await setToken(res['data']['token']);
    }
    return res;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    if (res['data']?['token'] != null) {
      await setToken(res['data']['token']);
    }
    return res;
  }

  Future<Map<String, dynamic>> getMe() async {
    return _get('/auth/me');
  }

  // ---------------- PLAYERS ----------------

  Future<Map<String, dynamic>> getPlayerProfile(String identifier) async {
    return _get('/players/profile?id=${Uri.encodeComponent(identifier)}');
  }

  Future<Map<String, dynamic>> claimProfile(String playerId) async {
    return _post('/players/claim', {'player_id': playerId});
  }

  Future<Map<String, dynamic>> searchPlayers(String query) async {
    return _get('/players/search?q=${Uri.encodeComponent(query)}');
  }

  // ---------------- TEAMS ----------------

  Future<Map<String, dynamic>> searchTeams(String query) async {
    return _get('/teams/search?q=${Uri.encodeComponent(query)}');
  }

  Future<Map<String, dynamic>> getTeamDetail(String teamId) async {
    return _get('/teams/${Uri.encodeComponent(teamId)}');
  }

  // ---------------- MATCHES ----------------

  Future<Map<String, dynamic>> getMatchesFeed({int limit = 15}) async {
    return _get('/matches/feed?limit=$limit');
  }

  Future<Map<String, dynamic>> getLiveMatches() async {
    return _get('/matches/live');
  }

  Future<Map<String, dynamic>> getMatchDetail(String id) async {
    return _get('/matches/$id');
  }

  Future<Map<String, dynamic>> createMatch(Map<String, dynamic> matchData) async {
    return _post('/matches', matchData);
  }

  Future<Map<String, dynamic>> updateMatch(String id, Map<String, dynamic> updateData) async {
    return _put('/matches/$id', updateData);
  }

  /// Real-time live score push (ultra-fast per-ball transmission)
  Future<Map<String, dynamic>> pushLiveScore(
      String id, Map<String, dynamic> liveData) async {
    return _post('/matches/$id/live-push', liveData);
  }

  /// Fast live state check with delta revision, events count, and timestamp support
  Future<Map<String, dynamic>> getLiveState(
    String id, {
    int? since,
    int? revision,
    int? eventsCount,
  }) async {
    final params = <String>[];
    if (since != null && since > 0) params.add('since=$since');
    if (revision != null && revision > 0) params.add('revision=$revision');
    if (eventsCount != null && eventsCount >= 0) params.add('events=$eventsCount');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _get('/matches/$id/live-state$query');
  }

  /// Lightweight connectivity probe (checks true internet access against backend)
  Future<bool> checkNetworkConnectivity() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final res = await _client.get(uri).timeout(const Duration(milliseconds: 1800));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ---------------- TOURNAMENTS ----------------

  Future<Map<String, dynamic>> searchTournaments(String query, {int limit = 25}) async {
    return _get('/tournaments/public?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  Future<Map<String, dynamic>> getTournamentDetail(String id) async {
    return _get('/tournaments/${Uri.encodeComponent(id)}');
  }

  // ---------------- 100% OFFLINE-FIRST 2-WAY SYNC ----------------

  Future<Map<String, dynamic>> batchSync({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>> matches = const [],
    List<Map<String, dynamic>> players = const [],
    List<Map<String, dynamic>> teams = const [],
    List<Map<String, dynamic>> tournaments = const [],
    List<Map<String, dynamic>> regPlayers = const [],
    List<Map<String, dynamic>> drafts = const [],
    List<Map<String, dynamic>> manualStats = const [],
    List<Map<String, dynamic>> tombstones = const [],
  }) async {
    final body = <String, dynamic>{
      'matches': matches,
      'players': players,
      'teams': teams,
      'tournaments': tournaments,
      'regPlayers': regPlayers,
      'drafts': drafts,
      'manualStats': manualStats,
      'tombstones': tombstones,
    };
    if (profile != null) {
      body['profile'] = profile;
    }
    return _post('/sync/batch', body);
  }

  Future<Map<String, dynamic>> pullSync() async {
    return _get('/sync/pull');
  }

  // ---------------- INTERNAL HTTP HELPERS ----------------

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
      return _processResponse(res);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await _client
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return _processResponse(res);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await _client
          .put(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return _processResponse(res);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Map<String, dynamic> _processResponse(http.Response res) {
    try {
      final Map<String, dynamic> json = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return json;
      } else {
        return {
          'status': 'error',
          'statusCode': res.statusCode,
          'message': json['message'] ?? 'Request failed (${res.statusCode})',
          'errors': json['errors']
        };
      }
    } catch (_) {
      return {
        'status': 'error',
        'statusCode': res.statusCode,
        'message': 'HTTP ${res.statusCode}: ${res.body}',
      };
    }
  }

  void dispose() {
    _client.close();
  }
}
