import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';

class MatchLineupsScreen extends StatefulWidget {
  final Store store;
  final MatchDraft draft;

  const MatchLineupsScreen({
    super.key,
    required this.store,
    required this.draft,
  });

  @override
  State<MatchLineupsScreen> createState() => _MatchLineupsScreenState();
}

class _MatchLineupsScreenState extends State<MatchLineupsScreen> {
  int _selectedTeamTab = 0; // 0 = Team A, 1 = Team B
  late Set<String> _xiA;
  late Set<String> _xiB;
  bool _starting = false;

  Store get store => widget.store;
  MatchDraft get draft => widget.draft;

  /// Dynamic squad size needed based on match wickets rule
  int get targetCount {
    if (draft.totalWickets > 0 && draft.totalWickets < 10) {
      return draft.lastManStands ? draft.totalWickets : draft.totalWickets + 1;
    }
    return 11;
  }

  @override
  void initState() {
    super.initState();
    final teamA = store.teamById(draft.teamAId);
    final teamB = store.teamById(draft.teamBId);

    _xiA = Set.from(draft.xiA);
    if (_xiA.isEmpty && teamA != null) {
      _xiA.addAll(teamA.players.take(targetCount).map((p) => p.id));
    }

    _xiB = Set.from(draft.xiB);
    if (_xiB.isEmpty && teamB != null) {
      _xiB.addAll(teamB.players.take(targetCount).map((p) => p.id));
    }
  }

  void _onTogglePlayer(String playerId, bool isTeamA) {
    setState(() {
      final xi = isTeamA ? _xiA : _xiB;
      if (xi.contains(playerId)) {
        xi.remove(playerId);
      } else {
        if (xi.length < targetCount) {
          xi.add(playerId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Target of $targetCount players already reached.'),
              duration: const Duration(milliseconds: 1500),
              backgroundColor: PitchTheme.primaryContainer,
            ),
          );
        }
      }
    });
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'P';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _getTag(Player p) {
    if (p.isKeeper) {
      return p.battingStyle.toLowerCase().contains('left')
          ? 'WK • LHB'
          : 'WK • RHB';
    }
    final bat = p.battingStyle.toLowerCase().contains('left') ? 'LHB' : 'RHB';
    final bowl = p.bowlingStyle.toLowerCase();
    if (bowl.contains('fast')) return '$bat • FAST';
    if (bowl.contains('spin') || bowl.contains('break')) return '$bat • SPIN';
    if (bowl.contains('med')) return '$bat • MED';
    return bat;
  }

  String _getStatsText(Player p) {
    if (p.role.toLowerCase().contains('batter')) {
      return 'Avg: 38.4 • SR: 142';
    } else if (p.role.toLowerCase().contains('all')) {
      return '14 Wkts • SR: 131';
    } else if (p.role.toLowerCase().contains('keeper')) {
      return '18 Catches • 4 Stumps';
    } else {
      return 'Econ: 6.8 • BB: 4/18';
    }
  }

