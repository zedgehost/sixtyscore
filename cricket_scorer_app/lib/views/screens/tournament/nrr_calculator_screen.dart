import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
// NRR Possibilities Calculator screen (Feature 3, D batch).
//
// Manual what-if tool over the CURRENT league points table: pick a
// tournament, your team and the rival it must overtake, choose
// "defend a total" or "chase a target", enter the numbers, and read
// the exact margin / latest chase ball needed. Nothing here writes
// to the store — fixtures, matches and the table are never modified.
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/nrr/nrr_calculator.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';
import 'package:cricket_scorer_app/views/screens/tournament/qualification_chances_screen.dart';

class NrrCalculatorScreen extends StatefulWidget {
  final Store store;
  final String? initialTournamentId;
  const NrrCalculatorScreen({
    super.key,
    required this.store,
    this.initialTournamentId,
  });

  @override
  State<NrrCalculatorScreen> createState() => _NrrCalculatorScreenState();
}

class _NrrCalculatorScreenState extends State<NrrCalculatorScreen> {
  Store get store => widget.store;

  String? _tournamentId;
  String? _teamId;
  String? _rivalId;
  int _mode = 0; // 0 = defend a total, 1 = chase a target
  bool _teamAllOut = false;
  bool _oppAllOut = false;

  final _quotaCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _teamBallsCtrl = TextEditingController();
  final _oppBallsCtrl = TextEditingController();

  NrrScenarioResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    Tournament? t;
    if (widget.initialTournamentId != null) {
      final matches = store.tournaments.where((x) => x.id == widget.initialTournamentId);
      if (matches.isNotEmpty) t = matches.first;
    }
    t ??= store.tournaments.isNotEmpty ? store.tournaments.first : null;
    if (t != null) {
      _tournamentId = t.id;
      _quotaCtrl.text = '${t.oversLimit}';
      _oppBallsCtrl.text = '${t.oversLimit}';
    }
    store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    _quotaCtrl.dispose();
    _scoreCtrl.dispose();
    _teamBallsCtrl.dispose();
    _oppBallsCtrl.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Tournament? get _tournament {
    for (final t in store.tournaments) {
      if (t.id == _tournamentId) return t;
    }
    return store.tournaments.isEmpty ? null : store.tournaments.first;
  }

  /// Balls per over for this tournament (from any of its matches).
  int get _ballsPerOver {
    final t = _tournament;
    if (t == null) return 6;
    for (final m in store.matches) {
      if (m.tournamentId == t.id) return m.ballsPerOver;
    }
    return 6;
  }

  List<PointsRow> get _rows {
    final t = _tournament;
    if (t == null) return const [];
    return leaguePointsTable(t, store.matches);
  }

  PointsRow? _rowOf(List<PointsRow> rows, String? id) {
    for (final r in rows) {
      if (r.teamId == id) return r;
    }
    return null;
  }

  void _pickTournament(String? id) {
    setState(() {
      _tournamentId = id;
      _teamId = null;
      _rivalId = null;
      _result = null;
      _error = null;
      final t = _tournament;
      if (t != null) {
        _quotaCtrl.text = '${t.oversLimit}';
        _oppBallsCtrl.text = '${t.oversLimit}';
      }
    });
  }

