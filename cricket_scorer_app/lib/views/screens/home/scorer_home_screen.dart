import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/services/auth/auth_service.dart';

import 'package:cricket_scorer_app/models/models.dart';

import 'package:cricket_scorer_app/core/utils/nav_memory.dart';

import 'package:cricket_scorer_app/services/share/points_table_share.dart';

import 'package:cricket_scorer_app/services/sync/publish_service.dart';

import 'package:cricket_scorer_app/domain/scoring/scoring.dart';

import 'package:cricket_scorer_app/services/storage/store.dart';

import 'package:cricket_scorer_app/core/theme/theme.dart';

import 'package:cricket_scorer_app/domain/tournament/tournament_engine.dart';

import 'package:cricket_scorer_app/views/widgets/guest_guard.dart';
import 'package:cricket_scorer_app/views/widgets/player_avatar.dart';

import 'package:cricket_scorer_app/views/screens/tournament/fixture_detail_screen.dart';

import 'package:cricket_scorer_app/views/screens/scoring/match_setup_screen.dart';

import 'package:cricket_scorer_app/views/screens/tournament/nrr_calculator_screen.dart';

import 'package:cricket_scorer_app/views/screens/tournament/qualification_chances_screen.dart';

import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';

import 'package:cricket_scorer_app/views/screens/scoring/scoring_screen.dart';

import 'package:cricket_scorer_app/views/screens/home/settings_screen.dart';

import 'package:cricket_scorer_app/views/screens/tournament/tournament_stats.dart';
import 'package:cricket_scorer_app/views/screens/draft/draft_screen.dart';

// 60Score v1.1.2 Matches screen: status tabs, filters, and match cards

// matching the approved redesign reference. Real data only — every list is

// derived from store.matches plus the active tab/filters.

class ScorerHomeScreen extends StatefulWidget {
  final Store store;

  final VoidCallback onOpenDrawer;

  const ScorerHomeScreen({
    super.key,
    required this.store,
    required this.onOpenDrawer,
  });

  @override
  State<ScorerHomeScreen> createState() => _ScorerHomeScreenState();
}

class _ScorerHomeScreenState extends State<ScorerHomeScreen> {
  Store get store => widget.store;

  // 0 = All, 1 = Live, 2 = Upcoming, 3 = Completed.

  int _tab = 0;

  String? _tournamentId;

  String? _teamId;

  int? _overs;

  // Default order is the straight fixture sequence (v1.3.5):

  // chronological ascending — the nearest match first and the

  // Grand Final last. The filter sheet can flip it to newest-first.

  String _sort = 'oldest'; // 'newest' | 'oldest'

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

  bool get _hasActiveFilters =>
      _tournamentId != null || _teamId != null || _overs != null;

  bool _isLive(Match m) => m.status == 'live';

  bool _isUpcoming(Match m) =>
      m.status == 'upcoming' || m.status == 'scheduled';

  List<Match> _applyFilters(List<Match> input) {
    final list = input.where((m) {
      if (_tournamentId != null && m.tournamentId != _tournamentId) {
        return false;
      }

      if (_teamId != null && m.teamAId != _teamId && m.teamBId != _teamId) {
        return false;
      }

      if (_overs != null && m.oversLimit != _overs) return false;

      return true;
    }).toList();

    list.sort((a, b) {
      // Fixtures without a date always go last.

      if (a.dateIso.isEmpty && b.dateIso.isEmpty) return 0;

      if (a.dateIso.isEmpty) return 1;

      if (b.dateIso.isEmpty) return -1;

      final c = a.dateIso.compareTo(b.dateIso);

      return _sort == 'newest' ? -c : c;
    });

    return list;
  }

  /// Tap target per lifecycle: live -> scorer, upcoming/scheduled ->

  /// fixture hub, completed -> scorecard. noResult/cancelled fixtures go to

  /// the fixture hub too (never the scorecard — that was the red-screen bug).

