import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/core/constants/preset_team_logos.dart';
import 'package:cricket_scorer_app/core/constants/preset_player_avatars.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Opens a bottom sheet for selecting a pre-made team logo
Future<PresetTeamLogo?> showTeamLogoPicker(
  BuildContext context, {
  String? currentLogoId,
}) {
  return showModalBottomSheet<PresetTeamLogo>(
    context: context,
    backgroundColor: PitchTheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PitchTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Team Emblem',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: PitchTheme.slateHeading,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PitchTheme.sportsEmeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '12 PRESETS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: PitchTheme.sportsEmerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a sports crest for your team. This emblem will appear on match scorecards and live feed.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: PitchTheme.slateSubdued,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 340,
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: TeamPresetCatalog.presets.length,
                  itemBuilder: (context, idx) {
                    final item = TeamPresetCatalog.presets[idx];
                    final isSelected = item.id == currentLogoId;

                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(item),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? PitchTheme.sportsEmeraldLight
                              : PitchTheme.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? PitchTheme.sportsEmerald
                                : PitchTheme.hairlineBorder,
                            width: isSelected ? 1.8 : 0.9,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: PitchTheme.sportsEmerald.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PresetTeamLogoBadge(
                              logoKey: item.id,
                              teamName: item.name,
                              size: 42,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                color: PitchTheme.slateHeading,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.defaultCode,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: PitchTheme.slateSubdued,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Opens a bottom sheet for selecting a pre-made player avatar
Future<PresetPlayerAvatar?> showPlayerAvatarPicker(
  BuildContext context, {
  String? currentAvatarId,
}) {
  return showModalBottomSheet<PresetPlayerAvatar>(
    context: context,
    backgroundColor: PitchTheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PitchTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Player Avatar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: PitchTheme.slateHeading,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PitchTheme.sportsEmeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '10 AVATARS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: PitchTheme.sportsEmerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a cricket personality emblem for the player profile.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: PitchTheme.slateSubdued,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 320,
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: PlayerPresetCatalog.presets.length,
                  itemBuilder: (context, idx) {
                    final item = PlayerPresetCatalog.presets[idx];
                    final isSelected = item.id == currentAvatarId;

                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(item),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? PitchTheme.sportsEmeraldLight
                              : PitchTheme.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? PitchTheme.sportsEmerald
                                : PitchTheme.hairlineBorder,
                            width: isSelected ? 1.8 : 0.9,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [item.primaryColor, item.secondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  color: item.iconColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: PitchTheme.slateHeading,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.roleDescription,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: PitchTheme.slateSubdued,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