  Future<void> _continueToOpeners() async {
    if (_starting) return;

    if (_xiA.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least 2 players for ${store.teamById(draft.teamAId)?.name ?? 'Team A'}.',
          ),
          backgroundColor: PitchTheme.error,
        ),
      );
      return;
    }

    if (_xiB.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least 2 players for ${store.teamById(draft.teamBId)?.name ?? 'Team B'}.',
          ),
          backgroundColor: PitchTheme.error,
        ),
      );
      return;
    }

    setState(() => _starting = true);
    try {
      draft.xiA = _xiA.toList();
      draft.xiB = _xiB.toList();

      final m = draft.toMatch();
      await store.upsertMatch(m);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ScoringScreen(store: store, match: m),
        ),
        (route) => route.isFirst,
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Add Player Bottom Sheet Modal
  // ---------------------------------------------------------------------------
  void _openAddPlayerModal(Team team, bool isTeamA) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: PitchTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.group_add,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Player to Lineup',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: PitchTheme.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: PitchTheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Search Player by ID
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showSearchPlayerDialog(team, isTeamA);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PitchTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: PitchTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Search Player by ID',
                              style: TextStyle(
                                color: PitchTheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Find an existing player from your database',
                              style: TextStyle(
                                color: PitchTheme.outline,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: PitchTheme.outline,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: New Quick Player
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showQuickCreatePlayerDialog(team, isTeamA);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PitchTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: PitchTheme.secondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'New Quick Player',
                              style: TextStyle(
                                color: PitchTheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Create on-the-fly with name, role & style',
                              style: TextStyle(
                                color: PitchTheme.outline,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: PitchTheme.outline,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Modal Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${team.name} roster',
                    style: const TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Need $targetCount starters',
                    style: const TextStyle(
                      color: PitchTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Create New Quick Player
  // ---------------------------------------------------------------------------
  void _showQuickCreatePlayerDialog(Team team, bool isTeamA) {
    final nameCtrl = TextEditingController();
    String role = 'Batter';
    String battingStyle = 'Right-hand';
    String bowlingStyle = 'Right-arm fast';
    bool isCaptain = false;
    bool isKeeper = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              backgroundColor: PitchTheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'New Player • ${team.name}',
                style: const TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Player Full Name',
                        hintText: 'e.g. Babar Azam',
                        filled: true,
                        fillColor: PitchTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: InputDecoration(
                        labelText: 'Primary Role',
                        filled: true,
                        fillColor: PitchTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Batter',
                          child: Text('Batter'),
                        ),
                        DropdownMenuItem(
                          value: 'Bowler',
                          child: Text('Bowler'),
                        ),
                        DropdownMenuItem(
                          value: 'All-Rounder',
                          child: Text('All-Rounder'),
                        ),
                        DropdownMenuItem(
                          value: 'Wicket-Keeper',
                          child: Text('Wicket-Keeper'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDState(() {
                            role = v;
                            if (role == 'Wicket-Keeper') isKeeper = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: battingStyle,
                            decoration: InputDecoration(
                              labelText: 'Batting Hand',
                              filled: true,
                              fillColor: PitchTheme.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Right-hand',
                                child: Text('Right-hand'),
                              ),
                              DropdownMenuItem(
                                value: 'Left-hand',
                                child: Text('Left-hand'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setDState(() => battingStyle = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: isCaptain,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Team Captain (C)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      activeColor: PitchTheme.primary,
                      onChanged: (v) =>
                          setDState(() => isCaptain = v ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    final newPlayer = Player(
                      id: Store.newId('player'),
                      name: name,
                      role: role,
                      battingStyle: battingStyle,
                      bowlingStyle: bowlingStyle,
                      isCaptain: isCaptain,
                      isKeeper: isKeeper,
                    );

                    team.players.add(newPlayer);
                    await store.upsertTeam(team);

                    setState(() {
                      final xi = isTeamA ? _xiA : _xiB;
                      if (xi.length < targetCount) {
                        xi.add(newPlayer.id);
                      }
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PitchTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Create & Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Search Player by ID / Database
  // ---------------------------------------------------------------------------
  void _showSearchPlayerDialog(Team team, bool isTeamA) {
    final searchCtrl = TextEditingController();
    final List<Player> pool = [];
    for (final t in store.teams) {
      for (final p in t.players) {
        if (!team.players.any((tp) => tp.id == p.id) &&
            !pool.any((x) => x.id == p.id)) {
          pool.add(p);
        }
      }
    }
    for (final r in store.regPlayers) {
      if (!team.players.any((tp) => tp.id == r.id) &&
          !pool.any((x) => x.id == r.id)) {
        pool.add(r.toTeamPlayer());
      }
    }

    List<Player> filtered = List.from(pool);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              backgroundColor: PitchTheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Search Player Database',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: (MediaQuery.sizeOf(context).height * 0.45).clamp(240.0, 420.0),
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'Search by name or code...',
                        filled: true,
                        fillColor: PitchTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setDState(() {
                          final query = val.toLowerCase().trim();
                          if (query.isEmpty) {
                            filtered = List.from(pool);
                          } else {
                            filtered = pool.where((p) {
                              return p.name.toLowerCase().contains(query) ||
                                  p.id.toLowerCase().contains(query);
                            }).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching players found in database.',
                                style: TextStyle(
                                  color: PitchTheme.outline,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final p = filtered[idx];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        PitchTheme.surfaceContainerLow,
                                    child: Text(
                                      _getInitials(p.name),
                                      style: const TextStyle(
                                        color: PitchTheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${p.role} • ${p.battingStyle}',
                                    style: const TextStyle(
                                      color: PitchTheme.outline,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: PitchTheme.secondary,
                                    ),
                                    onPressed: () async {
                                      team.players.add(p);
                                      await store.upsertTeam(team);

                                      setState(() {
                                        final xi = isTeamA ? _xiA : _xiB;
                                        if (xi.length < targetCount) {
                                          xi.add(p.id);
                                        }
                                      });

                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamA = store.teamById(draft.teamAId);
    final teamB = store.teamById(draft.teamBId);

    final currentTeam = _selectedTeamTab == 0 ? teamA : teamB;
    final currentXi = _selectedTeamTab == 0 ? _xiA : _xiB;
    final isTeamA = _selectedTeamTab == 0;
    final currentTarget = targetCount;

    final isTargetReached = currentXi.length >= currentTarget;
    final availablePlayers = currentTeam?.players ?? <Player>[];

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // Top Sub-Header & Wizard Progress (STEP 4 OF 4)
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: PitchTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: PitchTheme.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: PitchTheme.onSurface,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Match Lineups',
                            style: TextStyle(
                              color: PitchTheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PitchTheme.primaryContainer
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: PitchTheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'STEP 4 OF 4',
                              style: TextStyle(
                                color: PitchTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 48),
                    child: Text(
                      'Confirm your squad playing XI or minimal tournament rosters.',
                      style: TextStyle(
                        color: PitchTheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // Team Selection Segmented Tabs
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Team A Tab
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTeamTab = 0),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedTeamTab == 0
                                ? PitchTheme.surfaceContainerLowest
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTeamTab == 0
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _selectedTeamTab == 0
                                      ? PitchTheme.secondary
                                      : PitchTheme.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  teamA?.name ?? 'Team A',
                                  style: TextStyle(
                                    color: _selectedTeamTab == 0
                                        ? PitchTheme.onSurface
                                        : PitchTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTeamTab == 0
                                      ? PitchTheme.secondaryContainer
                                      : PitchTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_xiA.length}/$currentTarget',
                                  style: TextStyle(
                                    color: _selectedTeamTab == 0
                                        ? PitchTheme.onSecondaryContainer
                                        : PitchTheme.onSurfaceVariant,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Team B Tab
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTeamTab = 1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedTeamTab == 1
                                ? PitchTheme.surfaceContainerLowest
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTeamTab == 1
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _selectedTeamTab == 1
                                      ? PitchTheme.secondary
                                      : PitchTheme.outlineVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  teamB?.name ?? 'Team B',
                                  style: TextStyle(
                                    color: _selectedTeamTab == 1
                                        ? PitchTheme.onSurface
                                        : PitchTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTeamTab == 1
                                      ? PitchTheme.secondaryContainer
                                      : PitchTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_xiB.length}/$currentTarget',
                                  style: TextStyle(
                                    color: _selectedTeamTab == 1
                                        ? PitchTheme.onSecondaryContainer
                                        : PitchTheme.onSurfaceVariant,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // Quota Status Banner
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: isTargetReached
                              ? PitchTheme.secondary
                              : PitchTheme.outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTargetReached
                              ? '${currentTeam?.name ?? 'Team'} squad target reached'
                              : 'Select ${math.max(0, currentTarget - currentXi.length)} more players',
                          style: const TextStyle(
                            color: PitchTheme.onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${currentXi.length} of $currentTarget',
                      style: TextStyle(
                        color: isTargetReached
                            ? PitchTheme.secondary
                            : PitchTheme.outline,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // Add Player to Squad Quick Button
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                onTap: currentTeam == null
                    ? null
                    : () => _openAddPlayerModal(currentTeam, isTeamA),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PitchTheme.surfaceContainerLow,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: PitchTheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ADD PLAYER TO SQUAD',
                        style: TextStyle(
                          color: PitchTheme.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // Player Pool Header & List
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AVAILABLE POOL • ${availablePlayers.length} PLAYERS',
                    style: const TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    'SELECTED (${currentXi.length})',
                    style: const TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: availablePlayers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              size: 46,
                              color: PitchTheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No players registered in ${currentTeam?.name ?? 'team'} yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: PitchTheme.outline,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: currentTeam == null
                                  ? null
                                  : () => _openAddPlayerModal(
                                      currentTeam, isTeamA),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Player Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PitchTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      itemCount: availablePlayers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = availablePlayers[index];
                        final isSelected = currentXi.contains(p.id);
                        final initials = _getInitials(p.name);
                        final tag = _getTag(p);
                        final statsText = _getStatsText(p);

                        return InkWell(
                          onTap: () => _onTogglePlayer(p.id, isTeamA),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? PitchTheme.secondaryContainer
                                      .withValues(alpha: 0.25)
                                  : PitchTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? PitchTheme.secondaryContainer
                                    : PitchTheme.surfaceContainerLow,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar circle with optional captain badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (p.isCaptain
                                                ? PitchTheme.primary
                                                : PitchTheme.surfaceContainerHigh)
                                            : PitchTheme.surfaceContainerLow,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: TextStyle(
                                            color: isSelected
                                                ? (p.isCaptain
                                                    ? Colors.white
                                                    : PitchTheme.primary)
                                                : PitchTheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (p.isCaptain)
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: const BoxDecoration(
                                            color: PitchTheme.tertiaryFixed,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'C',
                                              style: TextStyle(
                                                color: PitchTheme.tertiary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Player details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.name,
                                              style: const TextStyle(
                                                color: PitchTheme.onSurface,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: PitchTheme
                                                  .surfaceContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tag,
                                              style: const TextStyle(
                                                color: PitchTheme
                                                    .onSurfaceVariant,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            p.role,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? PitchTheme.secondary
                                                  : PitchTheme.onSurfaceVariant,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Container(
                                            width: 3.5,
                                            height: 3.5,
                                            decoration: const BoxDecoration(
                                              color: PitchTheme.outlineVariant,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              statsText,
                                              style: const TextStyle(
                                                color: PitchTheme
                                                    .onSurfaceVariant,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkbox Circle
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? PitchTheme.secondary
                                        : PitchTheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // -----------------------------------------------------------------
            // Sticky Bottom CTA (CONTINUE TO OPENERS ➔)
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLowest.withValues(alpha: 0.95),
                border: const Border(
                  top: BorderSide(
                    color: PitchTheme.surfaceContainerLow,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _starting ? null : _continueToOpeners,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PitchTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _starting
                              ? 'PREPARING MATCH...'
                              : 'CONTINUE TO OPENERS',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: PitchTheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Select exactly $currentTarget players per team to proceed',
                        style: const TextStyle(
                          color: PitchTheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
