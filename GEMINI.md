# 60Score / STUMPS — Development Rules & Pitch Dynamic Design System

## Project Context & Mission
60Score (rebranding to STUMPS) is an offline-first cricket scoring and tournament management application built with Flutter. The entire UI is undergoing a modernization overhaul following the modern sports telemetry design ("Pitch Dynamic").

---

## 🎨 Global UI Design System: Pitch Dynamic

### Color Tokens
Always use tokens from `package:cricket_scorer_app/core/theme/pitch_theme.dart`:
- `PitchTheme.surface` (`#F9F9FF`): Main page and screen background.
- `PitchTheme.surfaceContainerLowest` (`#FFFFFF`): Cards, dialogs, sheets, bottom navigation.
- `PitchTheme.surfaceContainerLow` (`#F1F3FF`): Search bars, input fills, subtle containers.
- `PitchTheme.surfaceContainer` (`#E9EDFF`): Badge tracks, progress bar backgrounds.
- `PitchTheme.primary` (`#00261B`): Deep forest cricket green for primary buttons and banners.
- `PitchTheme.primaryContainer` (`#0B3D2E`): Pine container for telemetry equation cards & dark chips.
- `PitchTheme.secondary` (`#006D36`): Vibrant emerald green for links, target meters, active states.
- `PitchTheme.secondaryContainer` (`#7CF8A1`): Mint badge container.
- `PitchTheme.onSecondaryContainer` (`#007239`): Dark green text on mint badges.
- `PitchTheme.tertiaryFixed` (`#BBF540`): Electric neon lime accent for high-priority badges & CRR/RRR.
- `PitchTheme.onSurface` (`#141B2B`): Bold dark text for headings and scores.
- `PitchTheme.onSurfaceVariant` (`#414944`): Subdued charcoal text.
- `PitchTheme.outline` (`#717974`): Muted gray for timestamps, overs, captions.
- `PitchTheme.outlineVariant` (`#C0C8C3`): Card and avatar borders.
- `PitchTheme.error` (`#BA1A1A`): Cricket red for live pulse and wickets.

---

## 📱 Strict Responsive Layout Rules
1. **NO Hardcoded Fixed Widths or Heights:** Never hardcode rigid pixel dimensions like `width: 380` or `height: 800`.
2. **Dynamic Clamped Sizing:** Use `MediaQuery.sizeOf(context).width` with `.clamp(min, max)` for carousels and cards.
3. **Zero Overflow Principle:** Wrap all text in `Expanded` or `Flexible` with `maxLines` and `TextOverflow.ellipsis`.
4. **Smooth Scrolling:** All horizontal rows must use `SingleChildScrollView(scrollDirection: Axis.horizontal, physics: BouncingScrollPhysics())`. Vertical screen bodies must use `SingleChildScrollView(physics: BouncingScrollPhysics())`.

---

## 🔗 Architecture & Functional Integrity
- The app is offline-first: local SQLite/SharedPreferences operations must never crash when offline.
- Every new UI element must cleanly bind to the underlying domain `Store` models (`Match`, `Tournament`, `Team`, `Player`, `InningsState`).
- Keep `ALL_SCREENS_COMPREHENSIVE_GUIDE.md` updated as screens are modernized.
