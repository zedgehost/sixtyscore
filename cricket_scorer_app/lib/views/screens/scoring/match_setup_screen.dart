import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/views/screens/scoring/match_toss_screen.dart';

/// Dotted circle painter for the team selection placeholders
class DottedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  const DottedCirclePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashWidth = 5.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    final totalDash = dashWidth + dashSpace;
    final dashCount = (circumference / totalDash).floor();
    final adjustedDashSpace =
        (circumference - (dashCount * dashWidth)) / dashCount;
    final dashAngle = (dashWidth / circumference) * 2 * math.pi;
    final spaceAngle = (adjustedDashSpace / circumference) * 2 * math.pi;

    double currentAngle = 0;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        dashAngle,
        false,
        paint,
      );
      currentAngle += dashAngle + spaceAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DottedCirclePainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashWidth != oldDelegate.dashWidth ||
      dashSpace != oldDelegate.dashSpace;
}

class MatchSetupScreen extends StatefulWidget {
  final Store store;
  final String? tournamentId;

  /// When set, the setup edits this existing fixture in place instead of
  /// creating a brand-new match.
  final Match? existingMatch;

  const MatchSetupScreen({
    super.key,
    required this.store,
    this.tournamentId,
    this.existingMatch,
  });

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  String? teamAId;
  String? teamBId;
  String? tournamentId;
  final Set<String> xiA = {};
  final Set<String> xiB = {};

  int overs = 20; // Default 20 overs as in Stitch design
  String matchType = 'T20'; // Default match type
  String stage = 'league'; // Default match stage (league, qualifier1, eliminator, qualifier2, semifinal1, semifinal2, final, friendly)
  int totalWickets = 10; // Default 10 wickets as in Stitch design
  bool lastManStands = false;
  bool widePenalty = true;
  bool noBallPenalty = true;
  int ballsPerOver = 6;

  final venueCtrl =
      TextEditingController(text: 'Islamabad Club Cricket Pavilion');
  final titleCtrl = TextEditingController();
  final seasonCtrl = TextEditingController();
  String ballType = 'Tennis'; // Default Tennis as in Stitch design
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();

  String? tossWinnerId;
  String tossDecision = 'bat';

  bool _showAdvancedRules = false;

  Store get store => widget.store;

