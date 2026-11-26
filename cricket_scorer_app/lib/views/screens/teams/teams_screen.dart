import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/user_code.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';
import 'package:cricket_scorer_app/services/io/player_io.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/views/screens/teams/profile_screen.dart';
import 'package:cricket_scorer_app/views/widgets/guest_guard.dart';
import 'package:cricket_scorer_app/views/widgets/player_avatar.dart';
import 'package:cricket_scorer_app/core/constants/preset_team_logos.dart';
import 'package:cricket_scorer_app/views/widgets/preset_pickers.dart';

class TeamsScreen extends StatefulWidget {
  final Store store;
  const TeamsScreen({super.key, required this.store});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
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

  Map<String, dynamic> _computeTeamMetricsFor(Team team) {
    int played = 0;
    int won = 0;
    int lost = 0;
    int tied = 0;

    for (final m in store.matches) {
      if (m.teamAId != team.id && m.teamBId != team.id) continue;
      played++;
      if (m.status == 'completed' || (m.innings.length >= 2 && m.innings[1].isComplete)) {
        final res = computeResult(m, store.teamName);
        final lower = res.toLowerCase();
        if (lower.contains('won by') || lower.contains('won the super over')) {
          final teamName = store.teamName(team.id).trim().toLowerCase();
          if (lower.startsWith(teamName)) {
            won++;
          } else {
            lost++;
          }
        } else if (lower.contains('tied') || lower.contains('tie')) {
          tied++;
        }
      }
    }
    final winPct = played > 0 ? ((won / played) * 100).toStringAsFixed(1) : '0.0';
    return {
      'played': played,
      'won': won,
      'lost': lost,
      'tied': tied,
      'winPct': winPct,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editTeam(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: store.teams.length,
        itemBuilder: (context, i) {
          final t = store.teams[i];
          final stats = _computeTeamMetricsFor(t);
          return ListTile(
            leading: PresetTeamLogoBadge(
              logoKey: t.logo,
              teamName: t.name,
              size: 40,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    t.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PitchTheme.outlineVariant, width: 0.8),
                  ),
                  child: Text(
                    t.teamCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: PitchTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${t.players.length} players Â· ${stats['played'] ?? 0} matches (${stats['won'] ?? 0}W - ${stats['lost'] ?? 0}L)',
              style: const TextStyle(fontSize: 12, color: PitchTheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit team',
                  onPressed: () => _editTeam(context, t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete team',
                  onPressed: () async {
                    if (!await requireSignedInAction(context, store,
                        actionLabel: 'delete teams')) {
                      return;
                    }
                    if (!context.mounted) return;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('Delete ${t.name}?'),
                        content: const Text(
                          'This removes the team and its squad.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: kRed,
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.deleteTeam(t.id);
                      if (mounted) setState(() {});
                    }
                  },
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamDetailScreen(store: store, team: t),
              ),
            ).then((_) async {
              // M1: only the team changed â†’ teams-only save. A failed
              // save is shown, not swallowed into a debug print.
              final saved = await store.persistTeamsOnly();
              if (!saved && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Team changes could not be saved.'),
                  ),
                );
              }
            }),
          );
        },
      ),
    );
  }

  Future<void> _editTeam(BuildContext context, Team? existing) async {
    if (!await requireSignedInAction(context, store,
        actionLabel: 'create or edit teams')) {
      return;
    }
    if (!context.mounted) return;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.shortCode ?? '');
    var selectedLogo = existing?.logo ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(existing == null ? 'New Team' : 'Edit Team'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showTeamLogoPicker(
                      context,
                      currentLogoId: selectedLogo,
                    );
                    if (picked != null) {
                      setD(() {
                        selectedLogo = picked.id;
                        if (codeCtrl.text.trim().isEmpty) {
                          codeCtrl.text = picked.defaultCode;
                        }
                      });
                    }
                  },
                  child: Column(
                    children: [
                      PresetTeamLogoBadge(
                        logoKey: selectedLogo,
                        teamName: nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Team',
                        size: 56,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: PitchTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PitchTheme.hairlineBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: PitchTheme.sportsEmerald),
                            SizedBox(width: 4),
                            Text(
                              'Choose Emblem',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PitchTheme.sportsEmerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Team Name',
                    hintText: 'e.g. Lahore Qalandars',
                  ),
                  onChanged: (_) => setD(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Short Code (Abbreviation)',
                    hintText: 'e.g. LQ, NEP, PNG',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final code = codeCtrl.text.trim().toUpperCase();
      if (existing == null) {
        await store.upsertTeam(Team(
          id: Store.newId('team'),
          name: name,
          logo: selectedLogo,
          shortCode: code,
        ));
      } else {
        existing.name = name;
        existing.logo = selectedLogo;
        existing.shortCode = code;
        await store.persistTeamsOnly();
        unawaited(() async {
          try {
            final client = CpanelApiClient();
            await client.init();
            CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
          } catch (_) {}
        }());
      }
    }
  }
}

