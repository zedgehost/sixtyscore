# Pitch Dynamic — Official Global Design System & UI Rules
**Rule Priority:** Mandatory across all 27 application screens and any new widgets.
**Effective Date:** 2026-11-08

---

## 🎨 1. Global Color Tokens & Semantics

Every screen, dialog, sheet, and component in the app must strictly use the **Pitch Dynamic** palette defined in [`PitchTheme`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/core/theme/pitch_theme.dart):

| Token Name | Hex Code | Semantic Role & Allowed Usage |
| :--- | :--- | :--- |
| `PitchTheme.surface` | `#F9F9FF` | **Global Page / Scaffold Background** (crisp soft sports off-white). No screen may use pure dark navy anymore. |
| `PitchTheme.surfaceContainerLowest` | `#FFFFFF` | **Cards, Dialogs, Bottom Sheets & Navigation Bars** (pure white surface with subtle elevation shadow). |
| `PitchTheme.surfaceContainerLow` | `#F1F3FF` | **Search fields, pill backgrounds, target callouts, and secondary containers**. |
| `PitchTheme.surfaceContainer` | `#E9EDFF` | **Badge backgrounds, progress bar tracks, and table headers**. |
| `PitchTheme.surfaceVariant` | `#DCE2F7` | **Muted indicators, unselected states, and subtle dividers**. |
| `PitchTheme.primary` | `#00261B` | **Deep Forest Cricket Green**: Primary action buttons, primary branding, and hero action cards. |
| `PitchTheme.primaryContainer` | `#0B3D2E` | **Dark Pine Container**: Live equation pill backgrounds, active filter pills, and dark badge containers. |
| `PitchTheme.onPrimary` | `#FFFFFF` | Text/icons on `primary` and `primaryContainer`. |
| `PitchTheme.onPrimaryContainer` | `#79A894` | Muted mint text/captions inside dark pine containers. |
| `PitchTheme.secondary` | `#006D36` | **Vibrant Pitch Emerald**: Accent links (`View All →`, `Recap →`), success states, active navigation icons, and target meters. |
| `PitchTheme.secondaryContainer` | `#7CF8A1` | **Mint Badge Container**: Category tags, stage badges, winning team banners, and league pills. |
| `PitchTheme.onSecondaryContainer` | `#007239` | High-contrast dark green text inside mint badge containers. |
| `PitchTheme.tertiaryFixed` | `#BBF540` | **Electric Neon Lime**: High-visibility accent badges (`+ NEW`, `PRO`, CRR/RRR highlights, active pill text). |
| `PitchTheme.onSurface` | `#141B2B` | **Primary Text Color**: Headings, scores, player names, and prominent figures (deep dark charcoal/slate). |
| `PitchTheme.onSurfaceVariant` | `#414944` | **Secondary Text Color**: Subheadings, secondary figures, and table data. |
| `PitchTheme.outline` | `#717974` | **Muted Outline**: Timestamps, over indicators, overs remaining, and inactive icons. |
| `PitchTheme.outlineVariant` | `#C0C8C3` | **Card & Avatar Borders**: Subtle border strokes (`1.0px` or `1.5px`) with low alpha. |
| `PitchTheme.error` | `#BA1A1A` | **Cricket Red**: Live pulsing indicators, wickets lost, and destructive actions. |

---

## 📱 2. Strict Responsive Layout Rules (Zero Hardcoded Widths/Heights)

1. **NO Fixed Screen Widths or Rigid Container Dimensions:**
   - ❌ Never write `width: 380`, `width: 400`, `width: 800` on parent wrappers or full-width elements.
   - ❌ Never write `height: 800` or rigid fixed page heights.
   - ✅ Always use `Expanded`, `Flexible`, `LayoutBuilder`, or `MediaQuery.sizeOf(context)`.

2. **Horizontal Carousels & Cards:**
   - Card widths must always be computed dynamically relative to the viewport width:
     $$\text{cardWidth} = (\text{MediaQuery.sizeOf(context).width} \times 0.86).\text{clamp}(280.0, 360.0)$$
   - This ensures a card never overflows on a 320dp small phone and gracefully caps on tablets.

3. **Horizontal & Vertical Scrolling:**
   - Every horizontal card row must use `SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics())` or `ListView.builder`.
   - Every screen body must use `SingleChildScrollView(physics: const BouncingScrollPhysics())` with `SafeArea(top: true, bottom: false)` to prevent device notch/cutout overlap.

4. **Zero RenderFlex Overflow Guarantee:**
   - Every text field inside horizontal rows (`Row`, `ListTile`, headers) must be wrapped in `Expanded` or `Flexible` and specify `maxLines` with `TextOverflow.ellipsis`.
   - Dynamic badges and small metrics must be wrapped in `FittedBox(fit: BoxFit.scaleDown)` where appropriate.

---

## 🧩 3. Component & Widget Specifications

1. **Top App Bar / Header:**
   - Clean sticky header with `#FFFFFF` background, subtle shadow (`0 2px 8px rgba(0,0,0,0.04)`), and height `60-64dp`.
   - Left brand identifier with icon container, centered/flexible search bar pill (`#F1F3FF`), and right circular action buttons (notification bell + user avatar).

2. **Section Badges & Headers:**
   - Prominent badges (e.g. `LIVE & RECENT MATCHES`) must be centered in their section headers with clean padding (`horizontal: 12-14, vertical: 5-6`), rounded pill border (`Radius.circular(20)`), and accompanied by clean right-aligned action links (`VIEW ALL →`).

3. **Buttons & Actions:**
   - **Primary Action (High Prominence):** `PitchTheme.primary` (`#00261B`) with bold white text and rounded corners (`14-16dp`).
   - **Secondary Action (League / Pitch):** `PitchTheme.secondary` (`#006D36`) with white text and rounded corners (`14-16dp`).
   - **Pills & Chips:** Rounded 20dp capsules with high-contrast text (`fontSize: 10-12, fontWeight: FontWeight.w800`).

4. **Match & Tournament Cards:**
   - Card background: `#FFFFFF` (`PitchTheme.surfaceContainerLowest`).
   - Corner radius: `14-16dp`.
   - Elevation: Low subtle ambient shadow (`PitchTheme.cardShadow`).
   - Accent vertical indicator: `4-5dp` left border strip indicating match status or tournament tier.