  void _compute() {
    final t = _tournament;
    final rows = _rows;
    final team = _rowOf(rows, _teamId);
    final rival = _rowOf(rows, _rivalId);
    setState(() {
      _result = null;
      _error = null;
      if (t == null || team == null || rival == null) {
        _error = 'Please select a tournament, team, and rival.';
        return;
      }
      if (team.teamId == rival.teamId) {
        _error = 'Team and rival must be different.';
        return;
      }
      final bpo = _ballsPerOver;
      final quota = ballsFromOversText(_quotaCtrl.text, bpo);
      if (quota == null || quota <= 0) {
        _error = 'Enter a valid overs quota (e.g. 20 or 19.3).';
        return;
      }
      final score = int.tryParse(_scoreCtrl.text.trim());
      if (score == null || score <= 0) {
        _error = _mode == 0
            ? 'Enter your team\'s score.'
            : 'Enter the opponent\'s score.';
        return;
      }
      if (_mode == 0) {
        int? ballsFaced;
        if (_teamBallsCtrl.text.trim().isNotEmpty) {
          ballsFaced = ballsFromOversText(_teamBallsCtrl.text, bpo);
          if (ballsFaced == null || ballsFaced <= 0 || ballsFaced > quota) {
            _error = 'Enter valid balls faced (e.g. 19.2).';
            return;
          }
        }
        _result = runsMarginNeeded(
          team: team,
          rival: rival,
          teamScore: score,
          oversQuotaBalls: quota,
          ballsPerOver: bpo,
          ballsFacedTeam: ballsFaced,
          teamAllOut: _teamAllOut,
        );
      } else {
        var oppBalls = quota;
        if (_oppBallsCtrl.text.trim().isNotEmpty) {
          final parsed = ballsFromOversText(_oppBallsCtrl.text, bpo);
          if (parsed == null || parsed <= 0 || parsed > quota) {
            _error = 'Enter valid balls faced for the opponent.';
            return;
          }
          oppBalls = parsed;
        }
        _result = chaseLatestBalls(
          team: team,
          rival: rival,
          target: score + 1,
          oversQuotaBalls: quota,
          ballsPerOver: bpo,
          oppScore: score,
          oppBallsFaced: oppBalls,
          oppAllOut: _oppAllOut,
        );
      }
    });
  }

  String _nrrText(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(3)}';

