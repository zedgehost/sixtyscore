import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/core/constants/preset_team_logos.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Shared ICC/Cricbuzz-style 3-column broadcast match card used across
/// HomeScreen, PublicMatchesScreen ("View All"), and CompletedMatchesScreen.
class BroadcastMatchCard extends StatelessWidget {
  final String headerTitle;
  final String teamAName;
  final String teamACode;
  final String teamALogo;
  final String? teamARuns;
  final String? teamAOvers;
  final bool isTeamABatting;

  final String teamBName;
  final String teamBCode;
  final String teamBLogo;
  final String? teamBRuns;
  final String? teamBOvers;
  final bool isTeamBBatting;

  final bool isLive;
  final String statusLabel;
  final String footerText;
  final Animation<double>? pulseAnimation;
  final bool isOpening;
  final double? width;
  final VoidCallback? onTap;
  final Widget? headerTrailing;

  const BroadcastMatchCard({
    super.key,
    required this.headerTitle,
    required this.teamAName,
    required this.teamACode,
    required this.teamALogo,
    this.teamARuns,
    this.teamAOvers,
    this.isTeamABatting = false,
    required this.teamBName,
    required this.teamBCode,
    required this.teamBLogo,
    this.teamBRuns,
    this.teamBOvers,
    this.isTeamBBatting = false,
    required this.isLive,
    this.statusLabel = 'FT',
    required this.footerText,
    this.pulseAnimation,
    this.isOpening = false,
    this.width,
    this.onTap,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: PitchTheme.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: tournament/match title ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                if (headerTrailing != null) const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    headerTitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PitchTheme.slateSubdued,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                if (isOpening)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PitchTheme.sportsEmerald,
                    ),
                  )
                else
                  ?headerTrailing,
              ],
            ),
          ),

          // ── 3-column showdown body ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: Team A
                Expanded(
                  child: Row(
                    children: [
                      PresetTeamLogoBadge(
                        logoKey: teamALogo,
                        teamName: teamAName,
                        size: 36,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              teamACode,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isTeamABatting
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: PitchTheme.slateHeading,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (teamARuns != null) ...[
                              Text(
                                teamARuns!,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: isTeamABatting
                                      ? PitchTheme.sportsEmerald
                                      : PitchTheme.slateHeading,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (teamAOvers != null)
                                Text(
                                  teamAOvers!,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: PitchTheme.slateSubdued,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ] else
                              const Text(
                                'Yet to bat',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PitchTheme.slateSubdued,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // CENTER: Cricket emblem + LIVE/FT pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PitchTheme.hairlineBorder,
                            width: 0.9,
                          ),
                        ),
                        child: const Icon(
                          Icons.sports_cricket,
                          size: 18,
                          color: PitchTheme.sportsEmerald,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: PitchTheme.liveRedBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: PitchTheme.liveRed.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pulseAnimation != null)
                                RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: pulseAnimation!,
                                    builder: (context, _) => Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: PitchTheme.liveRed.withValues(
                                          alpha: pulseAnimation!.value,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: PitchTheme.liveRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 4),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: PitchTheme.liveRed,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: PitchTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: PitchTheme.slateSubdued,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // RIGHT: Team B
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              teamBCode,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isTeamBBatting
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: PitchTheme.slateHeading,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                            if (teamBRuns != null) ...[
                              Text(
                                teamBRuns!,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: isTeamBBatting
                                      ? PitchTheme.sportsEmerald
                                      : PitchTheme.slateHeading,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                              if (teamBOvers != null)
                                Text(
                                  teamBOvers!,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: PitchTheme.slateSubdued,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                            ] else
                              const Text(
                                'Yet to bat',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PitchTheme.slateSubdued,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.end,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PresetTeamLogoBadge(
                        logoKey: teamBLogo,
                        teamName: teamBName,
                        size: 36,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Footer: equation / result ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: PitchTheme.hairlineBorder, width: 0.9),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              footerText,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isLive
                    ? PitchTheme.slateHeading
                    : PitchTheme.slateSubdued,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpening ? null : onTap,
        borderRadius: BorderRadius.circular(PitchTheme.cardRadius),
        child: width != null ? SizedBox(width: width, child: card) : card,
      ),
    );
  }
}
