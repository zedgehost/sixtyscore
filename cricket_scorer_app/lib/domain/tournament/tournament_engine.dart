// 60Score tournament engine — automatic points table, NRR-based ranking,
// top-4 playoff qualification, semifinal seeding and grand-final assignment.
//
// Built on top of computePointsTable() in scoring.dart (ICC aggregate NRR,
// legal-ball overs, all-out = full quota, chase = actual balls faced).
// This file owns *qualification decisions*; it never invents results.
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';

/// Minimal store surface the playoff engine needs. [Store] satisfies this
/// interface implicitly (Dart structural interfaces), so call sites keep
/// passing the real Store while tests use a fake.
abstract class PlayoffStore {
  Tournament? tournamentById(String? id);
  String teamName(String id);
  List<Match> get matches;
  Future<void> persist();
}

/// Outcome of a playoff recalculation pass.
class PlayoffUpdate {
  /// True if any persisted state (seeds, finalists, qualification) changed.
  final bool changed;

  /// True when a consequential correction needs the user's explicit
  /// confirmation before it is applied (never applied silently).
  final bool needsConfirmation;

  /// Human-readable summary for logs / confirmation dialogs.
  final String message;

  /// Final (locked) qualifiers in rank order, empty if not finalized.
  final List<String> finalQualifiers;

  /// Provisionally guaranteed qualifiers (mathematical certainty only),
  /// empty when the stage is finalized.
  final List<String> provisionalQualifiers;

  const PlayoffUpdate({
    this.changed = false,
    this.needsConfirmation = false,
    this.message = '',
    this.finalQualifiers = const [],
    this.provisionalQualifiers = const [],
  });
}

/// League-stage fixtures of a tournament (excludes semifinals / final).
List<Match> leagueMatchesOf(String tournamentId, List<Match> all) => all
    .where((m) => m.tournamentId == tournamentId && m.stage == 'league')
    .toList();

/// Playoff fixtures of a tournament, ordered SF1, SF2, Final.
List<Match> playoffMatchesOf(String tournamentId, List<Match> all) {
  const order = [
    'qualifier1',
    'eliminator',
    'semifinal1',
    'semifinal2',
    'qualifier2',
    'playoff',
    'final',
  ];
  final list = all
      .where((m) => m.tournamentId == tournamentId && m.stage != 'league')
      .toList();
  list.sort((a, b) {
    final ia = order.indexOf(a.stage);
    final ib = order.indexOf(b.stage);
    final ordA = ia == -1 ? 999 : ia;
    final ordB = ib == -1 ? 999 : ib;
    return ordA.compareTo(ordB);
  });
  return list;
}

/// A league fixture is finalized when it can no longer change the table:
/// completed, no-result, or cancelled.
bool _fixtureFinalized(Match m) =>
    m.status == 'completed' ||
    m.status == 'noResult' ||
    m.status == 'cancelled';

/// True when every league fixture is finalized.
bool leagueStageFinalized(String tournamentId, List<Match> all) {
  final league = leagueMatchesOf(tournamentId, all);
  if (league.isEmpty) return false;
  return league.every(_fixtureFinalized);
}

/// Winner's team ID for a completed match, or null for ties / no-results /
/// unfinished matches. Never guesses from a live score.
String? matchWinnerId(Match m) {
  if (m.status != 'completed') return null;
  if (m.innings.length < 2) return null;
  final i1 = m.innings[0];
  final i2 = m.innings[1];

  // Super over winner check first
  final soWinner = superOverWinnerId(m);
  if (soWinner != null) return soWinner;

  if (i2.target > 0) {
    if (i2.totalRuns >= i2.target) return i2.battingTeamId;
    if (i2.totalRuns < i2.target - 1) return i1.battingTeamId;
    return null; // Tie
  }

  if (i1.totalRuns == i2.totalRuns) return null; // tie — no winner
  return i1.totalRuns > i2.totalRuns ? i1.battingTeamId : i2.battingTeamId;
}