  Widget _resultCard(List<PointsRow> rows) {
    final team = _rowOf(rows, _teamId);
    final rival = _rowOf(rows, _rivalId);
    if (_error != null) {
      return ScoreCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: kRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: PitchTheme.onSurface, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    final res = _result;
    if (res == null || team == null || rival == null) {
      return const ScoreCard(
        child: Text(
          'Select team, rival, and score then tap "Calculate" to view results.',
          style: TextStyle(color: PitchTheme.outline, fontSize: 13),
        ),
      );
    }
    final teamName = store.teamName(team.teamId);
    final rivalName = store.teamName(rival.teamId);
    final String headline;
    if (!res.possible) {
      headline = '$teamName cannot overtake $rivalName in this scenario.';
    } else if (_mode == 0) {
      headline = res.minMargin == 1
          ? 'Any win is enough for $teamName — must restrict opponent to ${res.maxOpponentRuns} runs.'
          : '$teamName must win by at least ${res.minMargin} runs — restricting opponent to ${res.maxOpponentRuns} runs.';
    } else {
      final balls = res.latestChaseBalls!;
      final bpo = _ballsPerOver;
      final overNo = (balls - 1) ~/ bpo + 1;
      final ballNo = (balls - 1) % bpo + 1;
      headline = '$teamName must complete the chase within ${oversText(balls, bpo)} overs (over $overNo, ball $ballNo).';
    }
    return ScoreCard(
      highlight: res.possible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                res.possible ? Icons.check_circle : Icons.cancel,
                color: res.possible ? kGreen : kRed,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            res.verdict,
            style: const TextStyle(color: PitchTheme.outline, fontSize: 13),
          ),
          if (res.resultingNrr != null) ...[
            const SizedBox(height: 8),
            Text(
              'In this scenario, $teamName will have an NRR of ${_nrrText(res.resultingNrr!)} '
              'vs $rivalName\'s current NRR of ${_nrrText(rival.nrr)} '
              '(${rival.points} pts).',
              style: const TextStyle(color: PitchTheme.outline, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamDropdown({
    required String label,
    required String? value,
    required List<String> teamIds,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      dropdownColor: PitchTheme.surfaceContainerLowest,
      items: [
        for (final id in teamIds)
          DropdownMenuItem(
            value: id,
            child: Text(
              store.teamName(id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tournament;
    final rows = _rows;
    final teamIds = t?.teamIds ?? const <String>[];
    // Sensible defaults: first team in the tournament vs the next one.
    if (_teamId == null || !teamIds.contains(_teamId)) {
      _teamId = teamIds.isNotEmpty ? teamIds.first : null;
    }
    if (_rivalId == null || !teamIds.contains(_rivalId)) {
      _rivalId = teamIds.length > 1 ? teamIds[1] : null;
    }
    final team = _rowOf(rows, _teamId);
    final rival = _rowOf(rows, _rivalId);

    return Scaffold(
      appBar: AppBar(title: const Text('NRR Calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          const Text(
            'Calculate what your team needs to overtake a rival on Net Run Rate (NRR) '
            'based on current standings. This simulation does not modify actual tables or matches.',
            style: TextStyle(color: PitchTheme.outline, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          ScoreButton(
            label: 'Qualification chances (all teams)',
            icon: Icons.analytics_outlined,
            kind: ScoreButtonKind.ghost,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QualificationChancesScreen(store: store),
              ),
            ),
          ),
          const SectionHeader('Tournament & Teams'),
          DropdownButtonFormField<String>(
            initialValue: t?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tournament'),
            dropdownColor: PitchTheme.surfaceContainerLowest,
            items: [
              for (final tr in store.tournaments)
                DropdownMenuItem(
                  value: tr.id,
                  child: Text(
                    tr.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _pickTournament,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _teamDropdown(
                  label: 'Your Team',
                  value: _teamId,
                  teamIds: teamIds,
                  onChanged: (v) => setState(() {
                    _teamId = v;
                    _result = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _teamDropdown(
                  label: 'Rival (to overtake)',
                  value: _rivalId,
                  teamIds: teamIds,
                  onChanged: (v) => setState(() {
                    _rivalId = v;
                    _result = null;
                  }),
                ),
              ),
            ],
          ),
          if (team != null && rival != null) ...[
            const SizedBox(height: 8),
            Text(
              '${store.teamName(team.teamId)}: ${team.points} pts, '
              'NRR ${_nrrText(team.nrr)}   •   '
              '${store.teamName(rival.teamId)}: ${rival.points} pts, '
              'NRR ${_nrrText(rival.nrr)}',
              style: const TextStyle(color: PitchTheme.outline, fontSize: 12),
            ),
          ],
          const SectionHeader('Scenario'),
          Row(
            children: [
              Expanded(
                child: OptionCard(
                  title: 'Defend a Total',
                  icon: Icons.shield,
                  selected: _mode == 0,
                  onTap: () => setState(() {
                    _mode = 0;
                    _result = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OptionCard(
                  title: 'Chase a Target',
                  icon: Icons.gps_fixed,
                  selected: _mode == 1,
                  onTap: () => setState(() {
                    _mode = 1;
                    _result = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quotaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    // Short label + hint (owner UI rule
                    // 2026-10-24): half-width fields at 360dp
                    // cannot fit the long label inside the box.
                    labelText: 'Overs per innings',
                    hintText: 'e.g. 8 or 7.3',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _scoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        _mode == 0 ? 'Your team score' : 'Opponent score',
                    hintText: _mode == 1 ? 'target = score + 1' : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_mode == 0) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _teamBallsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Overs faced (optional)',
                      hintText: 'e.g. 6.2',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'All out',
                      style: TextStyle(color: PitchTheme.onSurface, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Full quota counted',
                      style: TextStyle(color: PitchTheme.outline, fontSize: 11),
                    ),
                    value: _teamAllOut,
                    onChanged: (v) => setState(() => _teamAllOut = v),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _oppBallsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Opponent overs faced',
                      hintText: 'e.g. 8.0',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Opponent all out',
                      style: TextStyle(color: PitchTheme.onSurface, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Full quota counted',
                      style: TextStyle(color: PitchTheme.outline, fontSize: 11),
                    ),
                    value: _oppAllOut,
                    onChanged: (v) => setState(() => _oppAllOut = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          GoldButton(
            label: 'Calculate',
            icon: Icons.calculate,
            onPressed: t == null ? null : _compute,
          ),
          const SectionHeader('Result'),
          _resultCard(rows),
        ],
      ),
    );
  }
}
