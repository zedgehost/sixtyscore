import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
// Completed matches archive (v1.3.5).
//
// Home's "Recent Matches" opens THIS list — every completed match,
// newest first — never the general Matches screen (whose first
// section is Upcoming fixtures). From here the user opens whichever
// match they want (→ its scorecard) or deletes one on its own.
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/views/widgets/broadcast_match_card.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';

class CompletedMatchesScreen extends StatefulWidget {
  final Store store;
  const CompletedMatchesScreen({super.key, required this.store});

  @override
  State<CompletedMatchesScreen> createState() =>
      _CompletedMatchesScreenState();
}

class _CompletedMatchesScreenState extends State<CompletedMatchesScreen> {
  Store get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  // v1.4.5: no-result matches are finished matches too — they belong
  // in the Completed view alongside completed ones. Live/scheduled
  // matches stay excluded. The status itself is untouched.
  List<Match> get _completed {
    final list = store.matches
        .where((m) => m.status == 'completed' || m.status == 'noResult')
        .toList();
    list.sort((a, b) => b.dateIso.compareTo(a.dateIso));
    return list;
  }

  Future<void> _confirmDelete(Match m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete match?'),
        content: Text(
          'Delete ${store.teamName(m.teamAId)} vs '
          '${store.teamName(m.teamBId)} and its scorecard? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await store.deleteMatch(m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _completed;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Completed Matches')),
      body: matches.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.scoreboard_outlined,
                title: 'No completed matches yet',
                subtitle:
                    'Finished matches will appear here with full scorecards.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _card(matches[i]),
            ),
    );
  }

  Widget _card(Match m) {
    final tA = store.teamById(m.teamAId);
    final tB = store.teamById(m.teamBId);
    final a = tA?.name ?? store.teamName(m.teamAId);
    final b = tB?.name ?? store.teamName(m.teamBId);
    final codeA = tA?.displayCode ??
        (a.length >= 2 ? a.substring(0, 2).toUpperCase() : a.toUpperCase());
    final codeB = tB?.displayCode ??
        (b.length >= 2 ? b.substring(0, 2).toUpperCase() : b.toUpperCase());

    String? aRuns;
    String? aOvers;
    String? bRuns;
    String? bOvers;
    final bpo = m.ballsPerOver > 0 ? m.ballsPerOver : 6;
    for (final inn in m.innings) {
      final runs = '${inn.totalRuns}/${inn.wickets}';
      final ov = '(${inn.legalBalls ~/ bpo}.${inn.legalBalls % bpo})';
      if (inn.battingTeamId == m.teamAId) {
        aRuns = runs;
        aOvers = ov;
      } else {
        bRuns = runs;
        bOvers = ov;
      }
    }

    String header = m.matchTitle.isNotEmpty
        ? m.matchTitle
        : (m.dateIso.isNotEmpty
            ? m.dateIso.split('T').first
            : '${m.oversLimit} Overs Match');
    if (m.tournamentId != null) {
      final t = store.tournamentById(m.tournamentId!);
      if (t != null && t.name.isNotEmpty) header = t.name;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BroadcastMatchCard(
        headerTitle: header,
        teamAName: a,
        teamACode: codeA,
        teamALogo: tA?.logo ?? '',
        teamARuns: aRuns,
        teamAOvers: aOvers,
        teamBName: b,
        teamBCode: codeB,
        teamBLogo: tB?.logo ?? '',
        teamBRuns: bRuns,
        teamBOvers: bOvers,
        isLive: false,
        statusLabel: m.status == 'noResult' ? 'N/R' : 'FT',
        footerText: m.resultText.isNotEmpty ? m.resultText : 'Match Concluded',
        headerTrailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: PitchTheme.slateSubdued,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Delete match',
          onPressed: () => _confirmDelete(m),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScorecardScreen(store: store, match: m),
          ),
        ),
      ),
    );
  }
}