/// Teams mathematically guaranteed a top-4 finish on points alone.
/// Conservative: a team qualifies provisionally only if fewer than four
/// *other* teams could still finish with strictly more points. NRR is
/// ignored here on purpose — this direction is always safe.
List<String> guaranteedQualifiers(
  List<PointsRow> table,
  List<Match> leagueMatches,
) {
  final remaining = <String, int>{};
  for (final m in leagueMatches) {
    if (_fixtureFinalized(m)) continue;
    remaining[m.teamAId] = (remaining[m.teamAId] ?? 0) + 1;
    remaining[m.teamBId] = (remaining[m.teamBId] ?? 0) + 1;
  }
  final guaranteed = <String>[];
  for (final row in table) {
    var canExceed = 0;
    for (final other in table) {
      if (other.teamId == row.teamId) continue;
      final maxOther = other.points + 2 * (remaining[other.teamId] ?? 0);
      if (maxOther > row.points) canExceed++;
    }
    if (canExceed < 4) guaranteed.add(row.teamId);
  }
  return guaranteed;
}

/// Points table for the LEAGUE stage only (playoff matches never pollute it).
List<PointsRow> leaguePointsTable(
  Tournament t,
  List<Match> allMatches,
) {
  var tids = t.teamIds;
  if (tids.isEmpty) {
    final derived = <String>{};
    for (final m in allMatches) {
      if (m.tournamentId == t.id) {
        if (m.teamAId.isNotEmpty) derived.add(m.teamAId);
        if (m.teamBId.isNotEmpty) derived.add(m.teamBId);
      }
    }
    tids = derived.toList();
  }
  return computePointsTable(
    t.id,
    tids,
    allMatches.where((m) => m.stage == 'league').toList(),
    pointsAdjustments: t.pointsAdjustments,
    pointsTableOverrides: t.pointsTableOverrides,
  );
}

