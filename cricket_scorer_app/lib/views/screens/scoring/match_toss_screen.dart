import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/views/screens/scoring/match_lineups_screen.dart';

class MatchTossScreen extends StatefulWidget {
  final Store store;
  final MatchDraft draft;

  const MatchTossScreen({
    super.key,
    required this.store,
    required this.draft,
  });

  @override
  State<MatchTossScreen> createState() => _MatchTossScreenState();
}

class _MatchTossScreenState extends State<MatchTossScreen> {
  late String currentWinnerId;
  late String currentDecision;

  Store get store => widget.store;
  MatchDraft get draft => widget.draft;

  @override
  void initState() {
    super.initState();
    currentWinnerId = draft.tossWinnerId ?? draft.teamAId;
    currentDecision = draft.tossDecision.isNotEmpty ? draft.tossDecision : 'bat';
  }

  String _getTeamInitials(String name) {
    if (name.trim().isEmpty) return 'T';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _onContinueToLineups() {
    draft.tossWinnerId = currentWinnerId;
    draft.tossDecision = currentDecision;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchLineupsScreen(
          store: store,
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamA = store.teamById(draft.teamAId);
    final teamB = store.teamById(draft.teamBId);

    final teamAName = teamA?.name ?? 'Team A';
    final teamBName = teamB?.name ?? 'Team B';

    final teamAInitials = _getTeamInitials(teamAName);
    final teamBInitials = _getTeamInitials(teamBName);

    final winnerTeam = currentWinnerId == draft.teamAId ? teamA : teamB;
    final winnerName = winnerTeam?.name ?? 'Winner';
    final decisionVerb = currentDecision == 'bat' ? 'bat first' : 'bowl first';

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // Top App Bar / Header
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
                        'Match Toss',
                        style: TextStyle(
                          color: PitchTheme.primary,
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
                      color: PitchTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.toll,
                          size: 16,
                          color: PitchTheme.secondary,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'STEP 3 OF 4',
                          style: TextStyle(
                            color: PitchTheme.secondary,
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
            ),

            // -----------------------------------------------------------------
            // Body Content
            // -----------------------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SECTION 1: WHO WON THE TOSS?
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              '1. Who won the toss?',
                              style: TextStyle(
                                color: PitchTheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Select winner',
                              style: TextStyle(
                                color: PitchTheme.outline,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2-Column Team Cards
                        Row(
                          children: [
                            // Team A Card
                            Expanded(
                              child: _buildTeamTossCard(
                                teamId: draft.teamAId,
                                teamName: teamAName,
                                initials: teamAInitials,
                                isWinner: currentWinnerId == draft.teamAId,
                                onTap: () {
                                  setState(() => currentWinnerId = draft.teamAId);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Team B Card
                            Expanded(
                              child: _buildTeamTossCard(
                                teamId: draft.teamBId,
                                teamName: teamBName,
                                initials: teamBInitials,
                                isWinner: currentWinnerId == draft.teamBId,
                                onTap: () {
                                  setState(() => currentWinnerId = draft.teamBId);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // SECTION 2: WHAT DID THEY DECIDE?
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '2. What did they decide?',
                              style: TextStyle(
                                color: PitchTheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose batting or bowling first',
                              style: TextStyle(
                                color: PitchTheme.outline,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 2-Column Decision Cards (Bat / Bowl)
                        Row(
                          children: [
                            // Bat First Card
                            Expanded(
                              child: _buildDecisionCard(
                                title: 'Bat First',
                                icon: Icons.sports_cricket,
                                isSelected: currentDecision == 'bat',
                                onTap: () {
                                  setState(() => currentDecision = 'bat');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Bowl First Card
                            Expanded(
                              child: _buildDecisionCard(
                                title: 'Bowl First',
                                icon: Icons.sports_baseball,
                                isSelected: currentDecision == 'bowl',
                                onTap: () {
                                  setState(() => currentDecision = 'bowl');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // SECTION 3: OFFICIAL TOSS RESULT SUMMARY BOX
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: PitchTheme.secondaryContainer
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: PitchTheme.secondaryContainer,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: PitchTheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.toll,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'OFFICIAL TOSS RESULT',
                                          style: TextStyle(
                                            color:
                                                PitchTheme.onSecondaryContainer,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: PitchTheme.secondary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$winnerName won the toss and elected to $decisionVerb',
                                      style: const TextStyle(
                                        color: PitchTheme.onSecondaryContainer,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // SECTION 4: CONTINUE TO LINEUPS CTA
                        ElevatedButton(
                          onPressed: _onContinueToLineups,
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
                                'Continue to Lineups',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You can review playing XI on the next step',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: PitchTheme.outline,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
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
  // Team Toss Card (Ali Panthers vs AB Knights)
  // ---------------------------------------------------------------------------
  Widget _buildTeamTossCard({
    required String teamId,
    required String teamName,
    required String initials,
    required bool isWinner,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isWinner
              ? PitchTheme.primaryContainer
              : PitchTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWinner
                ? PitchTheme.primaryContainer
                : PitchTheme.surfaceContainerLow,
            width: 1.5,
          ),
          boxShadow: isWinner
              ? [
                  BoxShadow(
                    color: PitchTheme.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : PitchTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isWinner
                        ? Colors.white
                        : PitchTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: isWinner
                            ? PitchTheme.primary
                            : PitchTheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Icon(
                  isWinner
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isWinner
                      ? PitchTheme.tertiaryFixed
                      : PitchTheme.outlineVariant,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              teamName,
              style: TextStyle(
                color: isWinner ? Colors.white : PitchTheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isWinner
                    ? Colors.white.withValues(alpha: 0.15)
                    : PitchTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isWinner ? 'TOSS WINNER' : 'AWAITING',
                style: TextStyle(
                  color: isWinner
                      ? PitchTheme.tertiaryFixed
                      : PitchTheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Decision Card (Bat First / Bowl First)
  // ---------------------------------------------------------------------------
  Widget _buildDecisionCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? PitchTheme.primaryContainer
              : PitchTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? PitchTheme.primaryContainer
                : PitchTheme.surfaceContainerLow,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PitchTheme.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : PitchTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.12)
                    : PitchTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? PitchTheme.tertiaryFixed
                    : PitchTheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : PitchTheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? PitchTheme.tertiaryFixed
                  : PitchTheme.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