  bool get isTournamentMatch =>
      tournamentId != null && tournamentId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AuthService().isRestrictedGuest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest mode is view-only. Sign in with Google to create matches.'),
            backgroundColor: PitchTheme.primary,
          ),
        );
        Navigator.pop(context);
      }
    });
    tournamentId = widget.tournamentId;

    // Pre-fill from existing match fixture if editing
    final em = widget.existingMatch;
    if (em != null) {
      tournamentId = em.tournamentId ?? tournamentId;
      if (em.teamAId.isNotEmpty && store.teamById(em.teamAId) != null) {
        teamAId = em.teamAId;
      }
      if (em.teamBId.isNotEmpty && store.teamById(em.teamBId) != null) {
        teamBId = em.teamBId;
      }
      overs = em.oversLimit;
      _syncMatchTypeFromOvers(overs);
      ballsPerOver = em.ballsPerOver;
      venueCtrl.text = em.venue;
      titleCtrl.text = em.matchTitle;
      seasonCtrl.text = em.season;
      stage = em.stage.isNotEmpty
          ? em.stage
          : (isTournamentMatch ? 'league' : 'friendly');
      ballType = em.ballType.isNotEmpty ? em.ballType : 'Tennis';
      totalWickets = em.totalWickets > 0 ? em.totalWickets : 10;
      widePenalty = em.widePenalty;
      noBallPenalty = em.noBallPenalty;
      lastManStands = em.lastManStands;

      final parsed = DateTime.tryParse(em.dateIso);
      if (parsed != null) {
        date = parsed;
        time = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
      _preselect();
      if (em.xiA.isNotEmpty) {
        xiA.clear();
        xiA.addAll(em.xiA.take(11));
      }
      if (em.xiB.isNotEmpty) {
        xiB.clear();
        xiB.addAll(em.xiB.take(11));
      }
    } else if (tournamentId != null && tournamentId!.trim().isNotEmpty) {
      stage = 'league';
      final t = store.tournamentById(tournamentId);
      final uid = store.effectiveUserId;
      final isOwner = !AuthService().isRestrictedGuest && (t != null && (t.creatorId.isNotEmpty ? (uid.isNotEmpty && t.creatorId == uid) : true));
      if (!isOwner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the tournament creator can create fixtures for this tournament.')));
            Navigator.pop(context);
          }
        });
      }
      if (t != null) {
        overs = t.oversLimit;
        _syncMatchTypeFromOvers(overs);
        if (t.teamIds.length >= 2) {
          teamAId = t.teamIds[0];
          teamBId = t.teamIds[1];
          _preselect();
        }
      }
    } else {
      stage = 'friendly';
      // Fresh match: if teams exist, we can pre-select or let user select
      if (store.teams.length >= 2) {
        teamAId = store.teams[0].id;
        teamBId = store.teams[1].id;
        _preselect();
      }
    }
  }

  @override
  void dispose() {
    venueCtrl.dispose();
    titleCtrl.dispose();
    seasonCtrl.dispose();
    super.dispose();
  }

  void _syncMatchTypeFromOvers(int o) {
    if (o == 20) {
      matchType = 'T20';
    } else if (o == 8) {
      matchType = 'Super Sixty';
    } else if (o == 10) {
      matchType = 'T10';
    } else if (o == 5) {
      matchType = 'T5';
    } else if (o == 50) {
      matchType = 'ODI (50)';
    } else {
      matchType = '$o Overs';
    }
  }

  void _preselect() {
    xiA.clear();
    xiB.clear();
    final a = store.teamById(teamAId ?? '');
    final b = store.teamById(teamBId ?? '');
    if (a != null) xiA.addAll(a.players.take(11).map((p) => p.id));
    if (b != null) xiB.addAll(b.players.take(11).map((p) => p.id));
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: PitchTheme.primary,
              onPrimary: Colors.white,
              surface: PitchTheme.surfaceContainerLowest,
              onSurface: PitchTheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => date = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: PitchTheme.primary,
              onPrimary: Colors.white,
              surface: PitchTheme.surfaceContainerLowest,
              onSurface: PitchTheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => time = picked);
    }
  }

  void _showTeamPicker({required bool isTeamA}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentSelectedId = isTeamA ? teamAId : teamBId;
        final otherTeamId = isTeamA ? teamBId : teamAId;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableTeams = store.teams;
            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PitchTheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select ${isTeamA ? 'Team A' : 'Team B'}',
                        style: const TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _quickCreateTeam(isTeamA: isTeamA);
                        },
                        icon: const Icon(Icons.add,
                            size: 18, color: PitchTheme.secondary),
                        label: const Text(
                          'New Team',
                          style: TextStyle(
                            color: PitchTheme.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (availableTeams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.groups_outlined,
                              size: 48, color: PitchTheme.outline),
                          const SizedBox(height: 8),
                          const Text(
                            'No teams created yet',
                            style: TextStyle(
                              color: PitchTheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _quickCreateTeam(isTeamA: isTeamA);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Team'),
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
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: availableTeams.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: PitchTheme.surfaceContainerLow,
                        ),
                        itemBuilder: (context, index) {
                          final t = availableTeams[index];
                          final isSelected = t.id == currentSelectedId;
                          final isOther = t.id == otherTeamId;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? PitchTheme.primaryContainer
                                    : PitchTheme.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  t.name.isNotEmpty
                                      ? t.name[0].toUpperCase()
                                      : 'T',
                                  style: TextStyle(
                                    color: isSelected
                                        ? PitchTheme.tertiaryFixed
                                        : PitchTheme.onSurface,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              t.name,
                              style: TextStyle(
                                color: isOther
                                    ? PitchTheme.outline
                                    : PitchTheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${t.players.length} Squad Players ${isOther ? '(Selected as other team)' : ''}',
                              style: TextStyle(
                                color: isOther
                                    ? PitchTheme.outline
                                    : PitchTheme.outline,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: PitchTheme.secondary,
                                    size: 22,
                                  )
                                : null,
                            enabled: !isOther,
                            onTap: () {
                              setState(() {
                                if (isTeamA) {
                                  teamAId = t.id;
                                } else {
                                  teamBId = t.id;
                                }
                                _preselect();
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _quickCreateTeam({required bool isTeamA}) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create ${isTeamA ? 'Team A' : 'Team B'}',
          style: const TextStyle(
            color: PitchTheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Team Name',
            hintText: 'e.g. Lahore Strikers',
            border: OutlineInputBorder(),
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
              final newTeam = Team(
                id: Store.newId('team'),
                name: name,
                players: [],
              );
              await store.upsertTeam(newTeam);
              setState(() {
                if (isTeamA) {
                  teamAId = newTeam.id;
                } else {
                  teamBId = newTeam.id;
                }
                _preselect();
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PitchTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create & Select'),
          ),
        ],
      ),
    );
  }

  void _showOversPicker() {
    final presetOversList = [5, 8, 10, 12, 15, 20, 25, 30, 40, 50];
    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Overs Limit',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: presetOversList.map((o) {
                  final isSelected = overs == o;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        overs = o;
                        _syncMatchTypeFromOvers(o);
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? PitchTheme.primary
                            : PitchTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? PitchTheme.primary
                              : PitchTheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        '$o Overs',
                        style: TextStyle(
                          color: isSelected ? Colors.white : PitchTheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit, color: PitchTheme.secondary),
                title: const Text(
                  'Custom Overs Count',
                  style: TextStyle(
                    color: PitchTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _promptCustomOvers();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _promptCustomOvers() {
    final ctrl = TextEditingController(text: overs.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Custom Overs Limit',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Overs (1 - 100)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val >= 1 && val <= 100) {
                setState(() {
                  overs = val;
                  _syncMatchTypeFromOvers(val);
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PitchTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMatchTypePicker() {
    final types = [
      ('T20', 20),
      ('Super Sixty', 8),
      ('T10', 10),
      ('T5', 5),
      ('ODI (50)', 50),
      ('Custom Match', overs),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Match Type',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...types.map((t) {
                final isSelected = matchType == t.$1;
                return ListTile(
                  title: Text(
                    t.$1,
                    style: TextStyle(
                      color: isSelected
                          ? PitchTheme.primary
                          : PitchTheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('${t.$2} Overs Limit'),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: PitchTheme.secondary)
                      : null,
                  onTap: () {
                    setState(() {
                      matchType = t.$1;
                      overs = t.$2;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showBallTypePicker() {
    final balls = ['Tennis', 'Tape Ball', 'Leather', 'Rubber'];
    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Ball Type',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...balls.map((b) {
                final isSelected = ballType == b;
                return ListTile(
                  title: Text(
                    b,
                    style: TextStyle(
                      color: isSelected
                          ? PitchTheme.primary
                          : PitchTheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: PitchTheme.secondary)
                      : null,
                  onTap: () {
                    setState(() => ballType = b);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showWicketsPicker() {
    final options = [
      (10, '10 (Standard XI)'),
      (8, '8 Wickets'),
      (6, '6 Wickets'),
      (0, 'Auto (XI - 1)'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Max Wickets',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final isSelected = totalWickets == opt.$1;
                return ListTile(
                  title: Text(
                    opt.$2,
                    style: TextStyle(
                      color: isSelected
                          ? PitchTheme.primary
                          : PitchTheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: PitchTheme.secondary)
                      : null,
                  onTap: () {
                    setState(() => totalWickets = opt.$1);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

    String _getStageDisplayName(String stg) {
    switch (stg) {
      case 'semifinal1':
        return 'Semi Final 1';
      case 'semifinal2':
        return 'Semi Final 2';
      case 'final':
        return 'Grand Final';
      case 'qualifier1':
        return 'Qualifier 1';
      case 'eliminator':
        return 'Eliminator';
      case 'qualifier2':
        return 'Qualifier 2';
      case 'friendly':
        return 'Friendly Match';
      case 'playoff':
        return 'Playoff Match';
      default:
        return 'League Match';
    }
  }

  void _showTournamentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Tournament (Optional)',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.sports_cricket,
                    color: PitchTheme.outline),
                title: const Text(
                  'None (Standalone Match)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Regular friendly or practice match',
                  style: TextStyle(fontSize: 11, color: PitchTheme.outline),
                ),
                trailing: tournamentId == null
                    ? const Icon(Icons.check, color: PitchTheme.secondary)
                    : null,
                onTap: () {
                  setState(() {
                    tournamentId = null;
                    stage = 'friendly';
                  });
                  Navigator.pop(ctx);
                },
              ),
              ...store.tournaments.where((t) {
                if (AuthService().isRestrictedGuest) return false;
                final uid = store.effectiveUserId;
                if (t.creatorId.isNotEmpty) {
                  return uid.isNotEmpty && t.creatorId == uid;
                }
                return true;
              }).map((t) {
                final isSelected = tournamentId == t.id;
                return ListTile(
                  leading: Icon(
                    Icons.emoji_events,
                    color:
                        isSelected ? PitchTheme.secondary : PitchTheme.outline,
                  ),
                  title: Text(
                    t.name,
                    style: TextStyle(
                      color:
                          isSelected ? PitchTheme.primary : PitchTheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${t.teamIds.length} Teams • ${t.oversLimit} Overs',
                    style:
                        const TextStyle(fontSize: 11, color: PitchTheme.outline),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: PitchTheme.secondary)
                      : null,
                  onTap: () {
                    setState(() {
                      tournamentId = t.id;
                      stage = 'league';
                      overs = t.oversLimit;
                      _syncMatchTypeFromOvers(overs);
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showStagePicker() {
    final stages = [
      ('league', 'League Match', Icons.table_chart_outlined, 'Group stage match'),
      ('qualifier1', 'Qualifier 1', Icons.looks_one_outlined, 'Top 2 teams playoff'),
      ('eliminator', 'Eliminator', Icons.dangerous_outlined, 'Knockout playoff match'),
      ('qualifier2', 'Qualifier 2', Icons.looks_two_outlined, 'Playoff semifinal match'),
      ('semifinal1', 'Semi Final 1', Icons.military_tech_outlined, '1st semi final match'),
      ('semifinal2', 'Semi Final 2', Icons.military_tech_outlined, '2nd semi final match'),
      ('final', 'Grand Final', Icons.emoji_events_outlined, 'Tournament championship final'),
      ('playoff', 'Playoff Match', Icons.military_tech_outlined, 'General tournament playoff match'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Match Stage',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...stages.map((stg) {
                final isSelected = stage == stg.$1;
                return ListTile(
                  leading: Icon(
                    stg.$3,
                    color: isSelected ? PitchTheme.secondary : PitchTheme.outline,
                  ),
                  title: Text(
                    stg.$2,
                    style: TextStyle(
                      color: isSelected ? PitchTheme.primary : PitchTheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    stg.$4,
                    style: const TextStyle(fontSize: 11, color: PitchTheme.outline),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: PitchTheme.secondary)
                      : null,
                  onTap: () {
                    setState(() => stage = stg.$1);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleScoreLater() async {
    if (!_canProceed) {
      if (teamAId == null || teamBId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both Team A and Team B.'),
            backgroundColor: PitchTheme.error,
          ),
        );
        return;
      }
      if (teamAId == teamBId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team A and Team B must be two different teams.'),
            backgroundColor: PitchTheme.error,
          ),
        );
        return;
      }
    }

    _preselect();
    String p2(int v) => v.toString().padLeft(2, '0');
    final draft = MatchDraft(
      teamAId: teamAId!,
      teamBId: teamBId!,
      oversLimit: overs,
      ballsPerOver: ballsPerOver,
      venue: venueCtrl.text.trim(),
      dateIso:
          '${date.year}-${p2(date.month)}-${p2(date.day)}T${p2(time.hour)}:${p2(time.minute)}:00',
      matchTitle: titleCtrl.text.trim(),
      ballType: ballType,
      season: seasonCtrl.text.trim(),
      stage: isTournamentMatch ? stage : 'friendly',
      totalWickets: totalWickets,
      widePenalty: widePenalty,
      noBallPenalty: noBallPenalty,
      lastManStands: lastManStands,
      xiA: xiA.toList(),
      xiB: xiB.toList(),
      tournamentId: tournamentId,
      existingMatch: widget.existingMatch,
      creatorId: store.effectiveUserId,
      creatorName: store.activeProfile.displayName,
      creatorCode: store.effectiveUserCode,
    );

    final upcomingMatch = draft.toUpcomingFixture();
    await store.upsertMatch(upcomingMatch);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.event_available, color: PitchTheme.tertiaryFixed, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Match scheduled successfully! Saved under Upcoming matches.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: PitchTheme.primaryContainer,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context, true);
  }

  bool get _canProceed =>
      teamAId != null && teamBId != null && teamAId != teamBId;

  void _handleCreateMatch() {
    if (!_canProceed) {
      if (teamAId == null || teamBId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both Team A and Team B.'),
            backgroundColor: PitchTheme.error,
          ),
        );
        return;
      }
      if (teamAId == teamBId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team A and Team B must be two different teams.'),
            backgroundColor: PitchTheme.error,
          ),
        );
        return;
      }
    }

    _preselect();

    String p2(int v) => v.toString().padLeft(2, '0');
    final draft = MatchDraft(
      teamAId: teamAId!,
      teamBId: teamBId!,
      oversLimit: overs,
      ballsPerOver: ballsPerOver,
      venue: venueCtrl.text.trim(),
      dateIso:
          '${date.year}-${p2(date.month)}-${p2(date.day)}T${p2(time.hour)}:${p2(time.minute)}:00',
      matchTitle: titleCtrl.text.trim(),
      ballType: ballType,
      season: seasonCtrl.text.trim(),
      stage: isTournamentMatch ? stage : 'friendly',
      totalWickets: totalWickets,
      widePenalty: widePenalty,
      noBallPenalty: noBallPenalty,
      lastManStands: lastManStands,
      tossWinnerId: tossWinnerId ?? teamAId!,
      tossDecision: tossDecision,
      xiA: xiA.toList(),
      xiB: xiB.toList(),
      tournamentId: tournamentId,
      existingMatch: widget.existingMatch,
      creatorId: store.effectiveUserId,
      creatorName: store.activeProfile.displayName,
      creatorCode: store.effectiveUserCode,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchTossScreen(
          store: store,
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamA = teamAId != null ? store.teamById(teamAId!) : null;
    final teamB = teamBId != null ? store.teamById(teamBId!) : null;

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // Top Clean Minimal Header
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: PitchTheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(
                    color: PitchTheme.surfaceContainerLow,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: PitchTheme.onSurface,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Create Match',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Set up your match',
                        style: TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // Scrollable Content Body
            // -----------------------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 18.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tournament Indicator if any
                        if (isTournamentMatch) ...[
                          _buildTournamentBadge(),
                          const SizedBox(height: 14),
                        ],

                        // SECTION 1: Team Selection Card (Team A vs Team B)
                        _buildTeamSelectionCard(teamA, teamB),
                        const SizedBox(height: 18),

                        // SECTION 2: Clean Form Fields Card
                        _buildMatchDetailsCard(),
                        const SizedBox(height: 14),

                        // SECTION 3: Advanced Options & Tournament (Expandable)
                        _buildAdvancedRulesTile(),
                        const SizedBox(height: 24),

                        // SECTION 4: Bottom Action CTA
                        _buildBottomActionCta(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tournament Badge
  // ---------------------------------------------------------------------------
  Widget _buildTournamentBadge() {
    final t = store.tournamentById(tournamentId ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PitchTheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events,
              size: 16, color: PitchTheme.tertiaryFixed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t != null ? 'Tournament: ${t.name}' : 'Tournament Match',
              style: const TextStyle(
                color: PitchTheme.tertiaryFixed,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.tournamentId == null &&
              widget.existingMatch?.tournamentId == null) ...[
            InkWell(
              onTap: () {
                setState(() {
                  tournamentId = null;
                  stage = 'friendly';
                });
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close,
                    size: 16, color: PitchTheme.tertiaryFixed),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 1: Clean Circular Team Selection (Team A vs Team B)
  // ---------------------------------------------------------------------------
  Widget _buildTeamSelectionCard(Team? teamA, Team? teamB) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchTheme.surfaceContainerLow),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Team A
          Expanded(
            child: _buildTeamCircleItem(
              label: 'TEAM A',
              team: teamA,
              isTeamA: true,
            ),
          ),

          // VS Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'vs',
              style: TextStyle(
                color: PitchTheme.outlineVariant,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Team B
          Expanded(
            child: _buildTeamCircleItem(
              label: 'TEAM B',
              team: teamB,
              isTeamA: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCircleItem({
    required String label,
    required Team? team,
    required bool isTeamA,
  }) {
    final hasSelected = team != null;

    return InkWell(
      onTap: () => _showTeamPicker(isTeamA: isTeamA),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Team',
            style: TextStyle(
              color: PitchTheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // 80x80 Circle: Dotted border with + OR Solid with initials
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: hasSelected
                  ? null
                  : const DottedCirclePainter(
                      color: PitchTheme.outlineVariant,
                      strokeWidth: 2,
                      dashWidth: 5,
                      dashSpace: 4,
                    ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasSelected
                      ? PitchTheme.primaryContainer
                      : PitchTheme.surfaceContainerLow.withValues(alpha: 0.4),
                  border: hasSelected
                      ? Border.all(color: PitchTheme.secondary, width: 2)
                      : null,
                ),
                child: Center(
                  child: hasSelected
                      ? Text(
                          team.name.isNotEmpty
                              ? team.name[0].toUpperCase()
                              : 'T',
                          style: const TextStyle(
                            color: PitchTheme.tertiaryFixed,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : const Icon(
                          Icons.add,
                          size: 28,
                          color: PitchTheme.outline,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Team Name or TEAM A/B
          Text(
            hasSelected ? team.name.toUpperCase() : label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PitchTheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 2: Clean Form Fields Card
  // ---------------------------------------------------------------------------
  Widget _buildMatchDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchTheme.surfaceContainerLow),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Venue Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VENUE',
                style: TextStyle(
                  color: PitchTheme.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: venueCtrl,
                      style: const TextStyle(
                        color: PitchTheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        hintText: 'Enter venue name',
                        hintStyle: TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.location_on,
                    size: 20,
                    color: PitchTheme.outline,
                  ),
                ],
              ),
              Container(
                height: 1,
                color: PitchTheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Date & Time Row
          Row(
            children: [
              // Date
              Expanded(
                child: _buildClickableFormField(
                  label: 'DATE',
                  value: _formatDate(date),
                  icon: Icons.calendar_today,
                  iconSize: 17,
                  onTap: _selectDate,
                ),
              ),
              const SizedBox(width: 20),
              // Time
              Expanded(
                child: _buildClickableFormField(
                  label: 'TIME',
                  value: _formatTime(time),
                  icon: Icons.schedule,
                  iconSize: 18,
                  onTap: _selectTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. Overs & Match Type Row
          Row(
            children: [
              // Overs
              Expanded(
                child: _buildClickableFormField(
                  label: 'OVERS',
                  value: '$overs',
                  icon: Icons.arrow_drop_down,
                  iconSize: 22,
                  onTap: _showOversPicker,
                ),
              ),
              const SizedBox(width: 20),
              // Match Type
              Expanded(
                child: _buildClickableFormField(
                  label: 'MATCH TYPE',
                  value: matchType,
                  icon: Icons.arrow_drop_down,
                  iconSize: 22,
                  onTap: _showMatchTypePicker,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Match Stage Row (Tournament Matches Only)
          if (isTournamentMatch) ...[
            Row(
              children: [
                Expanded(
                  child: _buildClickableFormField(
                    label: 'MATCH STAGE',
                    value: _getStageDisplayName(stage),
                    icon: Icons.arrow_drop_down,
                    iconSize: 22,
                    onTap: _showStagePicker,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // 4. Ball Type & Wickets Row
          Row(
            children: [
              // Ball Type
              Expanded(
                child: _buildClickableFormField(
                  label: 'BALL TYPE',
                  value: ballType,
                  icon: Icons.arrow_drop_down,
                  iconSize: 22,
                  onTap: _showBallTypePicker,
                ),
              ),
              const SizedBox(width: 20),
              // Wickets
              Expanded(
                child: _buildClickableFormField(
                  label: 'WICKETS',
                  value: totalWickets == 0 ? '10 (Auto)' : '$totalWickets',
                  icon: Icons.arrow_drop_down,
                  iconSize: 22,
                  onTap: _showWicketsPicker,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClickableFormField({
    required String label,
    required String value,
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PitchTheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: PitchTheme.onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: iconSize,
                color: PitchTheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: PitchTheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 3: Advanced Options & Tournament (Expandable)
  // ---------------------------------------------------------------------------
  Widget _buildAdvancedRulesTile() {
    return Container(
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showAdvancedRules,
          onExpansionChanged: (v) => setState(() => _showAdvancedRules = v),
          title: const Text(
            'Match Rules & Tournament (Optional)',
            style: TextStyle(
              color: PitchTheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: PitchTheme.surfaceContainerLow),
                  // Match Title (Optional)
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: const InputDecoration(
                      labelText: 'Match Title / Subtitle (Optional)',
                      hintText: 'e.g. Semi-Final, Friendly Cup',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (widget.tournamentId == null &&
                      widget.existingMatch?.tournamentId == null &&
                      store.tournaments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildClickableFormField(
                      label: 'LINK TO TOURNAMENT (OPTIONAL)',
                      value: tournamentId != null
                          ? (store.tournamentById(tournamentId!)?.name ??
                              'Tournament Linked')
                          : 'None (Standalone Match)',
                      icon: Icons.arrow_drop_down,
                      iconSize: 22,
                      onTap: _showTournamentPicker,
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Balls Per Over
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balls per Over',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [4, 5, 6, 8].map((b) {
                          final isSel = ballsPerOver == b;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: InkWell(
                              onTap: () => setState(() => ballsPerOver = b),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? PitchTheme.primaryContainer
                                      : PitchTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$b',
                                  style: TextStyle(
                                    color: isSel
                                        ? PitchTheme.tertiaryFixed
                                        : PitchTheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Wide Ball Penalty Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Wide Ball (+1 run penalty)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: widePenalty,
                    activeTrackColor: PitchTheme.secondary,
                    onChanged: (v) => setState(() => widePenalty = v),
                  ),

                  // No Ball Penalty Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'No Ball (+1 run penalty)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: noBallPenalty,
                    activeTrackColor: PitchTheme.secondary,
                    onChanged: (v) => setState(() => noBallPenalty = v),
                  ),

                  // Last Man Stands Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Last Man Stands (Bat solo on last wicket)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: lastManStands,
                    activeTrackColor: PitchTheme.secondary,
                    onChanged: (v) => setState(() => lastManStands = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 4: Bottom Action CTA
  // ---------------------------------------------------------------------------
    Widget _buildBottomActionCta() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Primary Action: START NOW
        ElevatedButton(
          onPressed: _handleCreateMatch,
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
            children: const [
              Text(
                'START NOW (TOSS & LINEUPS)',
                style: TextStyle(
                  fontFamily: 'Chivo',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 18, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Secondary Action: SCORE LATER
        OutlinedButton(
          onPressed: _handleScoreLater,
          style: OutlinedButton.styleFrom(
            backgroundColor: PitchTheme.surfaceContainerLowest,
            foregroundColor: PitchTheme.primary,
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(
              color: PitchTheme.outlineVariant.withValues(alpha: 0.7),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.calendar_month, size: 18, color: PitchTheme.secondary),
              SizedBox(width: 8),
              Text(
                'SCORE LATER (SAVE FIXTURE)',
                style: TextStyle(
                  fontFamily: 'Chivo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: PitchTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