/// Recompute qualification and playoff assignments for [tournamentId].
///
/// Safe-recalculation contract:
/// - Idempotent: repeated calls with unchanged data change nothing.
/// - Never reseeds a playoff fixture that has started (live/completed).
/// - Never assigns a finalist from an unfinished match.
/// - Corrections after finalization need [force] = true (UI confirms first).
Future<PlayoffUpdate> applyPlayoffUpdate(
  PlayoffStore store,
  String tournamentId, {
  bool force = false,
}) async {
  final t = store.tournamentById(tournamentId);
  if (t == null) return const PlayoffUpdate(message: 'Tournament not found');
  final all = store.matches;
  final table = leaguePointsTable(t, all);
  if (table.isEmpty) return const PlayoffUpdate(message: 'No teams');

  // v1.4.5 Super 4 auto-fill trigger (brief): the league stage counts as
  // done for SEEDING only when every league fixture is completed or
  // no-result. A cancelled fixture does NOT trigger auto-fill — it must
  // be resolved to completed/no-result, or seeded manually. (Unlike
  // leagueStageFinalized, which also treats cancelled as finalized for
  // the remaining-matches math in guaranteedQualifiers.)
  final league = leagueMatchesOf(tournamentId, all);
  final finalized = (league.isNotEmpty &&
          league.every((m) => m.status == 'completed' || m.status == 'noResult')) ||
      (t.qualificationFinalized && t.qualifiedTeamIds.isNotEmpty);
  var changed = false;
  final notes = <String>[];

  Match? playoffByStage(String stage) {
    for (final m in all) {
      if (m.tournamentId == tournamentId && m.stage == stage) return m;
    }
    return null;
  }

  bool playoffStarted(Match? m) =>
      m != null && (m.status == 'live' || m.status == 'completed');

  final sf1 = playoffByStage('semifinal1');
  final sf2 = playoffByStage('semifinal2');
  final q1 = playoffByStage('qualifier1');
  final elim = playoffByStage('eliminator');
  final q2 = playoffByStage('qualifier2');
  final fin = playoffByStage('final');
  final anyPlayoffStarted = playoffStarted(sf1) ||
      playoffStarted(sf2) ||
      playoffStarted(q1) ||
      playoffStarted(elim) ||
      playoffStarted(q2) ||
      playoffStarted(fin);

  // ---------- Final qualification ----------
  List<String> finalQ = [];
  if (finalized) {
    finalQ = league.isNotEmpty
        ? table.take(4).map((r) => r.teamId).toList()
        : t.qualifiedTeamIds;
    final previouslyFinalized = t.qualificationFinalized;
    final storedQ = t.qualifiedTeamIds;
    final qChanged =
        storedQ.length != finalQ.length ||
        !Iterable.generate(finalQ.length)
            .every((i) => storedQ[i] == finalQ[i]);

    if (!previouslyFinalized || (qChanged && !anyPlayoffStarted)) {
      final needsConfirm = previouslyFinalized && qChanged && !force;
      if (needsConfirm) {
        return PlayoffUpdate(
          needsConfirmation: true,
          message:
              'League results changed after qualification was locked. '
              'Confirm to reseed the semifinals with the corrected standings.',
          finalQualifiers: finalQ,
        );
      }
      t.qualifiedTeamIds = finalQ;
      t.qualificationFinalized = true;
      changed = true;
      notes.add('Top 4 qualified: ${finalQ.map(store.teamName).join(', ')}');
    } else if (qChanged && anyPlayoffStarted) {
      // Playoffs already underway — never silently reseed.
      return PlayoffUpdate(
        needsConfirmation: true,
        message:
            'League standings changed but the playoffs have already started. '
            'Reseeding is blocked to protect completed playoff matches.',
        finalQualifiers: storedQ,
      );
    }

    // ---------- Semifinal seeding (1v4, 2v3) ----------
    // v1.4.5 Super 4 auto-fill: fill TBA slots ONLY. A slot that already
    // has a team — auto-filled on an earlier pass or picked manually in
    // the fixture editor — is never overwritten by this pass, so once
    // filled it sticks. Started playoffs are still never touched.
    void seedSemi(Match? semi, String a, String b, String label) {
      if (semi == null || playoffStarted(semi)) return;
      if (semi.teamAId.isEmpty && a.isNotEmpty) {
        semi.teamAId = a;
        changed = true;
        notes.add('$label Team A: ${store.teamName(a)}');
      }
      if (semi.teamBId.isEmpty && b.isNotEmpty) {
        semi.teamBId = b;
        changed = true;
        notes.add('$label Team B: ${store.teamName(b)}');
      }
    }

    if (finalQ.length == 4) {
      // Semifinal seeding (1v4, 2v3)
      seedSemi(sf1, finalQ[0], finalQ[3], 'Semi Final 1');
      seedSemi(sf2, finalQ[1], finalQ[2], 'Semi Final 2');

      // Page Playoff seeding: Q1 (1v2), Eliminator (3v4)
      seedSemi(q1, finalQ[0], finalQ[1], 'Qualifier 1');
      seedSemi(elim, finalQ[2], finalQ[3], 'Eliminator');
    }

    // Qualifier 2 seeding (Loser of Q1 vs Winner of Eliminator)
    if (q2 != null && !playoffStarted(q2) && q1 != null && elim != null) {
      final q1Winner = matchWinnerId(q1);
      final elimWinner = matchWinnerId(elim);
      if (q1.status == 'completed' && q1Winner != null) {
        final q1Loser = q1Winner == q1.teamAId ? q1.teamBId : q1.teamAId;
        if (q2.teamAId.isEmpty && q1Loser.isNotEmpty) {
          q2.teamAId = q1Loser;
          changed = true;
          notes.add('Qualifier 2 Team A: ${store.teamName(q1Loser)}');
        }
      }
      if (elim.status == 'completed' && elimWinner != null) {
        if (q2.teamBId.isEmpty && elimWinner.isNotEmpty) {
          q2.teamBId = elimWinner;
          changed = true;
          notes.add('Qualifier 2 Team B: ${store.teamName(elimWinner)}');
        }
      }
    }
  }

  // ---------- Grand-final assignment (only from finalized semifinals) ----------
  void assignFinalist(Match? semi, bool toTeamA) {
    if (semi == null || fin == null) return;
    if (playoffStarted(fin)) return; // final already underway — hands off
    final winner = matchWinnerId(semi);
    if (winner == null) return; // tie / unfinished / no-result: slot stays TBD
    if (toTeamA && fin.teamAId != winner) {
      fin.teamAId = winner;
      changed = true;
      notes.add('Grand Final Team A: ${store.teamName(winner)}');
    }
    if (!toTeamA && fin.teamBId != winner) {
      fin.teamBId = winner;
      changed = true;
      notes.add('Grand Final Team B: ${store.teamName(winner)}');
    }
  }

  // Grand Final Assignment: Page Playoff (Winner Q1 vs Winner Q2) or Semis (Winner SF1 vs Winner SF2)
  if (q1 != null && q2 != null) {
    assignFinalist(q1, true);
    assignFinalist(q2, false);
  } else if (sf1 != null || sf2 != null) {
    assignFinalist(sf1, true);
    assignFinalist(sf2, false);
  } else if (fin != null && !playoffStarted(fin) && finalQ.length >= 2) {
    // Direct league-to-final (no semifinals): top 2 seeds contest the final
    if (fin.teamAId.isEmpty && finalQ[0].isNotEmpty) {
      fin.teamAId = finalQ[0];
      changed = true;
      notes.add('Grand Final Team A (Seed 1): ${store.teamName(finalQ[0])}');
    }
    if (fin.teamBId.isEmpty && finalQ[1].isNotEmpty) {
      fin.teamBId = finalQ[1];
      changed = true;
      notes.add('Grand Final Team B (Seed 2): ${store.teamName(finalQ[1])}');
    }
  }

  // ---------- Provisional qualifiers (league not finalized) ----------
  List<String> provisional = [];
  if (!finalized) {
    provisional = guaranteedQualifiers(
      table,
      leagueMatchesOf(tournamentId, all),
    );
  }

  if (changed) await store.persist();
  return PlayoffUpdate(
    changed: changed,
    message: notes.isEmpty ? 'No playoff changes' : notes.join(' · '),
    finalQualifiers: t.qualificationFinalized ? t.qualifiedTeamIds : const [],
    provisionalQualifiers: provisional,
  );
}

