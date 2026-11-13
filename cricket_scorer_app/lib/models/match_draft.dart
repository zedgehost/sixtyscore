import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

/// Holds transitional match configuration data across multi-step wizard screens:
/// 1. Create Match (Setup)
/// 2. Match Toss
/// 3. Match Lineups
class MatchDraft {
  String? tournamentId;
  String teamAId;
  String teamBId;
  int oversLimit;
  int ballsPerOver;
  String venue;
  String dateIso;
  String matchTitle;
  String ballType;
  String season;
  String stage; // league, playoff, qualifier1, eliminator, qualifier2, semifinal1, semifinal2, final, friendly
  int totalWickets;
  bool lastManStands;
  bool widePenalty;
  bool noBallPenalty;
  String? tossWinnerId;
  String tossDecision; // 'bat' | 'bowl'
  List<String> xiA;
  List<String> xiB;
  Match? existingMatch;
  String creatorId;
  String creatorName;
  String creatorCode;

  MatchDraft({
    this.tournamentId,
    required this.teamAId,
    required this.teamBId,
    this.oversLimit = 20,
    this.ballsPerOver = 6,
    this.venue = '',
    this.dateIso = '',
    this.matchTitle = '',
    this.ballType = 'Tennis',
    this.season = '',
    this.stage = 'league',
    this.totalWickets = 10,
    this.lastManStands = false,
    this.widePenalty = true,
    this.noBallPenalty = true,
    this.tossWinnerId,
    this.tossDecision = 'bat',
    this.xiA = const [],
    this.xiB = const [],
    this.existingMatch,
    this.creatorId = '',
    this.creatorName = '',
    this.creatorCode = '',
  });

  /// Factory constructor to seamlessly initialize a draft from an existing match
  factory MatchDraft.fromMatch(Match m) {
    return MatchDraft(
      tournamentId: m.tournamentId,
      teamAId: m.teamAId,
      teamBId: m.teamBId,
      oversLimit: m.oversLimit,
      ballsPerOver: m.ballsPerOver,
      venue: m.venue,
      dateIso: m.dateIso,
      matchTitle: m.matchTitle,
      ballType: m.ballType,
      season: m.season,
      stage: m.stage.isNotEmpty ? m.stage : 'league',
      totalWickets: m.totalWickets > 0 ? m.totalWickets : 10,
      lastManStands: m.lastManStands,
      widePenalty: m.widePenalty,
      noBallPenalty: m.noBallPenalty,
      tossWinnerId: m.tossWinnerId.isNotEmpty ? m.tossWinnerId : null,
      tossDecision: m.tossDecision.isNotEmpty ? m.tossDecision : 'bat',
      xiA: List.from(m.xiA),
      xiB: List.from(m.xiB),
      existingMatch: m,
      creatorId: m.creatorId,
      creatorName: m.creatorName,
      creatorCode: m.creatorCode,
    );
  }

  /// Build a real live Match instance from this draft
  Match toMatch() {
    if (existingMatch != null) {
      final em = existingMatch!;
      em.tournamentId = tournamentId;
      em.teamAId = teamAId;
      em.teamBId = teamBId;
      em.xiA = xiA;
      em.xiB = xiB;
      em.oversLimit = oversLimit;
      em.ballsPerOver = ballsPerOver;
      em.venue = venue;
      em.dateIso = dateIso;
      em.matchTitle = matchTitle;
      em.ballType = ballType;
      em.season = season;
      em.stage = stage;
      em.tossWinnerId = tossWinnerId ?? teamAId;
      em.tossDecision = tossDecision;
      em.status = 'live';
      em.totalWickets = totalWickets;
      em.lastManStands = lastManStands;
      em.widePenalty = widePenalty;
      em.noBallPenalty = noBallPenalty;
      if (creatorId.isNotEmpty && em.creatorId.isEmpty) {
        em.creatorId = creatorId;
        em.creatorName = creatorName;
        em.creatorCode = creatorCode;
      }
      return em;
    }

    return Match(
      id: Store.newId('match'),
      tournamentId: tournamentId,
      teamAId: teamAId,
      teamBId: teamBId,
      xiA: xiA,
      xiB: xiB,
      oversLimit: oversLimit,
      ballsPerOver: ballsPerOver,
      venue: venue,
      dateIso: dateIso,
      matchTitle: matchTitle,
      ballType: ballType,
      season: season,
      stage: stage,
      tossWinnerId: tossWinnerId ?? teamAId,
      tossDecision: tossDecision,
      status: 'live',
      totalWickets: totalWickets,
      lastManStands: lastManStands,
      widePenalty: widePenalty,
      noBallPenalty: noBallPenalty,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorCode: creatorCode,
    );
  }

  /// Build an upcoming scheduled fixture (Score Later flow)
  Match toUpcomingFixture() {
    if (existingMatch != null) {
      final em = existingMatch!;
      em.tournamentId = tournamentId;
      em.teamAId = teamAId;
      em.teamBId = teamBId;
      em.xiA = xiA;
      em.xiB = xiB;
      em.oversLimit = oversLimit;
      em.ballsPerOver = ballsPerOver;
      em.venue = venue;
      em.dateIso = dateIso;
      em.matchTitle = matchTitle;
      em.ballType = ballType;
      em.season = season;
      em.stage = stage;
      em.tossWinnerId = tossWinnerId ?? '';
      em.tossDecision = tossDecision;
      em.status = 'upcoming';
      em.totalWickets = totalWickets;
      em.lastManStands = lastManStands;
      em.widePenalty = widePenalty;
      em.noBallPenalty = noBallPenalty;
      if (creatorId.isNotEmpty && em.creatorId.isEmpty) {
        em.creatorId = creatorId;
        em.creatorName = creatorName;
        em.creatorCode = creatorCode;
      }
      return em;
    }

    return Match(
      id: Store.newId('match'),
      tournamentId: tournamentId,
      teamAId: teamAId,
      teamBId: teamBId,
      xiA: xiA,
      xiB: xiB,
      oversLimit: oversLimit,
      ballsPerOver: ballsPerOver,
      venue: venue,
      dateIso: dateIso,
      matchTitle: matchTitle,
      ballType: ballType,
      season: season,
      stage: stage,
      tossWinnerId: tossWinnerId ?? '',
      tossDecision: tossDecision,
      status: 'upcoming',
      totalWickets: totalWickets,
      lastManStands: lastManStands,
      widePenalty: widePenalty,
      noBallPenalty: noBallPenalty,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorCode: creatorCode,
    );
  }
}