class TeamDetailScreen extends StatefulWidget {
  final Store store;
  final Team team;
  const TeamDetailScreen({super.key, required this.store, required this.team});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  Team get team => widget.team;
  Store get store => widget.store;

  Map<String, dynamic> _computeTeamMetrics() {
    int played = 0;
    int won = 0;
    int lost = 0;
    int tied = 0;

    for (final m in store.matches) {
      if (m.teamAId != team.id && m.teamBId != team.id) continue;
      played++;
      if (m.status == 'completed' || (m.innings.length >= 2 && m.innings[1].isComplete)) {
        final res = computeResult(m, store.teamName);
        final lower = res.toLowerCase();
        if (lower.contains('won by') || lower.contains('won the super over')) {
          final teamName = store.teamName(team.id).trim().toLowerCase();
          if (lower.startsWith(teamName)) {
            won++;
          } else {
            lost++;
          }
        } else if (lower.contains('tied') || lower.contains('tie')) {
          tied++;
        }
      }
    }
    final winPct = played > 0 ? ((won / played) * 100).toStringAsFixed(1) : '0.0';
    return {
      'played': played,
      'won': won,
      'lost': lost,
      'tied': tied,
      'winPct': winPct,
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _computeTeamMetrics();

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      appBar: AppBar(
        backgroundColor: PitchTheme.surface,
        title: Text(
          team.name,
          style: const TextStyle(fontWeight: FontWeight.w800, color: PitchTheme.onSurface),
        ),
        actions: [
          PlayerListIoButtons(
            exportName: '60score_squad_${team.id}',
            exportRows: () =>
                team.players.map((p) => rowFromPlayer(p, team.name)).toList(),
            onImport: (rows) async {
              for (final r in rows) {
                // Reuse a registered player with the same name when one
                // exists, so ids (and career stats) stay unified.
                final reg = store.regPlayers
                    .where(
                      (x) => x.name.toLowerCase() == r.playerName.toLowerCase(),
                    )
                    .firstOrNull;
                if (reg != null) {
                  if (team.playerById(reg.id) == null) {
                    team.players.add(reg.toTeamPlayer());
                  }
                } else if (!team.players.any(
                  (x) => x.name.toLowerCase() == r.playerName.toLowerCase(),
                )) {
                  team.players.add(r.toTeamPlayer(Store.newId('player')));
                }
              }
              await store.persistTeamsOnly();
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: PitchTheme.onSurface),
            tooltip: 'Rename Team',
            onPressed: () async {
              final ctrl = TextEditingController(text: team.name);
              final name = await showDialog<String>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Rename team'),
                  content: TextField(controller: ctrl),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                setState(() => team.name = name);
                await store.persistTeamsOnly();
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: PitchTheme.error),
            tooltip: 'Delete Team',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('Delete ${team.name}?'),
                  content: const Text('This removes the team and its squad.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: PitchTheme.error),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await store.deleteTeam(team.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PitchTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          if (!await requireSignedInAction(context, store,
              actionLabel: 'add or manage players')) {
            return;
          }
          if (context.mounted) _chooseAddPlayer(context);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add player', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Team Profile Identity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: PitchTheme.primary,
                        foregroundColor: Colors.white,
                        child: Text(
                          team.name.isEmpty ? '?' : team.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: PitchTheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 6),
                            // Shareable Team Code with Copy Action
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: team.teamCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Team Code ${team.teamCode} copied to clipboard!'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: PitchTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: PitchTheme.secondary.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy_rounded, size: 12, color: PitchTheme.secondary),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ID: ${team.teamCode}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: PitchTheme.secondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'TAP TO COPY',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: PitchTheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: PitchTheme.surfaceContainer),
                  const SizedBox(height: 14),
                  // Telemetry Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricTile('MATCHES', '${metrics['played']}', PitchTheme.onSurface),
                      _buildMetricTile('WON', '${metrics['won']}', PitchTheme.secondary),
                      _buildMetricTile('LOST', '${metrics['lost']}', PitchTheme.error),
                      _buildMetricTile('TIED/NR', '${metrics['tied']}', PitchTheme.outline),
                      _buildMetricTile('WIN %', '${metrics['winPct']}%', PitchTheme.onSurface),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Squad Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, size: 20, color: PitchTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'SQUAD ROSTER (${team.players.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: PitchTheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Tap player for profile',
                  style: TextStyle(
                    fontSize: 11,
                    color: PitchTheme.outline.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Squad Roster Cards
            if (team.players.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_add_alt_1_outlined, size: 40, color: PitchTheme.outline.withValues(alpha: 0.6)),
                    const SizedBox(height: 10),
                    const Text(
                      'No players in squad yet',
                      style: TextStyle(fontWeight: FontWeight.w700, color: PitchTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use "+ Add player" below to build your squad lineup.',
                      style: TextStyle(fontSize: 12, color: PitchTheme.outline),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: team.players.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = team.players[i];
                  final tags = [
                    if (p.isCaptain) 'C',
                    if (p.isViceCaptain) 'VC',
                    if (p.isKeeper) 'WK',
                  ].join(' Â· ');
                  final cardPhoto = store.photoForPlayer(p.id);

                  return Material(
                    color: PitchTheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: PlayerAvatar(
                        photoBase64: cardPhoto.isEmpty ? null : cardPhoto,
                        role: p.role,
                        name: p.name,
                        radius: 20,
                        fallbackIcon: Icons.person,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            p.isVerified ? Icons.verified_rounded : Icons.shield_outlined,
                            size: 14,
                            color: p.isVerified ? PitchTheme.secondary : PitchTheme.outline,
                          ),
                          if (p.userCode != null && p.userCode!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: PitchTheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.userCode!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: PitchTheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${p.role} Â· ${p.battingStyle} Â· ${p.bowlingStyle}${tags.isEmpty ? '' : ' Â· $tags'}',
                        style: const TextStyle(fontSize: 12, color: PitchTheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            store: store,
                            playerId: p.id,
                            playerName: p.name,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: PitchTheme.outline,
                            tooltip: 'Edit Player',
                            onPressed: () => _editPlayer(context, p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: PitchTheme.outline,
                            tooltip: 'Remove Player',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (d) => AlertDialog(
                                  title: const Text('Remove player?'),
                                  content: Text(
                                    'Remove ${p.name} from ${team.name}? '
                                    'Their past match figures are not changed.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: PitchTheme.error),
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              setState(() => team.players.removeAt(i));
                              await store.persistTeamsOnly();
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 80), // Fab spacing
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: PitchTheme.outline,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// v1.1.7: Add-player chooser â€” create a new player or pick an existing
  /// registered player into this team.
  void _chooseAddPlayer(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Add New Player'),
              subtitle: const Text('Create a new player profile'),
              onTap: () {
                Navigator.pop(ctx);
                _editPlayer(context, null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Choose Registered Player'),
              subtitle: const Text('Pick from registered players'),
              onTap: () {
                Navigator.pop(ctx);
                _pickRegisteredPlayer(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// v1.1.7: searchable registered-player picker. Adds the selected player
  /// to the current team using the same shared record/ID (no duplicates).
  void _pickRegisteredPlayer(BuildContext context) {
    final store = widget.store;
    final team = widget.team;
    var query = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = query.trim().toLowerCase();
          final cleanQ = q.replaceAll('-', '').replaceAll(' ', '');
          final list = store.regPlayers.where((r) {
            if (q.isEmpty) return true;
            final name = r.name.toLowerCase();
            final id = r.id.toLowerCase();
            final code = userCodeForUid(r.id).toLowerCase();
            final cleanCode = code.replaceAll('-', '').replaceAll(' ', '');
            return name.contains(q) ||
                id.contains(q) ||
                code.contains(q) ||
                cleanCode.contains(cleanQ) ||
                (r.jerseyNo > 0 && '${r.jerseyNo}'.contains(q));
          }).toList();
          return AlertDialog(
            title: const Text('Choose Registered Player'),
            content: SizedBox(
              width: double.maxFinite,
              height: (MediaQuery.sizeOf(ctx).height * 0.5).clamp(260.0, 480.0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search name or shirt number',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child:
                                Text('No registered players found.'),
                          )
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final r = list[i];
                              final already = team.players
                                  .any((p) => p.id == r.id);
                              return ListTile(
                                leading: PlayerAvatar(
                                  photoBase64: r.photoBase64.isEmpty
                                      ? null
                                      : r.photoBase64,
                                  role: r.role,
                                  name: r.name,
                                  radius: 20,
                                  fallbackIcon: Icons.person,
                                ),
                                title: Text(r.name),
                                subtitle: Text(
                                  '${r.role}${r.jerseyNo > 0 ? ' Â· #${r.jerseyNo}' : ''}',
                                ),
                                trailing: already
                                    ? const Icon(Icons.check,
                                        color: Colors.green)
                                    : null,
                                onTap: () async {
                                  if (already) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Player is already in this team.'),
                                      ),
                                    );
                                    return;
                                  }
                                  team.players.add(r.toTeamPlayer());
                                  await store.persistTeamsOnly();
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    setState(() {});
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Player added successfully.'),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editPlayer(BuildContext context, Player? existing) async {
    final p =
        existing ?? Player(id: Store.newId('player'), name: '', jerseyNo: 0);
    final nameCtrl = TextEditingController(text: p.name);
    final jerseyCtrl = TextEditingController(
      text: p.jerseyNo > 0 ? '${p.jerseyNo}' : '',
    );
    var role = p.role;
    var bat = p.battingStyle;
    var bowl = p.bowlingStyle;
    var cap = p.isCaptain;
    var vc = p.isViceCaptain;
    var wk = p.isKeeper;
    // v1.1.6: photo management through Team Management â€” Add / Change /
    // Remove Image, saved on the shared player record (see save below).
    var photoBase64 = p.photoBase64;
    const roles = ['Batter', 'Bowler', 'All-Rounder', 'Wicket-Keeper'];
    const bats = ['Right-hand', 'Left-hand'];
    const bowls = [
      'None',
      'Right-arm fast',
      'Right-arm medium',
      'Right-arm spin',
      'Left-arm fast',
      'Left-arm medium',
      'Left-arm spin',
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(existing == null ? 'Add player' : 'Edit player'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // v1.1.6: photo picker (same gallery flow as player
                // registration). Tap avatar to Add/Change; Remove Image
                // clears the photo on the shared record.
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 75,
                    );
                    if (img != null) {
                      final bytes = await img.readAsBytes();
                      setD(() {
                        photoBase64 = base64Encode(bytes);
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PlayerAvatar(
                        photoBase64:
                            photoBase64.isEmpty ? null : photoBase64,
                        role: role,
                        name: nameCtrl.text,
                        radius: 40,
                        fallbackIcon: Icons.person,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: kCyan,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final avatar = await showPlayerAvatarPicker(
                          context,
                          currentAvatarId: photoBase64,
                        );
                        if (avatar != null) {
                          setD(() => photoBase64 = avatar.id);
                        }
                      },
                      icon: const Icon(Icons.face, size: 18),
                      label: const Text('Preset Avatar'),
                    ),
                    if (photoBase64.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => setD(() => photoBase64 = ''),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: jerseyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jersey no.'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setD(() => role = v ?? role),
                ),
                DropdownButtonFormField<String>(
                  initialValue: bat,
                  decoration: const InputDecoration(labelText: 'Batting style'),
                  items: bats
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setD(() => bat = v ?? bat),
                ),
                DropdownButtonFormField<String>(
                  initialValue: bowl,
                  decoration: const InputDecoration(labelText: 'Bowling style'),
                  items: bowls
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setD(() => bowl = v ?? bowl),
                ),
                CheckboxListTile(
                  value: cap,
                  title: const Text('Captain'),
                  onChanged: (v) => setD(() => cap = v ?? false),
                ),
                CheckboxListTile(
                  value: vc,
                  title: const Text('Vice-captain'),
                  onChanged: (v) => setD(() => vc = v ?? false),
                ),
                CheckboxListTile(
                  value: wk,
                  title: const Text('Wicket-keeper'),
                  onChanged: (v) => setD(() => wk = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      p.name = nameCtrl.text.trim();
      p.jerseyNo = int.tryParse(jerseyCtrl.text) ?? 0;
      p.role = role;
      p.battingStyle = bat;
      p.bowlingStyle = bowl;
      // v1.1.6: photo lives on the shared player record â€” when this team
      // player links to a registered player (same ID), update the
      // canonical record too so every screen shows the same photo.
      p.photoBase64 = photoBase64;
      final reg = store.regById(p.id);
      if (reg != null) {
        reg.photoBase64 = photoBase64;
        await store.upsertRegPlayer(reg);
      }
      // only one captain / vice-captain / keeper flag set per team
      if (cap) {
        for (final x in team.players) {
          x.isCaptain = false;
        }
      }
      if (vc) {
        for (final x in team.players) {
          x.isViceCaptain = false;
        }
      }
      p.isCaptain = cap;
      p.isViceCaptain = vc;
      p.isKeeper = wk;
      if (existing == null) team.players.add(p);
      setState(() {});
      await store.persistTeamsOnly();
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
    }
  }
}
