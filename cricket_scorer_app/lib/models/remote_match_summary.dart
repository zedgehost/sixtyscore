// Lightweight match feed summary model returned by `GET /api/matches/feed`.
// Keeps Homepage live & recent match cards responsive without downloading
// full ball-by-ball payloads until a user taps into Match Centre.

class InningsScoreSummary {
  final String battingTeamId;
  final int totalRuns;
  final int wickets;
  final int legalBalls;
  final String oversText;
  final double crr;
  final int target;

  const InningsScoreSummary({
    required this.battingTeamId,
    required this.totalRuns,
    required this.wickets,
    required this.legalBalls,
    required this.oversText,
    required this.crr,
    this.target = 0,
  });

  factory InningsScoreSummary.fromJson(Map<String, dynamic> j) =>
      InningsScoreSummary(
        battingTeamId: (j['batting_team_id'] ?? '').toString(),
        totalRuns: (j['total_runs'] as num?)?.toInt() ?? 0,
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        legalBalls: (j['legal_balls'] as num?)?.toInt() ?? 0,
        oversText: (j['overs_text'] ?? '0.0').toString(),
        crr: (j['crr'] as num?)?.toDouble() ?? 0.0,
        target: (j['target'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'batting_team_id': battingTeamId,
        'total_runs': totalRuns,
        'wickets': wickets,
        'legal_balls': legalBalls,
        'overs_text': oversText,
        'crr': crr,
        'target': target,
      };
}

class RemoteMatchSummary {
  final String id;
  final String? tournamentId;
  final String creatorId;
  final String creatorCode;
  final String creatorName;
  final String teamAId;
  final String teamBId;
  final String teamAName;
  final String teamBName;
  final String matchTitle;
  final int oversLimit;
  final int ballsPerOver;
  final String venue;
  final String dateIso;
  final String status;
  final String stage;
  final String resultText;
  final String ballType;
  final List<InningsScoreSummary> innings;
  final int updatedAtEpoch;

  const RemoteMatchSummary({
    required this.id,
    this.tournamentId,
    this.creatorId = '',
    this.creatorCode = '',
    this.creatorName = '',
    this.teamAId = '',
    this.teamBId = '',
    this.teamAName = 'Team A',
    this.teamBName = 'Team B',
    this.matchTitle = '',
    this.oversLimit = 20,
    this.ballsPerOver = 6,
    this.venue = '',
    this.dateIso = '',
    this.status = 'live',
    this.stage = 'league',
    this.resultText = '',
    this.ballType = 'Tennis Ball',
    this.innings = const [],
    this.updatedAtEpoch = 0,
  });

  bool get isLive => status == 'live';
  bool get isCompleted => status == 'completed' || status == 'noResult';

  InningsScoreSummary? inningsForTeam(String teamId) {
    for (final inn in innings) {
      if (inn.battingTeamId == teamId) return inn;
    }
    return null;
  }

  factory RemoteMatchSummary.fromJson(Map<String, dynamic> j) {
    final rawInnings = (j['innings_summary'] as List?) ?? const [];
    return RemoteMatchSummary(
      id: (j['id'] ?? '').toString(),
      tournamentId: j['tournament_id'] as String?,
      creatorId: (j['creator_id'] ?? '').toString(),
      creatorCode: (j['creator_code'] ?? '').toString(),
      creatorName: (j['creator_name'] ?? '').toString(),
      teamAId: (j['team_a_id'] ?? '').toString(),
      teamBId: (j['team_b_id'] ?? '').toString(),
      teamAName: (j['team_a_name'] ?? 'Team A').toString(),
      teamBName: (j['team_b_name'] ?? 'Team B').toString(),
      matchTitle: (j['match_title'] ?? '').toString(),
      oversLimit: (j['overs_limit'] as num?)?.toInt() ?? 20,
      ballsPerOver: (j['balls_per_over'] as num?)?.toInt() ?? 6,
      venue: (j['venue'] ?? '').toString(),
      dateIso: (j['date_iso'] ?? '').toString(),
      status: (j['status'] ?? 'live').toString(),
      stage: (j['stage'] ?? 'league').toString(),
      resultText: (j['result_text'] ?? '').toString(),
      ballType: (j['ball_type'] ?? 'Tennis Ball').toString(),
      innings: rawInnings
          .whereType<Map>()
          .map((e) => InningsScoreSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      updatedAtEpoch: (j['updated_at_epoch'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tournament_id': tournamentId,
        'creator_id': creatorId,
        'creator_code': creatorCode,
        'creator_name': creatorName,
        'team_a_id': teamAId,
        'team_b_id': teamBId,
        'team_a_name': teamAName,
        'team_b_name': teamBName,
        'match_title': matchTitle,
        'overs_limit': oversLimit,
        'balls_per_over': ballsPerOver,
        'venue': venue,
        'date_iso': dateIso,
        'status': status,
        'stage': stage,
        'result_text': resultText,
        'ball_type': ballType,
        'innings_summary': innings.map((e) => e.toJson()).toList(),
        'updated_at_epoch': updatedAtEpoch,
      };
}