  void _openMatch(Match m) {
    final canScore = !AuthService().isRestrictedGuest &&
        m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);
    if (m.status == 'live') {
      if (canScore) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScoringScreen(store: store, match: m),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScorecardScreen(store: store, match: m),
          ),
        );
      }
      return;
    }

    if (m.status == 'completed') {
      Navigator.push(
        context,

        MaterialPageRoute(
          builder: (_) => ScorecardScreen(store: store, match: m),
        ),
      );

      return;
    }

    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => FixtureDetailScreen(store: store, matchId: m.id),
      ),
    );
  }

  /// Delete ONE match (v1.3.5: completed matches; v1.3.7: also

  /// upcoming / cancelled / noResult fixtures), with confirmation —

  /// the points table and statistics recompute from the remaining

  /// records on their own. LIVE matches are excluded: deleting a

  /// match while its scoring screen is open would corrupt the

  /// live session.

  Future<void> _confirmDeleteMatch(Match m) async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (c) => AlertDialog(
        title: const Text('Delete match?'),

        content: Text(
          'Delete ${store.teamName(m.teamAId)} vs '
          '${store.teamName(m.teamBId)}'
          '${m.status == 'completed' ? ' and its scorecard' : ''}? '
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

  void _showNewMatchMenu(BuildContext buttonCtx) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    final box = buttonCtx.findRenderObject() as RenderBox?;

    final RelativeRect position;

    if (box != null && overlay != null) {
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);

      final bottomRight = box.localToGlobal(
        box.size.bottomRight(Offset.zero),
        ancestor: overlay,
      );

      position = RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      );
    } else {
      position = const RelativeRect.fromLTRB(200, 200, 0, 0);
    }

    showMenu<String>(
      context: buttonCtx,

      position: position,

      color: PitchTheme.surfaceContainerLowest,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      items: [
        PopupMenuItem(
          value: 'quick',

          child: Row(
            children: const [
              Icon(Icons.flash_on, color: kCyan, size: 20),

              SizedBox(width: 10),

              Text(
                'Quick Match',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        PopupMenuItem(
          value: 'tournament',

          child: Row(
            children: const [
              Icon(Icons.emoji_events, color: kGold, size: 20),

              SizedBox(width: 10),

              Text(
                'Tournament Match',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == null || !mounted) return;
      if (!await requireSignedInAction(context, store,
          actionLabel: 'create matches')) {
        return;
      }
      if (!mounted) return;

      Navigator.push(
        context,

        MaterialPageRoute(builder: (_) => MatchSetupScreen(store: store)),
      );
    });
  }

  void _openAdvancedFilters() {
    showModalBottomSheet<void>(
      context: context,

      backgroundColor: PitchTheme.surfaceContainerLowest,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Advanced Filters',

                      style: TextStyle(
                        color: PitchTheme.onSurface,

                        fontSize: 18,

                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'SORT BY DATE',

                      style: TextStyle(
                        color: PitchTheme.outline,

                        fontSize: 11,

                        fontWeight: FontWeight.w700,

                        letterSpacing: 1,
                      ),
                    ),

                    RadioGroup<String>(
                      groupValue: _sort,

                      onChanged: (v) {
                        if (v == null) return;

                        setState(() => _sort = v);
                      },

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: const [
                          RadioListTile<String>(
                            value: 'newest',

                            title: Text(
                              'Date: newest first',

                              style: TextStyle(
                                color: PitchTheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            activeColor: PitchTheme.secondary,

                            contentPadding: EdgeInsets.zero,

                            dense: true,
                          ),

                          RadioListTile<String>(
                            value: 'oldest',

                            title: Text(
                              'Date: oldest first',

                              style: TextStyle(
                                color: PitchTheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            activeColor: PitchTheme.secondary,

                            contentPadding: EdgeInsets.zero,

                            dense: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,

                      child: OutlinedButton.icon(
                        onPressed: _hasActiveFilters
                            ? () {
                                setState(() {
                                  _tournamentId = null;

                                  _teamId = null;

                                  _overs = null;
                                });

                                Navigator.pop(sheetCtx);
                              }
                            : null,

                        icon: const Icon(Icons.filter_alt_off, size: 18),

                        label: const Text('Clear all filters'),

                        style: OutlinedButton.styleFrom(
                          foregroundColor: PitchTheme.primary,

                          side: const BorderSide(color: PitchTheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _applyFilters(store.matches.where(_isUpcoming).toList());

    final live = _applyFilters(store.matches.where(_isLive).toList());

    final completed = _applyFilters(
      store.matches.where((m) => !_isLive(m) && !_isUpcoming(m)).toList(),
    );

    final sections = <Widget>[];

    switch (_tab) {
      case 1:
        sections.add(_liveSection(live));

        break;

      case 2:
        sections.add(_upcomingSection(upcoming));

        break;

      case 3:
        sections.add(_completedSection(completed));

        break;

      default:
        final totalCount = upcoming.length + live.length + completed.length;

        if (totalCount == 0) {
          sections.add(
            _buildUnifiedEmptyState(
              isFiltered: _hasActiveFilters,

              onClearFilters: () {
                setState(() {
                  _tournamentId = null;

                  _teamId = null;

                  _overs = null;
                });
              },

              onStartMatch: () => _showNewMatchMenu(context),
            ),
          );
        } else {
          if (live.isNotEmpty) sections.add(_liveSection(live));

          if (upcoming.isNotEmpty) sections.add(_upcomingSection(upcoming));

          if (completed.isNotEmpty) sections.add(_completedSection(completed));
        }
    }

    return Scaffold(
      backgroundColor: PitchTheme.surface,

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),

          children: [
            BrandedHeader(
              onMenu: widget.onOpenDrawer,

              onSettings: () => Navigator.push(
                context,

                MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
              ),
            ),

            _titleRow(),

            const SizedBox(height: 12),

            _tabsRow(),

            const SizedBox(height: 10),

            _filtersRow(),

            ...sections,
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
    final totalMatches = store.matches.length;
    final liveMatches = store.matches.where(_isLive).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Matches',
                      style: TextStyle(
                        color: PitchTheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: liveMatches > 0
                            ? PitchTheme.error.withValues(alpha: 0.12)
                            : PitchTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        liveMatches > 0 ? '$liveMatches LIVE' : '$totalMatches Total',
                        style: TextStyle(
                          color: liveMatches > 0
                              ? PitchTheme.error
                              : PitchTheme.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'View, manage & score fixtures',
                  style: TextStyle(
                    color: PitchTheme.outline,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (btnCtx) => ElevatedButton(
              onPressed: () => _showNewMatchMenu(btnCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: PitchTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, size: 18, color: PitchTheme.tertiaryFixed),
                  SizedBox(width: 5),
                  Text(
                    'New Match',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabsRow() {
    final liveCount = store.matches.where(_isLive).length;
    final upcomingCount = store.matches.where(_isUpcoming).length;
    final completedCount =
        store.matches.where((m) => !_isLive(m) && !_isUpcoming(m)).length;
    final allCount = store.matches.length;

    final tabs = [
      (label: 'All Matches', count: allCount, icon: Icons.sports_cricket, isLive: false, id: 0),
      (label: 'Live', count: liveCount, icon: Icons.sensors, isLive: true, id: 1),
      (label: 'Upcoming', count: upcomingCount, icon: Icons.calendar_month, isLive: false, id: 2),
      (label: 'Completed', count: completedCount, icon: Icons.check_circle_outline, isLive: false, id: 3),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          for (final t in tabs) ...[
            _tabPill(
              label: t.label,
              count: t.count,
              icon: t.icon,
              isLive: t.isLive,
              selected: _tab == t.id,
              onTap: () => setState(() => _tab = t.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tabPill({
    required String label,
    required int count,
    required IconData icon,
    required bool isLive,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? PitchTheme.primaryContainer
              : PitchTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? PitchTheme.primaryContainer
                : PitchTheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: PitchTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ] else ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? PitchTheme.tertiaryFixed
                    : PitchTheme.secondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? PitchTheme.tertiaryFixed
                    : PitchTheme.onSurface,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? PitchTheme.secondaryContainer
                    : PitchTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? PitchTheme.onSecondaryContainer
                      : PitchTheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersRow() {
    final tournaments = store.tournaments;
    final teams = store.teams;
    final formats = <int>{for (final m in store.matches) m.oversLimit}.toList()
      ..sort();

    final tournamentSelected = _tournamentId != null;
    final teamSelected = _teamId != null;
    final formatSelected = _overs != null;

    final tournamentLabel = tournamentSelected
        ? (store.tournamentById(_tournamentId)?.name ?? 'Tournament')
        : 'All Tournaments';

    final teamLabel = teamSelected ? store.teamName(_teamId!) : 'All Teams';

    final formatLabel = formatSelected ? '$_overs overs' : 'All Formats';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          _advancedFilterButton(),
          const SizedBox(width: 8),
          _filterChip(
            icon: Icons.emoji_events_outlined,
            label: tournamentLabel,
            isSelected: tournamentSelected,
            onClear: tournamentSelected
                ? () => setState(() => _tournamentId = null)
                : null,
            onSelected: (v) =>
                setState(() => _tournamentId = v.isEmpty ? null : v),
            items: [
              const PopupMenuItem(value: '', child: Text('All Tournaments')),
              for (final t in tournaments)
                PopupMenuItem(value: t.id, child: Text(t.name)),
            ],
          ),
          const SizedBox(width: 8),
          _filterChip(
            icon: Icons.groups_outlined,
            label: teamLabel,
            isSelected: teamSelected,
            onClear: teamSelected ? () => setState(() => _teamId = null) : null,
            onSelected: (v) => setState(() => _teamId = v.isEmpty ? null : v),
            items: [
              const PopupMenuItem(value: '', child: Text('All Teams')),
              for (final t in teams)
                PopupMenuItem(value: t.id, child: Text(t.name)),
            ],
          ),
          const SizedBox(width: 8),
          _filterChip(
            icon: Icons.sports_cricket_outlined,
            label: formatLabel,
            isSelected: formatSelected,
            onClear:
                formatSelected ? () => setState(() => _overs = null) : null,
            onSelected: (v) =>
                setState(() => _overs = v.isEmpty ? null : int.parse(v)),
            items: [
              const PopupMenuItem(value: '', child: Text('All Formats')),
              for (final o in formats)
                PopupMenuItem(value: '$o', child: Text('$o overs')),
            ],
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(() {
                _tournamentId = null;
                _teamId = null;
                _overs = null;
              }),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: PitchTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: PitchTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.close, color: PitchTheme.error, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: PitchTheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
    bool isSelected = false,
    VoidCallback? onClear,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: PitchTheme.surfaceContainerLowest,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => items,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? PitchTheme.primaryContainer
              : PitchTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? PitchTheme.primaryContainer
                : PitchTheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? PitchTheme.tertiaryFixed
                  : PitchTheme.secondary,
              size: 16,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? PitchTheme.surface : PitchTheme.onSurface,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (isSelected && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.cancel,
                    color: PitchTheme.tertiaryFixed,
                    size: 15,
                  ),
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down,
                color: isSelected
                    ? PitchTheme.surface.withValues(alpha: 0.7)
                    : PitchTheme.outline,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _advancedFilterButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: _openAdvancedFilters,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hasActiveFilters || _sort != 'oldest'
                    ? PitchTheme.secondary
                    : PitchTheme.outlineVariant.withValues(alpha: 0.4),
                width: 1,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune,
                  color: _hasActiveFilters || _sort != 'oldest'
                      ? PitchTheme.secondary
                      : PitchTheme.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Filters',
                  style: TextStyle(
                    color: _hasActiveFilters || _sort != 'oldest'
                        ? PitchTheme.secondary
                        : PitchTheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_hasActiveFilters || _sort != 'oldest')
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: PitchTheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUnifiedEmptyState({
    required bool isFiltered,
    required VoidCallback onClearFilters,
    required VoidCallback onStartMatch,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PitchTheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PitchTheme.surfaceContainerLow,
              border: Border.all(
                color: PitchTheme.secondary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.sports_cricket,
              size: 32,
              color: PitchTheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'No matches match your filters'
                : 'No matches scheduled yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PitchTheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try resetting your tournament, team, or format filters to see all fixtures.'
                : 'Start scoring a quick match or create tournament fixtures to see them here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PitchTheme.outline,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (isFiltered)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Reset All Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PitchTheme.secondary,
                side: const BorderSide(color: PitchTheme.secondary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: onStartMatch,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Start First Match'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PitchTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _upcomingSection(List<Match> matches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        SectionTitle(
          icon: Icons.calendar_month,

          title: 'Upcoming Matches',

          trailing: _tab == 2 || matches.length > 4
              ? null
              : ViewAllLink(onTap: () => setState(() => _tab = 2)),
        ),

        if (matches.isEmpty)
          const EmptyState(
            icon: Icons.calendar_month,

            title: 'No upcoming matches',

            subtitle: 'New fixtures will appear here once scheduled.',
          )
        else
          for (var i = 0; i < matches.length; i++)
            _matchCard(matches[i], number: i + 1),
      ],
    );
  }

  Widget _liveSection(List<Match> matches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),

          child: Row(
            children: [
              const Icon(Icons.sensors, color: kRed, size: 20),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'LIVE MATCHES',

                  style: TextStyle(
                    color: PitchTheme.onSurface,

                    fontSize: 15,

                    fontWeight: FontWeight.w800,

                    letterSpacing: 0.5,
                  ),
                ),
              ),

              if (_tab != 1 && matches.isNotEmpty)
                ViewAllLink(onTap: () => setState(() => _tab = 1)),
            ],
          ),
        ),

        if (matches.isEmpty)
          const EmptyState(
            icon: Icons.sensors,

            title: 'No live matches at the moment',

            subtitle:
                'When a match is live, it will appear here for quick access.',
          )
        else
          for (var i = 0; i < matches.length; i++)
            _matchCard(matches[i], number: i + 1),
      ],
    );
  }

  Widget _completedSection(List<Match> matches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        SectionTitle(
          icon: Icons.check_circle,

          title: 'Completed Matches',

          trailing: _tab == 3
              ? null
              : ViewAllLink(onTap: () => setState(() => _tab = 3)),
        ),

        if (matches.isEmpty)
          const EmptyState(
            icon: Icons.check_circle,

            title: 'No completed matches yet',

            subtitle: 'Finished matches will appear here with full scorecards.',
          )
        else
          for (var i = 0; i < matches.length; i++)
            _matchCard(matches[i], number: i + 1),
      ],
    );
  }

  /// Split "06 Nov 2026, 03:00 PM" into date/time lines.

  (String, String) _dateTimeParts(String dateIso) {
    final full = formatFixtureDate(dateIso);

    if (full == 'Date TBD') return ('Date TBD', '');

    final idx = full.indexOf(', ');

    if (idx < 0) return (full, '');

    return (full.substring(0, idx), full.substring(idx + 2));
  }

  Widget _matchCard(Match m, {required int number}) {
    final (dateStr, timeStr) = _dateTimeParts(m.dateIso);
    final venue = m.venue.trim().isEmpty ? 'Venue TBD' : m.venue.trim();
    final nameA = store.teamName(m.teamAId);
    final nameB = store.teamName(m.teamBId);
    final title = m.matchTitle.trim().isNotEmpty
        ? m.matchTitle.trim()
        : 'Match $number';
    final stageTag = m.stage == 'league'
        ? 'LEAGUE'
        : stageLabel(m.stage).toUpperCase();

    final isLive = m.status == 'live';
    final isCompleted = m.status == 'completed' || m.status == 'noResult';

    // Innings summaries if available
    final innA = m.innings.where((i) => i.battingTeamId == m.teamAId).firstOrNull;
    final innB = m.innings.where((i) => i.battingTeamId == m.teamBId).firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openMatch(m),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLive
                  ? PitchTheme.secondary.withValues(alpha: 0.6)
                  : PitchTheme.outlineVariant.withValues(alpha: 0.35),
              width: isLive ? 1.5 : 1,
            ),
            boxShadow: PitchTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar: Stage tag, Match Title & Overs, Status Pill, Delete
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isLive
                      ? PitchTheme.primaryContainer.withValues(alpha: 0.08)
                      : PitchTheme.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isLive ? PitchTheme.primaryContainer : PitchTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stageTag,
                        style: TextStyle(
                          color: isLive ? PitchTheme.tertiaryFixed : PitchTheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$title • ${m.oversLimit} Overs',
                        style: const TextStyle(
                          color: PitchTheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusPill(m.status),
                    if (!isLive) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _confirmDeleteMatch(m),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline, size: 18, color: PitchTheme.outline),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. Center Matchup: Team A vs Team B (Clean, Spacious & Responsive)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  children: [
                    // Team A
                    Expanded(
                      child: Row(
                        children: [
                          CaptainAvatar(store: store, teamId: m.teamAId, radius: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  nameA,
                                  style: const TextStyle(
                                    color: PitchTheme.onSurface,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (innA != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${innA.totalRuns}/${innA.wickets} (${oversText(innA.legalBalls, innA.ballsPerOver)})',
                                    style: const TextStyle(
                                      color: PitchTheme.onSurfaceVariant,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // VS Pill
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLive
                              ? PitchTheme.error.withValues(alpha: 0.1)
                              : PitchTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: isLive ? PitchTheme.error : PitchTheme.outline,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),

                    // Team B
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  nameB,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    color: PitchTheme.onSurface,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (innB != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${innB.totalRuns}/${innB.wickets} (${oversText(innB.legalBalls, innB.ballsPerOver)})',
                                    style: const TextStyle(
                                      color: PitchTheme.onSurfaceVariant,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CaptainAvatar(store: store, teamId: m.teamBId, radius: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Result Banner (if completed)
              if (isCompleted && m.resultText.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: PitchTheme.onSecondaryContainer, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.resultText.trim(),
                            style: const TextStyle(
                              color: PitchTheme.onSecondaryContainer,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Card Footer: Date, Time, Venue, Forward Chevron
              Divider(height: 1, color: PitchTheme.outlineVariant.withValues(alpha: 0.25)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: PitchTheme.outline, size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dateStr + (timeStr.isNotEmpty ? ', $timeStr' : ''),
                        style: const TextStyle(color: PitchTheme.outline, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: PitchTheme.outline, fontSize: 11)),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on, color: PitchTheme.outline, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue,
                        style: const TextStyle(color: PitchTheme.outline, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: PitchTheme.secondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TournamentDetailScreen extends StatefulWidget {
  final Store store;

  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,

    required this.store,

    required this.tournament,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Store get store => widget.store;

  Tournament get tournament => widget.tournament;

  /// Latest playoff recalculation outcome (idempotent engine pass).

  /// Fetched once on open and re-run whenever a fixture screen pops back.

  PlayoffUpdate? _playoffUpdate;

  @override
  void initState() {
    super.initState();

    // Recents resume (v1.4.5): see NavMemory's contract.

    NavMemory.save('tournament', tournament.id);

    _runPlayoffUpdate();
  }

  @override
  void dispose() {
    NavMemory.clear('tournament', tournament.id);

    super.dispose();
  }

  Future<void> _runPlayoffUpdate() async {
    final update = await applyPlayoffUpdate(store, tournament.id);

    if (mounted) setState(() => _playoffUpdate = update);
  }

  /// Team IDs currently shown with a Q badge. Final qualifiers when the

  /// league stage is locked, otherwise mathematically guaranteed

  /// provisional qualifiers.

  Set<String> get _qualifierIds {
    final finalQ =
        _playoffUpdate?.finalQualifiers ?? tournament.qualifiedTeamIds;

    if (tournament.qualificationFinalized && finalQ.isNotEmpty) {
      return finalQ.toSet();
    }

    return (_playoffUpdate?.provisionalQualifiers ?? const <String>[]).toSet();
  }

  bool get _qualificationFinal =>
      tournament.qualificationFinalized &&
      ((_playoffUpdate?.finalQualifiers ?? tournament.qualifiedTeamIds)
          .isNotEmpty);

  /// Publish / unpublish this tournament (owner only, login required).

  /// Manual action only — publishing is never automatic.

  Future<void> _togglePublish() async {
    final wasPublished = tournament.published;

    final svc = PublishService();

    final err = wasPublished
        ? await svc.unpublish(store, tournament)
        : await svc.publish(store, tournament);

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ??
              (wasPublished
                  ? 'Unpublished — it no longer appears in Search.'
                  : 'Published — anyone can find it in Search '
                        '(view-only).'),
        ),
      ),
    );
  }

  Future<void> _openFixture(Match m) async {
    late final Widget screen;
    final canScore = !AuthService().isRestrictedGuest &&
        m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);

    switch (m.status) {
      case 'live':
        screen = canScore
            ? ScoringScreen(store: store, match: m)
            : ScorecardScreen(store: store, match: m);
        break;

      case 'completed':
        screen = ScorecardScreen(store: store, match: m);

        break;

      default:

        // upcoming / noResult / cancelled -> detail screen (never the

        // scorecard; that was the red-screen routing bug).

        screen = FixtureDetailScreen(store: store, matchId: m.id);
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    if (!mounted) return;

    setState(() {});

    await _runPlayoffUpdate();
  }

  /// Branded fixture card used by both the league and playoff sections.

  Widget _fixtureCard(Match m, {String? stageOverride}) {
    final title = m.matchTitle.isNotEmpty
        ? m.matchTitle
        : (stageOverride ?? 'League Fixture');

    final subtitle = m.resultText.isNotEmpty
        ? m.resultText
        : '${formatFixtureDate(m.dateIso)}'
              '${m.venue.isNotEmpty ? ' · ${m.venue}' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: ScoreCard(
        onTap: () => _openFixture(m),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,

                    style: const TextStyle(
                      color: kCyan,

                      fontSize: 12,

                      fontWeight: FontWeight.w700,

                      letterSpacing: 0.4,
                    ),
                  ),
                ),

                StatusPill(m.status),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                CaptainAvatar(store: store, teamId: m.teamAId),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    store.teamName(m.teamAId),

                    style: const TextStyle(
                      color: PitchTheme.onSurface,

                      fontWeight: FontWeight.w700,

                      fontSize: 15,
                    ),
                  ),
                ),

                const Text(
                  'vs',

                  style: TextStyle(color: PitchTheme.outline, fontSize: 12),
                ),

                Expanded(
                  child: Text(
                    store.teamName(m.teamBId),

                    textAlign: TextAlign.end,

                    style: const TextStyle(
                      color: PitchTheme.onSurface,

                      fontWeight: FontWeight.w700,

                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                CaptainAvatar(store: store, teamId: m.teamBId),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,

              style: const TextStyle(color: PitchTheme.outline, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateScheduleDialog() async {
    var teamIds = List<String>.from(tournament.teamIds);

    if (teamIds.length < 2) {
      if (store.teams.length >= 2) {
        final confirmed = await showDialog<bool>(
          context: context,

          builder: (c) => AlertDialog(
            title: const Text('Enroll Teams'),

            content: Text(
              'This tournament has ${teamIds.length} teams. '
              'Auto-enroll all ${store.teams.length} registered teams?',
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),

                child: const Text('Cancel'),
              ),

              FilledButton(
                onPressed: () => Navigator.pop(c, true),

                child: const Text('Auto-Enroll'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          tournament.teamIds = store.teams.map((t) => t.id).toList();

          await store.persistTournamentsOnly();

          teamIds = tournament.teamIds;
        } else {
          return;
        }
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add at least 2 teams before generating fixtures.',
            ),
          ),
        );

        return;
      }
    }

    var overs = tournament.oversLimit;

    var doubleRoundRobin = false;

    var ballType = 'Tennis Ball';

    if (!mounted) return;

    final generated = await showDialog<bool>(
      context: context,

      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Generate Fixtures'),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Participating Teams: ${teamIds.length}',

                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: overs,

                  decoration: const InputDecoration(
                    labelText: 'Overs per innings',
                  ),

                  items: [5, 6, 8, 10, 12, 15, 20, 50]
                      .map(
                        (o) =>
                            DropdownMenuItem(value: o, child: Text('$o overs')),
                      )
                      .toList(),

                  onChanged: (v) => setD(() => overs = v ?? 8),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: ballType,

                  decoration: const InputDecoration(labelText: 'Ball type'),

                  items: const [
                    DropdownMenuItem(
                      value: 'Tennis Ball',
                      child: Text('Tennis Ball'),
                    ),

                    DropdownMenuItem(
                      value: 'Leather Ball',
                      child: Text('Leather Ball'),
                    ),

                    DropdownMenuItem(
                      value: 'Tape Ball',
                      child: Text('Tape Ball'),
                    ),
                  ],

                  onChanged: (v) => setD(() => ballType = v ?? 'Tennis Ball'),
                ),

                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,

                  title: const Text('Home & Away (Double Round-Robin)'),

                  value: doubleRoundRobin,

                  onChanged: (v) => setD(() => doubleRoundRobin = v),
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

              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (generated != true) return;

    final fixtures = generateRoundRobinFixtures(
      tournamentId: tournament.id,

      teamIds: teamIds,

      oversLimit: overs,

      ballType: ballType,

      doubleRoundRobin: doubleRoundRobin,
    );

    for (final f in fixtures) {
      await store.upsertMatch(f);
    }

    if (mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated ${fixtures.length} fixtures!')),
      );
    }
  }

  Future<void> _generatePlayoffsDialog() async {
    final existingPlayoffs = playoffMatchesOf(tournament.id, store.matches);

    if (existingPlayoffs.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,

        builder: (c) => AlertDialog(
          title: const Text('Playoffs Already Exist'),

          content: Text(
            'This tournament already has ${existingPlayoffs.length} playoff fixture(s). '
            'Do you want to add more playoff fixtures?',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () => Navigator.pop(c, true),

              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    var playoffFormat = 'semis'; // 'semis', 'page', 'direct_final'

    var overs = tournament.oversLimit;

    var ballType = 'Tennis Ball';

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Setup Knockouts / Playoffs'),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Select Playoff Structure:',

                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),

                const SizedBox(height: 8),

                for (final opt in [
                  {
                    'id': 'semis',
                    'title': 'Standard Semifinals & Final',
                    'sub': 'SF1 (1v4), SF2 (2v3), Grand Final',
                  },
                  {
                    'id': 'page',
                    'title': 'IPL / Page Playoff System',
                    'sub': 'Qualifier 1, Eliminator, Qualifier 2, Final',
                  },
                  {
                    'id': 'direct_final',
                    'title': 'Direct Final (Top 2 Teams)',
                    'sub': '1st vs 2nd ranked in points table',
                  },
                ])
                  InkWell(
                    onTap: () => setD(() => playoffFormat = opt['id']!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: playoffFormat == opt['id']
                            ? PitchTheme.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: playoffFormat == opt['id']
                              ? PitchTheme.primary
                              : PitchTheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            playoffFormat == opt['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: playoffFormat == opt['id']
                                ? PitchTheme.primary
                                : PitchTheme.outline,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt['title']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  opt['sub']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PitchTheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: overs,

                  decoration: const InputDecoration(
                    labelText: 'Overs per innings',
                  ),

                  items: [5, 6, 8, 10, 12, 15, 20, 50]
                      .map(
                        (o) =>
                            DropdownMenuItem(value: o, child: Text('$o overs')),
                      )
                      .toList(),

                  onChanged: (v) => setD(() => overs = v ?? 8),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: ballType,

                  decoration: const InputDecoration(labelText: 'Ball type'),

                  items: const [
                    DropdownMenuItem(
                      value: 'Tennis Ball',
                      child: Text('Tennis Ball'),
                    ),

                    DropdownMenuItem(
                      value: 'Leather Ball',
                      child: Text('Leather Ball'),
                    ),

                    DropdownMenuItem(
                      value: 'Tape Ball',
                      child: Text('Tape Ball'),
                    ),
                  ],

                  onChanged: (v) => setD(() => ballType = v ?? 'Tennis Ball'),
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

              child: const Text('Create Playoffs'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final now = DateTime.now();

    final fixtures = <Match>[];

    Match buildPlayoffMatch(String stage, String title, int dayOffset) {
      return Match(
        id: 'playoff_${tournament.id}_${stage}_${DateTime.now().millisecondsSinceEpoch}_${fixtures.length}',

        tournamentId: tournament.id,

        teamAId: '',

        teamBId: '',

        xiA: const [],

        xiB: const [],

        oversLimit: overs,

        ballsPerOver: 6,

        venue: tournament.venue,

        dateIso: now.add(Duration(days: dayOffset)).toIso8601String(),

        stage: stage,

        matchTitle: title,

        ballType: ballType,

        status: 'upcoming',

        tossWinnerId: '',

        tossDecision: 'bat',
      );
    }

    if (playoffFormat == 'semis') {
      fixtures.add(buildPlayoffMatch('semifinal1', 'Semi Final 1', 1));

      fixtures.add(buildPlayoffMatch('semifinal2', 'Semi Final 2', 1));

      fixtures.add(buildPlayoffMatch('final', 'Grand Final', 2));
    } else if (playoffFormat == 'page') {
      fixtures.add(buildPlayoffMatch('qualifier1', 'Qualifier 1', 1));

      fixtures.add(buildPlayoffMatch('eliminator', 'Eliminator', 1));

      fixtures.add(buildPlayoffMatch('qualifier2', 'Qualifier 2', 2));

      fixtures.add(buildPlayoffMatch('final', 'Grand Final', 3));
    } else if (playoffFormat == 'direct_final') {
      fixtures.add(buildPlayoffMatch('final', 'Grand Final', 1));
    }

    for (final f in fixtures) {
      await store.upsertMatch(f);
    }

    await _runPlayoffUpdate();

    if (mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${fixtures.length} playoff fixtures!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = leaguePointsTable(tournament, store.matches);

    final qualifierIds = _qualifierIds;

    final leagueFixtures =
        store.matches
            .where(
              (m) => m.tournamentId == tournament.id && m.stage == 'league',
            )
            .toList()
          ..sort((a, b) => a.dateIso.compareTo(b.dateIso));

    final playoffFixtures = playoffMatchesOf(tournament.id, store.matches);

    return DefaultTabController(
      length: 3,

      // v1.4.5: tab ORDER is Fixtures, Points Table, Stats, and the

      // screen opens on Fixtures (index 0). Switching between tabs

      // still works as before, and no tab state is persisted

      // anywhere, so nothing else is affected.
      initialIndex: 0,

      child: Scaffold(
        appBar: AppBar(
          title: Text(tournament.name),

          actions: [
            if (AuthService().isLoggedIn)
              IconButton(
                icon: Icon(
                  tournament.published ? Icons.public : Icons.public_off,

                  color: tournament.published ? kGreen : null,
                ),

                tooltip: tournament.published
                    ? 'Published — tap to unpublish'
                    : 'Publish (public, view-only)',

                onPressed: _togglePublish,
              ),

            IconButton(
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Tournament Draft',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DraftListScreen(
                    store: store,
                    initialTournamentId: tournament.id,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),

              tooltip: 'Share points table',

              // v1.1.7: shareable points-table image from real standings.
              onPressed: () =>
                  sharePointsTableImage(context, store, tournament),
            ),

            IconButton(
              icon: const Icon(Icons.delete_outline),

              onPressed: () async {
                if (tournament.published) {
                  PublishService().deletePublishedDoc(tournament.id);
                }

                await store.deleteTournament(tournament.id);

                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],

          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fixtures'),

              Tab(text: 'Points Table'),

              Tab(text: 'Stats'),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (!await requireSignedInAction(context, store,
                actionLabel: 'create tournament fixtures')) {
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,

              MaterialPageRoute(
                builder: (_) =>
                    MatchSetupScreen(store: store, tournamentId: tournament.id),
              ),
            ).then((_) => setState(() {}));
          },

          icon: const Icon(Icons.add),

          label: const Text('New fixture'),
        ),

        body: TabBarView(
          children: [
            // Fixtures — league and playoffs, with status-based routing
            ListView(
              padding: const EdgeInsets.all(10),

              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const SectionHeader('League Fixtures'),

                    TextButton.icon(
                      icon: const Icon(Icons.auto_mode, size: 16),

                      label: const Text('Auto Fixtures'),

                      onPressed: () => _generateScheduleDialog(),
                    ),
                  ],
                ),

                if (leagueFixtures.isEmpty)
                  Column(
                    children: [
                      const EmptyState(
                        icon: Icons.event_note,

                        title: 'No league fixtures',

                        subtitle:
                            'Use + to create manually, or generate automatically.',
                      ),

                      const SizedBox(height: 8),

                      FilledButton.icon(
                        icon: const Icon(Icons.auto_mode),

                        label: const Text('Generate Round-Robin Schedule'),

                        onPressed: () => _generateScheduleDialog(),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),

                for (final m in leagueFixtures) _fixtureCard(m),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const SectionHeader('Playoffs'),

                    TextButton.icon(
                      icon: const Icon(Icons.emoji_events_outlined, size: 16),

                      label: const Text('Auto Knockouts'),

                      onPressed: () => _generatePlayoffsDialog(),
                    ),
                  ],
                ),

                if (playoffFixtures.isEmpty)
                  Column(
                    children: [
                      const EmptyState(
                        icon: Icons.emoji_events_outlined,

                        title: 'No playoff fixtures',

                        subtitle:
                            'Semifinals and the final appear here once added.',
                      ),

                      const SizedBox(height: 8),

                      FilledButton.icon(
                        icon: const Icon(Icons.emoji_events_outlined),

                        label: const Text('Setup Knockouts / Playoffs'),

                        onPressed: () => _generatePlayoffsDialog(),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),

                for (final m in playoffFixtures)
                  _fixtureCard(m, stageOverride: stageLabel(m.stage)),

                const SizedBox(height: 70),
              ],
            ),

            // Points table (ICC NRR) with playoff qualification badges
            ListView(
              padding: const EdgeInsets.all(10),

              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),

                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,

                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calculate_outlined, size: 18),

                          label: const Text('Qualification Scenarios'),

                          onPressed: () => Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => QualificationChancesScreen(
                                store: store,

                                initialTournamentId: tournament.id,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        OutlinedButton.icon(
                          icon: const Icon(Icons.functions_outlined, size: 18),

                          label: const Text('NRR Calculator'),

                          onPressed: () => Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => NrrCalculatorScreen(
                                store: store,

                                initialTournamentId: tournament.id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (qualifierIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),

                    child: Row(
                      children: [
                        _qualificationFinal
                            ? const QBadge()
                            : const QBadge(provisional: true),

                        const SizedBox(width: 8),

                        Text(
                          _qualificationFinal
                              ? 'Qualified for the playoffs'
                              : 'Q* = provisional qualification (mathematically guaranteed)',

                          style: const TextStyle(
                            color: kGold,

                            fontSize: 12,

                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,

                  child: DataTable(
                    columnSpacing: 12,

                    columns: const [
                      DataColumn(label: Text('#')),

                      DataColumn(label: Text('Team')),

                      DataColumn(label: Text('P')),

                      DataColumn(label: Text('W')),

                      DataColumn(label: Text('L')),

                      DataColumn(label: Text('T')),

                      DataColumn(label: Text('NR')),

                      DataColumn(label: Text('Pts')),

                      DataColumn(label: Text('NRR')),

                      DataColumn(label: Text('Adj')),
                    ],

                    rows: [
                      for (var i = 0; i < rows.length; i++)
                        DataRow(
                          color: qualifierIds.contains(rows[i].teamId)
                              ? WidgetStateProperty.all(
                                  kGold.withValues(alpha: 0.10),
                                )
                              : null,

                          cells: [
                            DataCell(Text('${i + 1}')),

                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,

                                children: [
                                  Text(store.teamName(rows[i].teamId)),

                                  if (qualifierIds.contains(
                                    rows[i].teamId,
                                  )) ...[
                                    const SizedBox(width: 6),

                                    _qualificationFinal
                                        ? const QBadge()
                                        : const QBadge(provisional: true),
                                  ],

                                  // Manual-row marker (v1.4.4): a gold

                                  // pencil means this row is edited.
                                  if (tournament.pointsTableOverrides
                                      .containsKey(rows[i].teamId)) ...[
                                    const SizedBox(width: 6),

                                    const Icon(
                                      Icons.edit,

                                      size: 14,
                                      color: kGold,
                                    ),
                                  ],

                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_note_outlined,

                                      size: 18,
                                    ),

                                    tooltip: 'Edit points row',

                                    onPressed: () =>
                                        _editPointsRow(context, rows[i]),
                                  ),
                                ],
                              ),

                              onTap: () => _editPointsRow(context, rows[i]),
                            ),

                            DataCell(Text('${rows[i].played}')),

                            DataCell(Text('${rows[i].won}')),

                            DataCell(Text('${rows[i].lost}')),

                            DataCell(Text('${rows[i].tied}')),

                            DataCell(Text('${rows[i].noResult}')),

                            DataCell(
                              Text(
                                '${rows[i].points}',

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,

                                  color: kCyan,
                                ),
                              ),
                            ),

                            DataCell(Text(rows[i].nrr.toStringAsFixed(3))),

                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),

                                tooltip: 'Custom points adjustment',

                                onPressed: () =>
                                    _editAdjustment(context, rows[i].teamId),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(top: 8),

                  child: Text(
                    'NRR uses the ICC rule: aggregate runs per over scored minus conceded across the tournament; a team bowled out is deemed to have faced its full overs quota.',

                    style: TextStyle(fontSize: 11, color: PitchTheme.outline),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 12),

                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (_) => NrrCalculatorScreen(store: store),
                      ),
                    ),

                    icon: const Icon(Icons.calculate),

                    label: const Text('NRR Calculator'),
                  ),
                ),
              ],
            ),

            // Tournament stats (Stumps-style leaderboards)
            TournamentStatsTab(store: store, tournament: tournament),
          ],
        ),
      ),
    );
  }

  /// Manual points-table row editor (v1.4.4, delta semantics since

  /// v1.4.7): the dialog shows the DISPLAYED row (computed + delta)

  /// and Save stores the difference between the typed values and

  /// the computed row as the new delta, so later matches keep

  /// flowing into the edited row. Reset removes the override so

  /// the row goes back to computed values. Counts parse leniently:

  /// a blank, invalid or negative count saves as 0 — never a

  /// refusal. NRR accepts any decimal (negative included).

  Future<void> _editPointsRow(BuildContext context, PointsRow row) async {
    final teamId = row.teamId;

    final existing = tournament.pointsTableOverrides[teamId];

    TextEditingController ctrl(String v) => TextEditingController(text: v);

    // Pre-fill from the DISPLAYED row: under delta semantics the

    // stored override is a delta, not a display value, so reading

    // it here would show the correction instead of the row.

    final cP = ctrl('${row.played}');

    final cW = ctrl('${row.won}');

    final cL = ctrl('${row.lost}');

    final cT = ctrl('${row.tied}');

    final cNR = ctrl('${row.noResult}');

    final cPts = ctrl('${row.points}');

    final cNrr = ctrl(row.nrr.toStringAsFixed(3));

    try {
      final action = await showDialog<String>(
        context: context,

        builder: (c) => AlertDialog(
          title: Text('Edit points row — ${store.teamName(teamId)}'),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                _rowField(cP, 'P (played)'),

                _rowField(cW, 'W (won)'),

                _rowField(cL, 'L (lost)'),

                _rowField(cT, 'T (tied)'),

                _rowField(cNR, 'NR (no result)'),

                _rowField(cPts, 'Pts (points)'),

                _rowField(cNrr, 'NRR (decimal)', decimal: true),

                const SizedBox(height: 8),

                const Text(
                  'Counts save as 0 when blank, invalid or negative. '
                  'NRR accepts any decimal. The row is marked with a '
                  'gold pencil while edited.',

                  style: TextStyle(fontSize: 11, color: PitchTheme.outline),
                ),
              ],
            ),
          ),

          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'reset'),

                child: const Text('Reset'),
              ),

            TextButton(
              onPressed: () => Navigator.pop(c, null),

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () => Navigator.pop(c, 'save'),

              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (action == 'reset') {
        // v1.4.5 action feedback: a failed save reverts the

        // in-memory change, so the display never claims a save

        // that did not land on disk.

        final prev = tournament.pointsTableOverrides[teamId];

        tournament.pointsTableOverrides.remove(teamId);

        final saved = await store.persistTournamentsOnly();

        if (mounted) {
          if (!saved && prev != null) {
            tournament.pointsTableOverrides[teamId] = prev;
          }

          setState(() {});

          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? 'Points override removed.'
                    : 'Remove failed — try again.',
              ),
            ),
          );
        }
      } else if (action == 'save') {
        int count(TextEditingController ctrl) {
          final v = int.tryParse(ctrl.text.trim());

          if (v == null || v < 0) return 0;

          return v;
        }

        final nrr = double.tryParse(cNrr.text.trim()) ?? 0;

        final prev = tournament.pointsTableOverrides[teamId];

        // v1.4.7: store the DELTA between the typed (displayed)

        // values and the computed row — never the typed values

        // themselves — so later matches keep updating this row.

        // Computed WITHOUT overrides but WITH pointsAdjustments,

        // matching the baseline the display uses.

        PointsRow? computed;

        for (final r in computePointsTable(
          tournament.id,

          tournament.teamIds,

          store.matches.where((m) => m.stage == 'league').toList(),

          pointsAdjustments: tournament.pointsAdjustments,
        )) {
          if (r.teamId == teamId) computed = r;
        }

        final base =
            computed ??
            PointsRow(teamId); // no matches yet: computed is all zero

        tournament.pointsTableOverrides[teamId] = PointsTableOverride(
          played: count(cP) - base.played,

          won: count(cW) - base.won,

          lost: count(cL) - base.lost,

          tied: count(cT) - base.tied,

          noResult: count(cNR) - base.noResult,

          points: count(cPts) - base.points,

          nrr: nrr - base.nrr,
        );

        tournament.overridesDeltaMigrated = true;

        final saved = await store.persistTournamentsOnly();

        if (mounted) {
          if (!saved) {
            if (prev != null) {
              tournament.pointsTableOverrides[teamId] = prev;
            } else {
              tournament.pointsTableOverrides.remove(teamId);
            }
          }

          setState(() {});

          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? 'Points table saved.'
                    : 'Points save failed — try again.',
              ),
            ),
          );
        }
      }
    } finally {
      for (final c in [cP, cW, cL, cT, cNR, cPts, cNrr]) {
        c.dispose();
      }
    }
  }

  Widget _rowField(
    TextEditingController ctrl,
    String label, {
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),

      child: TextField(
        controller: ctrl,

        keyboardType: decimal
            ? const TextInputType.numberWithOptions(signed: true, decimal: true)
            : TextInputType.number,

        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _editAdjustment(BuildContext context, String teamId) async {
    final ctrl = TextEditingController(
      text: '${tournament.pointsAdjustments[teamId] ?? 0}',
    );

    final ok = await showDialog<bool>(
      context: context,

      builder: (c) => AlertDialog(
        title: Text('Custom points — ${store.teamName(teamId)}'),

        content: TextField(
          controller: ctrl,

          keyboardType: const TextInputType.numberWithOptions(signed: true),

          decoration: const InputDecoration(
            labelText: 'Adjustment (added to earned points)',
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
    );

    if (ok == true) {
      final v = int.tryParse(ctrl.text) ?? 0;

      // v1.4.5 action feedback: revert on a failed save so the

      // display never claims a save that did not land on disk.

      final prev = tournament.pointsAdjustments[teamId];

      if (v == 0) {
        tournament.pointsAdjustments.remove(teamId);
      } else {
        tournament.pointsAdjustments[teamId] = v;
      }

      final saved = await store.persistTournamentsOnly();

      if (context.mounted) {
        if (!saved) {
          if (prev != null) {
            tournament.pointsAdjustments[teamId] = prev;
          } else {
            tournament.pointsAdjustments.remove(teamId);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Points adjustment saved.'
                  : 'Adjustment save failed — try again.',
            ),
          ),
        );
      }

      if (mounted) setState(() {});
    }
  }
}