/// Pure-Dart round-robin fixture generator for tournaments.
/// Generates single or double round-robin match fixtures using polygon rotation.
List<Match> generateRoundRobinFixtures({
  required String tournamentId,
  required List<String> teamIds,
  required int oversLimit,
  int ballsPerOver = 6,
  String venue = '',
  String ballType = 'Tennis Ball',
  DateTime? startDate,
  int matchesPerDay = 1,
  bool doubleRoundRobin = false,
  String creatorId = '',
  String creatorName = '',
  String creatorCode = '',
}) {
  final teams = teamIds.toSet().where((id) => id.trim().isNotEmpty).toList();
  if (teams.length < 2) return [];
  final isOdd = teams.length % 2 != 0;
  if (isOdd) {
    teams.add('__BYE__');
  }

  final n = teams.length;
  final rounds = n - 1;
  final matchesPerRound = n ~/ 2;
  final fixtures = <Match>[];
  var currentDate = startDate ?? DateTime.now();
  var matchCounter = 0;

  for (var round = 0; round < rounds; round++) {
    for (var matchIdx = 0; matchIdx < matchesPerRound; matchIdx++) {
      final home = teams[matchIdx];
      final away = teams[n - 1 - matchIdx];

      if (home != '__BYE__' && away != '__BYE__') {
        final isEvenRound = round % 2 == 0;
        final teamA = isEvenRound ? home : away;
        final teamB = isEvenRound ? away : home;

        final fixtureDate = currentDate.add(Duration(days: matchCounter ~/ matchesPerDay));
        fixtures.add(Match(
          id: 'fix_${tournamentId}_${fixtures.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
          tournamentId: tournamentId,
          teamAId: teamA,
          teamBId: teamB,
          xiA: const [],
          xiB: const [],
          oversLimit: oversLimit,
          ballsPerOver: ballsPerOver,
          venue: venue,
          dateIso: fixtureDate.toIso8601String(),
          stage: 'league',
          matchTitle: 'Match ${fixtures.length + 1}',
          ballType: ballType,
          status: 'upcoming',
          tossWinnerId: '',
          tossDecision: 'bat',
          creatorId: creatorId,
          creatorName: creatorName,
          creatorCode: creatorCode,
        ));
        matchCounter++;
      }
    }

    final last = teams.removeLast();
    teams.insert(1, last);
  }

  if (doubleRoundRobin) {
    final firstLegCount = fixtures.length;
    for (var i = 0; i < firstLegCount; i++) {
      final leg1 = fixtures[i];
      final fixtureDate = currentDate.add(Duration(days: matchCounter ~/ matchesPerDay));
      fixtures.add(Match(
        id: 'fix_${tournamentId}_${fixtures.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
        tournamentId: tournamentId,
        teamAId: leg1.teamBId,
        teamBId: leg1.teamAId,
        xiA: const [],
        xiB: const [],
        oversLimit: oversLimit,
        ballsPerOver: ballsPerOver,
        venue: venue,
        dateIso: fixtureDate.toIso8601String(),
        stage: 'league',
        matchTitle: 'Match ${fixtures.length + 1}',
        ballType: ballType,
        status: 'upcoming',
        tossWinnerId: '',
        tossDecision: 'bat',
        creatorId: creatorId,
        creatorName: creatorName,
        creatorCode: creatorCode,
      ));
      matchCounter++;
    }
  }

  return fixtures;
}
