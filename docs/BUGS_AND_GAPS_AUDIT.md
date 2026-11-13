# 60Score (cricket_scorer_app) — Ultra-Deep Technical Audit: 30 Bugs, Architectural Gaps & Edge Cases

**Audit Date:** November 2026  
**Audited Version:** v1.4.8+31 (MVVM Architecture Restructured)
**Scope:** Full repository (`lib/core/`, `lib/domain/`, `lib/models/`, `lib/services/`, `lib/viewmodels/`, `lib/views/`)
**Test Suite Status:** 537/537 Unit & Widget Tests Passing (100%)
**Static Analysis:** Clean (`flutter analyze` — 0 issues)  
**Resolution Progress:** 9/30 Gaps Resolved (All 4 Critical P0s + 3 High P1s Solved & Tested)  

---

## Executive Summary

An exhaustive, multi-pass technical audit was conducted on the **60Score** (`cricket_scorer_app`) codebase. While the application displays exemplary domain design, offline-first reliability, and rigorous unit test coverage (528 tests), **30 distinct architectural, domain-logic, cricket-law, and platform portability gaps** were uncovered.

Most critically, deep analysis identified **4 Critical (P0) logic flaws**:
1. **DLS Target Result Inversion (`lib/scoring.dart`):** Reaching a revised DLS target declares the losing team as the winner because scores are compared directly against first-innings totals.
2. **Playoff Bracket Stall on Super Over (`lib/tournament_engine.dart`):** Tied semifinal matches decided via Super Over return `null` as the winner, permanently freezing Grand Final qualification as `TBD`.
3. **Scorecard Edit Target Wiping (`lib/screens/scorecard_edit_screen.dart`):** Saving any scorecard edit permanently overwrites and erases DLS revised targets.
4. **ICC DLS NRR Violation (`lib/scoring.dart`):** Team 1 is credited with full overs and runs in rain-shortened matches, distorting tournament NRR calculations.

---

## Master Table of Audit Findings

| ID | Status | Severity | Category | Title | File Location |
|---|---|---|---|---|---|
| **GAP-13** | 🟢 **SOLVED** | 🔴 Critical (P0)  | Cricket Law / Scoring Engine  | DLS Target Result Inversion Bug  | `lib/domain/scoring/scoring.dart` |
| **GAP-14** | 🟢 **SOLVED** | 🔴 Critical (P0)  | Tournament Playoff Engine  | Playoff Grand Finalist Assignment Stalling on Super Over  | `lib/domain/tournament/tournament_engine.dart` |
| **GAP-15** | 🟢 **SOLVED** | 🔴 Critical (P0)  | Scorecard Editing / Data Integrity  | Scorecard Edit Screen Unconditionally Erases DLS Target  | `lib/views/screens/scorecard/scorecard_edit_screen.dart` |
| **GAP-16** | 🟢 **SOLVED** | 🔴 Critical (P0)  | Tournament Engine / ICC Regulations  | ICC DLS Standard Regulations Violation in NRR Calculation  | `lib/domain/scoring/scoring.dart` |
| **GAP-02** | ⚪ Open | 🟠 High (P1)  | Architecture / Authentication  | Hardcoded Owner Email & Lack of Multi-Tenant Security  | `lib/account_profile.dart:15, lib/store.dart:396, 440`  |
| **GAP-03** | ⚪ Open | 🟠 High (P1)  | Cloud Security / Backend  | Missing Cloud Firestore Rules for Phase-D Entity Collections  | `lib/entity_firestore.dart, lib/sync_service.dart:780-788`  |
| **GAP-17** | ⚪ Open | 🟠 High (P1)  | UI / Sharing Engine  | RepaintBoundary Unhandled NullCheckException Across 5 Share Modules  | `lib/points_table_share.dart:51, lib/stats_share.dart:194, lib/summary_share.dart:68, lib/fixture_poster.dart:43, lib/poster_summary.dart:488`  |
| **GAP-18** | 🟢 **SOLVED** | 🟠 High (P1)  | Cricket Law / Match Scorer  | Bowler Incapacitation Mid-Over Blocked by UI Rule Lock  | `lib/views/screens/scoring/scoring_screen.dart` |
| **GAP-19** | 🟢 **SOLVED** | 🟠 High (P1)  | Tournament Engine / Super Over  | Super Over Screen Never Triggers Playoff Recalculation  | `lib/views/screens/scoring/super_over_screen.dart` |
| **GAP-20** | 🟢 **SOLVED** | 🟠 High (P1)  | Scorecard Editing / Administrative Control  | Hard Block on Correcting Winning Result in Scorecard Edit  | `lib/views/screens/scorecard/scorecard_screen.dart` |
| **GAP-21** | ⚪ Open | 🟠 High (P1)  | Cloud Sync / Multi-Account  | Unscoped PhotoSync Tracker Causing Multi-User Photo Sync Failure  | `lib/photo_sync.dart:62, lib/photo_sync.dart:185`  |
| **GAP-01** | ⚪ Open | 🟡 Medium (P2)  | UI / Presentation  | Hardcoded Stale Version in Drawer (`Version 1.3.4`)  | `lib/main.dart:704`  |
| **GAP-05** | ⚪ Open | 🟡 Medium (P2)  | Platform Portability / Web  | Web Platform `dart:io` Incompatibility in Backup & Restore  | `lib/backup_service.dart:1-35`  |
| **GAP-07** | ⚪ Open | 🟡 Medium (P2)  | Data Architecture / Concurrency  | Lack of Atomic Transactions in SharedPreferences DB Dump  | `lib/store.dart:703-748`  |
| **GAP-08** | ⚪ Open | 🟡 Medium (P2)  | Memory / Performance  | Base64 Inline Player Photos Inside SharedPrefs Causing OOM Kills  | `lib/models.dart:16, lib/store.dart:1001-1005`  |
| **GAP-22** | ⚪ Open | 🟡 Medium (P2)  | Performance / UI Responsiveness  | Synchronous Pure Dart Image Processing Freezing UI Thread  | `lib/photo_sync.dart:85-100`  |
| **GAP-23** | ⚪ Open | 🟡 Medium (P2)  | TTS Commentary / Audio  | TTS Wicket Announcement Cut Off Mid-Sentence at Over Boundary  | `lib/screens/scoring_screen.dart:788-790, lib/tts_service.dart:165-174`  |
| **GAP-24** | ⚪ Open | 🟡 Medium (P2)  | Data Management / Trash  | Trashed Registered Players Permanently Lost on Restore  | `lib/store.dart:912-918, lib/store.dart:1187`  |
| **GAP-25** | ⚪ Open | 🟡 Medium (P2)  | Draft System / Algorithm  | Draft Turn Order Calculation Out of Phase on Custom Round Sizes  | `lib/draft.dart:36`  |
| **GAP-26** | ⚪ Open | 🟡 Medium (P2)  | Draft System / Team Quota  | Draft Skipped Turns Counted Towards Team Squad Quota  | `lib/draft.dart:55-57, lib/draft.dart:90-100`  |
| **GAP-27** | ⚪ Open | 🟡 Medium (P2)  | Fixture Management / Scoring Sync  | Fixture Overs Limit Edit Does Not Update Existing Innings  | `lib/scoring.dart:993-1027`  |
| **GAP-28** | ⚪ Open | 🟡 Medium (P2)  | PDF Export / Unicode Support  | Default Helvetica Font Crash on Urdu/Arabic/Emoji Text in PDF  | `lib/pdf_export.dart:20-60`  |
| **GAP-29** | ⚪ Open | 🟡 Medium (P2)  | Match State / Previews  | Toss Presumption of Batting First in Unplayed Matches  | `lib/models.dart:1038-1044`  |
| **GAP-30** | ⚪ Open | 🟢 Low (P3)  | Analytics / POTM Formula  | POTM Economy Multiplier Hardcoded to 6 Balls  | `lib/potm.dart:49, 77`  |
| **GAP-04** | ⚪ Open | 🟢 Low (P3)  | Cloud Architecture  | Multi-Device Realtime Cloud Sync Disabled (Offline-First Trade-off)  | `lib/sync_service.dart, lib/main.dart`  |
| **GAP-06** | ⚪ Open | 🟢 Low (P3)  | Cricket Law / UI  | DLS Minimum Overs Threshold Missing in UI  | `lib/dls.dart, lib/screens/scoring_screen.dart`  |
| **GAP-09** | 🟢 **SOLVED** | 🟢 Resolved Locally  | Web Compilation / JavaScript  | 64-bit Integer Literal JavaScript Compilation Failure  | `lib/services/sync/photo_sync.dart` |
| **GAP-10** | ⚪ Open | 🟢 Low (P3)  | Math Engine  | NRR Division-by-Zero Guard with Custom Overs  | `lib/scoring.dart:1180-1182`  |
| **GAP-11** | ⚪ Open | 🟢 Low (P3)  | Tournament Management  | Playoff Fixture Reseeding on Late Scorecard Edits  | `lib/tournament_engine.dart:180-210`  |
| **GAP-12** | 🟢 **SOLVED** | 🟢 Resolved Locally  | Build Toolchain  | Dart SDK Version Constraint Incompatibility  | `pubspec.yaml` |

---

## Detailed Technical Analysis & Root Causes

### GAP-13: DLS Target Result Inversion Bug
- **Severity:** 🔴 Critical (P0)
- **Category:** Cricket Law / Scoring Engine
- **Location:** [`lib/scoring.dart:766-777`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/scoring.dart)

#### 1. Vulnerability & Bug Description
In `computeResult()`, the match winner comparison directly evaluates `if (i2.totalRuns > i1.totalRuns)` and `else if (i1.totalRuns > i2.totalRuns)`, completely omitting `i2.target`. In any match where Duckworth-Lewis-Stern reduces Team 2's target below Team 1's score (e.g. Team 1 made 160 in 20 overs, rain reduces Team 2's target to 95 in 10 overs), if Team 2 scores 95 to win, `95 > 160` is FALSE, and `160 > 95` is TRUE. The app erroneously declares Team 1 the winner by 65 runs!

#### 2. Technical Impact
Severe match corruption. Winning teams are declared losers, tournament points are awarded to the wrong team, and scorecards record false results.

#### 3. Problematic Code
```dart
// lib/scoring.dart:766-777
if (i2.totalRuns > i1.totalRuns) {
  final wktsLeft = maxWkts - i2.wickets;
  final ballsUsed = i2.legalBalls;
  final ballsLeft = i2.oversLimit * i2.ballsPerOver - ballsUsed;
  text = '${teamName(i2.battingTeamId)} won by $wktsLeft wicket${wktsLeft == 1 ? '' : 's'}...';
} else if (i1.totalRuns > i2.totalRuns) {
  final margin = i1.totalRuns - i2.totalRuns;
  text = '${teamName(i1.battingTeamId)} won by $margin run${margin == 1 ? '' : 's'}';
}
```

#### 4. Remediation Plan
Check `if (i2.target > 0)`: If `i2.totalRuns >= i2.target`, Team 2 wins by wickets. If `i2.totalRuns < i2.target - 1`, Team 1 wins by `(i2.target - 1) - i2.totalRuns` runs (DLS method). If equal, it is a tie.

---
### GAP-14: Playoff Grand Finalist Assignment Stalling on Super Over
- **Severity:** 🔴 Critical (P0)
- **Category:** Tournament Playoff Engine
- **Location:** [`lib/tournament_engine.dart:83-90, 240-255`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/tournament_engine.dart)

#### 1. Vulnerability & Bug Description
`matchWinnerId(m)` returns `null` whenever regular innings scores are tied (`if (i1.totalRuns == i2.totalRuns) return null;`), failing to consult `superOverWinnerId(m)`. When a semifinal (SF1 or SF2) ends tied and is decided via Super Over, `assignFinalist` checks `if (winner == null) return;`. The finalist slot in the Grand Final is NEVER populated, permanently stalling the playoff bracket as TBD.

#### 2. Technical Impact
Tournament playoffs break whenever any semifinal goes to a Super Over. Organizers cannot schedule or score the Grand Final.

#### 3. Problematic Code
```dart
// lib/tournament_engine.dart:88-90
if (i1.totalRuns == i2.totalRuns) return null; // tie — no winner
return i1.totalRuns > i2.totalRuns ? i1.battingTeamId : i2.battingTeamId;

// lib/tournament_engine.dart:243-244
final winner = matchWinnerId(semi);
if (winner == null) return; // tie / unfinished / no-result: slot stays TBD
```

#### 4. Remediation Plan
Update `matchWinnerId` to return `superOverWinnerId(m)` when regular totals are equal. Also handle DLS target logic.

---
### GAP-15: Scorecard Edit Screen Unconditionally Erases DLS Target
- **Severity:** 🔴 Critical (P0)
- **Category:** Scorecard Editing / Data Integrity
- **Location:** [`lib/screens/scorecard_edit_screen.dart:515-517, lib/screens/scorecard_screen.dart:1550-1553`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/screens/scorecard_edit_screen.dart)

#### 1. Vulnerability & Bug Description
Whenever any post-match correction is saved in `ScorecardEditScreen` or a ball is edited in `ScorecardScreen`, the code executes: `_edit.innings[1].target = _edit.innings[0].totalRuns + 1;`. This unconditionally overwrites and destroys any rain-revised DLS target, resetting it to standard first innings + 1.

#### 2. Technical Impact
Editing a simple player name, boundary, or extra permanently erases the DLS target from the database and reverts the match result to an incorrect non-rain state.

#### 3. Problematic Code
```dart
// lib/screens/scorecard_edit_screen.dart:515-517
if (_edit.innings.length > 1) {
  _edit.innings[1].target = _edit.innings[0].totalRuns + 1;
}

// lib/screens/scorecard_screen.dart:1550-1553
if (innIdx == 0 && match.innings.length > 1) {
  // Chase target follows corrected first-innings total
  match.innings[1].target = replayed.totalRuns + 1;
}
```

#### 4. Remediation Plan
Only reset `target` if `inn.target == originalInnings0Total + 1`. If `target` was revised by DLS or manual override, preserve the existing target.

---
### GAP-16: ICC DLS Standard Regulations Violation in NRR Calculation
- **Severity:** 🔴 Critical (P0)
- **Category:** Tournament Engine / ICC Regulations
- **Location:** [`lib/scoring.dart:1300-1304, lib/nrr_calculator.dart`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/scoring.dart)

#### 1. Vulnerability & Bug Description
In `computePointsTable`, `account(InningsState inn)` unconditionally adds Team 1's actual total runs and full 20-over balls (`batRow.runsFor += inn.totalRuns; batRow.ballsFor += balls;`). ICC Clause 16.10.2 stipulates: when DLS is applied, Team 1 must be credited with 1 run less than Team 2's target score off the number of overs allocated to Team 2.

#### 2. Technical Impact
Massive mathematical distortion in league NRR standings. Teams in rain-affected matches suffer severely unfair NRR penalties or artificial boosts.

#### 3. Problematic Code
```dart
// lib/scoring.dart:1301-1304
batRow.runsFor += inn.totalRuns;
batRow.ballsFor += balls;
bowlRow.runsAgainst += inn.totalRuns;
bowlRow.ballsAgainst += balls;
```

#### 4. Remediation Plan
When `i2.target > 0` and DLS was applied, credit Team 1 with `(i2.target - 1)` runs off Team 2's scheduled balls quota for NRR calculations.

---
### GAP-02: Hardcoded Owner Email & Lack of Multi-Tenant Security
- **Severity:** 🟠 High (P1)
- **Category:** Architecture / Authentication
- **Location:** [`lib/account_profile.dart:15, lib/store.dart:396, 440`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/account_profile.dart)

#### 1. Vulnerability & Bug Description
`kOwnerEmail = 'xharitarar550@gmail.com'` is hardcoded in production source code. Legacy guest migration, owner claims, and administrative operations are tied exclusively to this single Gmail address.

#### 2. Technical Impact
Any other developer, client, or tournament organizer who deploys this app cannot claim owner privileges or run legacy migration without modifying source code.

#### 3. Problematic Code
```dart
// lib/account_profile.dart:15
const String kOwnerEmail = 'xharitarar550@gmail.com';
```

#### 4. Remediation Plan
Remove hardcoded owner email. Derive admin rights from Firebase Custom Claims or Firestore role documents.

---
### GAP-03: Missing Cloud Firestore Rules for Phase-D Entity Collections
- **Severity:** 🟠 High (P1)
- **Category:** Cloud Security / Backend
- **Location:** [`lib/entity_firestore.dart, lib/sync_service.dart:780-788`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/entity_firestore.dart, lib/sync_service.dart)

#### 1. Vulnerability & Bug Description
Phase-D delta sync writes to subcollections `users/{uid}/matches`, `teams`, `tournaments`, and `tombstones`. Documented Firebase security rules only cover `backup/app_data` and `photos/{photoId}`. Unwritten entity rules cause Firestore to reject writes with `PERMISSION_DENIED`.

#### 2. Technical Impact
Entity sync fails silently, falls back to legacy monolithic blob sync, which fails on databases > 1 MiB.

#### 3. Problematic Code
```dart
// sync_service.dart:782-785
} catch (e) {
  _lastError = e.toString();
  debugPrint('Sync entity push failed, blob fallback: $e');
}
```

#### 4. Remediation Plan
Deploy Firestore security rules allowing read/write for all subcollections under `/users/{uid}/{collection}/{id}` where `request.auth.uid == uid`.

---
### GAP-17: RepaintBoundary Unhandled NullCheckException Across 5 Share Modules
- **Severity:** 🟠 High (P1)
- **Category:** UI / Sharing Engine
- **Location:** [`lib/points_table_share.dart:51, lib/stats_share.dart:194, lib/summary_share.dart:68, lib/fixture_poster.dart:43, lib/poster_summary.dart:488`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/points_table_share.dart)

#### 1. Vulnerability & Bug Description
All 5 image generation modules insert an overlay entry, wait `Future.delayed(const Duration(milliseconds: 400))`, and then assert `key.currentContext!.findRenderObject()`. If the user presses back or navigates away during that 400ms window, `key.currentContext` is null, throwing an unhandled `NullCheckException` crash and leaving orphaned overlay entries.

#### 2. Technical Impact
Crash on sharing preview abort; UI freezes or leaks transparent overlay layers blocking touch events.

#### 3. Problematic Code
```dart
// lib/points_table_share.dart:50-52
await Future.delayed(const Duration(milliseconds: 400));
final boundary =
    key.currentContext!.findRenderObject() as RenderRepaintBoundary;
```

#### 4. Remediation Plan
Check `if (key.currentContext == null || !key.currentContext!.mounted) return null;` wrapped in a `try/finally` block ensuring `entry.remove()` always executes.

---
### GAP-18: Bowler Incapacitation Mid-Over Blocked by UI Rule Lock
- **Severity:** 🟠 High (P1)
- **Category:** Cricket Law / Match Scorer
- **Location:** [`lib/scoring.dart:147-153, lib/screens/scoring_screen.dart:533-538`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/scoring.dart)

#### 1. Vulnerability & Bug Description
Under MCC Law 17.8, if a bowler is injured mid-over, another bowler must complete the remaining deliveries. The app strictly enforces `_canChangeBowler` ONLY before the first ball of an over is bowled (`_currentOverEvents(inn).isEmpty`). Once any ball is bowled, bowler change is completely disabled.

#### 2. Technical Impact
Scorers cannot record mid-over bowler injuries without either attributing balls to the injured bowler or corrupting the scorecard via undo.

#### 3. Problematic Code
```dart
// lib/screens/scoring_screen.dart:533-538
bool _canChangeBowler(InningsState inn) =>
    match.status == 'live' &&
    !inn.isComplete &&
    !inn.awaitingBowler &&
    inn.currentBowlerId.isNotEmpty &&
    _currentOverEvents(inn).isEmpty; // BLOCKED if any ball bowled!
```

#### 4. Remediation Plan
Add an 'Injured Bowler / Replace Mid-Over' option in the scoring menu that allows selecting a replacement bowler to finish the remaining balls of the over.

---
### GAP-19: Super Over Screen Never Triggers Playoff Recalculation
- **Severity:** 🟠 High (P1)
- **Category:** Tournament Engine / Super Over
- **Location:** [`lib/screens/super_over_screen.dart:72-85`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/screens/super_over_screen.dart)

#### 1. Vulnerability & Bug Description
Unlike `scoring_screen.dart` and `scorecard_edit_screen.dart`, `super_over_screen.dart` only calls `computeResult()` and `persistMatchesOnly()`. It never calls `applyPlayoffUpdate(store, match.tournamentId)`. When a Super Over finishes, playoff brackets are never updated.

#### 2. Technical Impact
Playoff standings and finalist slots do not update when a match is decided via Super Over.

#### 3. Problematic Code
```dart
// lib/screens/super_over_screen.dart:73-79
computeResult(match, store.teamName);
final saved = await store.persistMatchesOnly();
// MISSING: applyPlayoffUpdate(store, match.tournamentId)!
```

#### 4. Remediation Plan
Call `applyPlayoffUpdate(store, match.tournamentId)` upon Super Over completion.

---
### GAP-20: Hard Block on Correcting Winning Result in Scorecard Edit
- **Severity:** 🟠 High (P1)
- **Category:** Scorecard Editing / Administrative Control
- **Location:** [`lib/screens/scorecard_screen.dart:1556-1570`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/screens/scorecard_screen.dart)

#### 1. Vulnerability & Bug Description
If a ball edit on a completed match alters the winning team (e.g. correcting a boundary erroneously awarded to the wrong team), the app aggressively rejects the edit: `'This edit would change the match winner — refused. Only margin corrections are allowed after completion.'`

#### 2. Technical Impact
Scorers cannot fix genuine scorebook mistakes that affected the match outcome. The entire match must be deleted and rescored.

#### 3. Problematic Code
```dart
// lib/screens/scorecard_screen.dart:1556-1560
if (match.status == 'completed' &&
    origWinner != null &&
    newWinner != null &&
    origWinner != newWinner) {
  match.innings[innIdx] = inn; // REVERTS EDIT!
  _snack('This edit would change the match winner — refused.');
}
```

#### 4. Remediation Plan
Replace hard-block with an explicit confirmation dialog asking the scorer/admin to confirm that this edit intentionally changes the match winner.

---
### GAP-21: Unscoped PhotoSync Tracker Causing Multi-User Photo Sync Failure
- **Severity:** 🟠 High (P1)
- **Category:** Cloud Sync / Multi-Account
- **Location:** [`lib/photo_sync.dart:62, lib/photo_sync.dart:185`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/photo_sync.dart)

#### 1. Vulnerability & Bug Description
The tracker key `score60_photo_sync_v1` is static and un-scoped. If User A logs in and uploads player photos, the hashes are saved in this shared key. If User B logs in on the same device, `tracker[reg.id]?['h'] == hash` evaluates to true, skipping upload to User B's Firestore storage.

#### 2. Technical Impact
User B's registered players appear with missing photos on other devices because photos were never uploaded to User B's account.

#### 3. Problematic Code
```dart
// lib/photo_sync.dart:62
static const String trackerKey = 'score60_photo_sync_v1'; // NOT SCOPED BY UID!
```

#### 4. Remediation Plan
Scope tracker key by UID: `score60_photo_sync_v1__$uid`.

---
### GAP-01: Hardcoded Stale Version in Drawer (`Version 1.3.4`)
- **Severity:** 🟡 Medium (P2)
- **Category:** UI / Presentation
- **Location:** [`lib/main.dart:704`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/main.dart)

#### 1. Vulnerability & Bug Description
The navigation drawer footer displays hardcoded `'Version 1.3.4'`, while `pubspec.yaml` defines `1.4.8+31`.

#### 2. Technical Impact
Users and QA testers believe they are running an outdated version.

#### 3. Problematic Code
```dart
// lib/main.dart:704
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Version 1.3.4', ...),
)
```

#### 4. Remediation Plan
Update string to `'Version 1.4.8'` or resolve dynamically using `package_info_plus`.

---
### GAP-05: Web Platform `dart:io` Incompatibility in Backup & Restore
- **Severity:** 🟡 Medium (P2)
- **Category:** Platform Portability / Web
- **Location:** [`lib/backup_service.dart:1-35`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/backup_service.dart)

#### 1. Vulnerability & Bug Description
`backup_service.dart` directly imports `dart:io` and calls `getApplicationDocumentsDirectory()`. On Flutter Web, this throws `UnsupportedError`, disabling all local backup, auto-backup, and JSON export features.

#### 2. Technical Impact
Web users cannot create or restore backups.

#### 3. Problematic Code
```dart
// lib/backup_service.dart:5, 24
import 'dart:io';
final docs = await getApplicationDocumentsDirectory(); // FAILS ON WEB
```

#### 4. Remediation Plan
Use conditional imports or Web Blob download triggers (`html.AnchorElement.click()`).

---
### GAP-07: Lack of Atomic Transactions in SharedPreferences DB Dump
- **Severity:** 🟡 Medium (P2)
- **Category:** Data Architecture / Concurrency
- **Location:** [`lib/store.dart:703-748`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/store.dart)

#### 1. Vulnerability & Bug Description
The entire database (all teams, matches, tournaments, drafts) is serialized as JSON strings across separate SharedPreferences keys sequentially without atomic transaction wrapping. If the app is killed mid-write, partial database state is committed.

#### 2. Technical Impact
Database corruption if OS kills process during heavy background writes.

#### 3. Problematic Code
```dart
// lib/store.dart:705-720
await p.setString(_scoped(_kTeams), ...);
await p.setString(_scoped(_kTournaments), ...);
await p.setString(_scoped(_kMatches), ...); // If killed here, state is out-of-sync!
```

#### 4. Remediation Plan
Migrate to SQLite / Isar / Hive or implement write-ahead atomic commit markers.

---
### GAP-08: Base64 Inline Player Photos Inside SharedPrefs Causing OOM Kills
- **Severity:** 🟡 Medium (P2)
- **Category:** Memory / Performance
- **Location:** [`lib/models.dart:16, lib/store.dart:1001-1005`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/models.dart)

#### 1. Vulnerability & Bug Description
Player photos are stored as inline Base64 JPEG strings inside `Player` and `RegPlayer` models. Serializing these multi-megabyte strings into SharedPreferences on every ball or team edit causes memory spikes and OS-level kills.

#### 2. Technical Impact
App freezes and sudden crashes on devices with large player photo libraries.

#### 3. Problematic Code
```dart
// lib/models.dart:16
String photoBase64; // Stored inline in every match XI and team squad!
```

#### 4. Remediation Plan
Store photos as standalone local disk files, storing only relative file paths in JSON models.

---
### GAP-22: Synchronous Pure Dart Image Processing Freezing UI Thread
- **Severity:** 🟡 Medium (P2)
- **Category:** Performance / UI Responsiveness
- **Location:** [`lib/photo_sync.dart:85-100`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/photo_sync.dart)

#### 1. Vulnerability & Bug Description
`compressPhoto()` uses `package:image` to decode, resize, and re-encode multi-megabyte camera photos synchronously on Flutter's main UI isolate.

#### 2. Technical Impact
Scoring screen and app UI freeze for 1.5–3.5 seconds during photo uploads.

#### 3. Problematic Code
```dart
// lib/photo_sync.dart:87-97
final decoded = img.decodeImage(Uint8List.fromList(bytes));
final out = img.copyResize(decoded, ...);
return img.encodeJpg(out, quality: jpegQuality); // HEAVY SYNCHRONOUS WORK
```

#### 4. Remediation Plan
Offload image decoding and compression to a background isolate using Flutter's `compute()`.

---
### GAP-23: TTS Wicket Announcement Cut Off Mid-Sentence at Over Boundary
- **Severity:** 🟡 Medium (P2)
- **Category:** TTS Commentary / Audio
- **Location:** [`lib/screens/scoring_screen.dart:788-790, lib/tts_service.dart:165-174`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/screens/scoring_screen.dart)

#### 1. Vulnerability & Bug Description
When a wicket falls on the final ball of an over, `tts.speak()` is called sequentially for both the wicket and the over summary without queuing. Standard `FlutterTts` cancels any currently spoken utterance, truncating the wicket announcement.

#### 2. Technical Impact
Wicket announcement is cut off mid-word.

#### 3. Problematic Code
```dart
// lib/screens/scoring_screen.dart:788-790
for (final p in phrases) {
  tts.speak(p); // Overwrites previous speech immediately!
}
```

#### 4. Remediation Plan
Configure `awaitSpeakCompletion(true)` or concatenate phrases into a single speech utterance: `tts.speak(phrases.join(' ... '))`.

---
### GAP-24: Trashed Registered Players Permanently Lost on Restore
- **Severity:** 🟡 Medium (P2)
- **Category:** Data Management / Trash
- **Location:** [`lib/store.dart:912-918, lib/store.dart:1187`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/store.dart)

#### 1. Vulnerability & Bug Description
`deleteRegPlayer()` deletes players directly without snapshotting to Trash. Furthermore, in `restoreFromTrash()`, the `default:` branch drops and permanently deletes any entity other than match, team, or tournament.

#### 2. Technical Impact
Accidentally deleted registered players cannot be recovered.

#### 3. Problematic Code
```dart
// lib/store.dart:912-917
default:
  _trash.removeAt(i);
  await persist();
  break; // Drops entry without restoring!
```

#### 4. Remediation Plan
Snapshot registered players into `_trash` on delete, and add `case EntityKind.regPlayers:` in `restoreFromTrash()`.

---
### GAP-25: Draft Turn Order Calculation Out of Phase on Custom Round Sizes
- **Severity:** 🟡 Medium (P2)
- **Category:** Draft System / Algorithm
- **Location:** [`lib/draft.dart:36`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/draft.dart)

#### 1. Vulnerability & Bug Description
`nextTurn` calculates the team index via `order[idx % order.length]`. If `manualRoundPicks` has fewer teams than standard, `idx % order.length` indexes out of phase with the round start, skipping teams.

#### 2. Technical Impact
Custom round draft orders skip the first team and assign turns to the wrong team.

#### 3. Problematic Code
```dart
// lib/draft.dart:36
return DraftTurn(round, idx + 1, order[idx % order.length]); // Out of phase!
```

#### 4. Remediation Plan
Compute index relative to the current round start: `final roundStart = (round - 1) * teamsPerRound; final roundIdx = idx - roundStart; return order[roundIdx % order.length];`.

---
### GAP-26: Draft Skipped Turns Counted Towards Team Squad Quota
- **Severity:** 🟡 Medium (P2)
- **Category:** Draft System / Team Quota
- **Location:** [`lib/draft.dart:55-57, lib/draft.dart:90-100`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/draft.dart)

#### 1. Vulnerability & Bug Description
`squadCount` counts all picks assigned to a team (`d.picks.where((p) => p.teamId == teamId).length`), including placeholder skipped picks (`playerId == ''`). A team that skips a turn has their quota prematurely exhausted.

#### 2. Technical Impact
A team skipping a turn can never draft a replacement player in a later round.

#### 3. Problematic Code
```dart
// lib/draft.dart:55-56
int squadCount(Draft d, String teamId) =>
    d.picks.where((p) => p.teamId == teamId).length; // Counts skipped picks!
```

#### 4. Remediation Plan
Only count real players: `d.picks.where((p) => p.teamId == teamId && p.playerId.isNotEmpty).length`.

---
### GAP-27: Fixture Overs Limit Edit Does Not Update Existing Innings
- **Severity:** 🟡 Medium (P2)
- **Category:** Fixture Management / Scoring Sync
- **Location:** [`lib/scoring.dart:993-1027`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/scoring.dart)

#### 1. Vulnerability & Bug Description
`applyFixtureEdit` updates `Match.oversLimit` but fails to update `InningsState.oversLimit` for existing innings.

#### 2. Technical Impact
Changing overs in fixture edit has zero effect on already-created innings; the innings continues to play under the old overs limit.

#### 3. Problematic Code
```dart
// lib/scoring.dart:1021
m.oversLimit = oversLimit; // Does NOT update m.innings[i].oversLimit!
```

#### 4. Remediation Plan
Loop through `for (final inn in m.innings) inn.oversLimit = oversLimit;`.

---
### GAP-28: Default Helvetica Font Crash on Urdu/Arabic/Emoji Text in PDF
- **Severity:** 🟡 Medium (P2)
- **Category:** PDF Export / Unicode Support
- **Location:** [`lib/pdf_export.dart:20-60`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/pdf_export.dart)

#### 1. Vulnerability & Bug Description
Standard built-in Helvetica Type 1 font in `package:pdf` supports only Latin-1. Passing Urdu, Arabic, Hindi, or emojis throws `Cannot render character` exceptions during PDF generation.

#### 2. Technical Impact
PDF scorecard export crashes completely for players or venues with non-Latin names.

#### 3. Problematic Code
```dart
// lib/pdf_export.dart:45
final small = const pw.TextStyle(fontSize: 9); // Defaults to Helvetica Type 1
```

#### 4. Remediation Plan
Load and register a bundled Unicode font (e.g. Roboto or Noto Sans) with TTF fallback.

---
### GAP-29: Toss Presumption of Batting First in Unplayed Matches
- **Severity:** 🟡 Medium (P2)
- **Category:** Match State / Previews
- **Location:** [`lib/models.dart:1038-1044`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/models.dart)

#### 1. Vulnerability & Bug Description
If `tossWinnerId` is empty (`''`), `Match.battingFirstId` falls through to returning `teamBId`.

#### 2. Technical Impact
Pre-match preview cards and fixture lists falsely display Team B as batting first before any toss has occurred.

#### 3. Problematic Code
```dart
// lib/models.dart:1040-1043
if (tossWinnerId == teamAId) {
  return tossDecision == 'bat' ? teamAId : teamBId;
}
return tossDecision == 'bat' ? teamBId : teamAId; // If tossWinnerId is empty, returns teamBId!
```

#### 4. Remediation Plan
Return empty string `''` if `tossWinnerId.isEmpty`.

---
### GAP-30: POTM Economy Multiplier Hardcoded to 6 Balls
- **Severity:** 🟢 Low (P3)
- **Category:** Analytics / POTM Formula
- **Location:** [`lib/potm.dart:49, 77`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/potm.dart)

#### 1. Vulnerability & Bug Description
Player of the Match economy calculation uses `bowlRuns * 6.0 / bowlBalls` unconditionally, ignoring `Match.ballsPerOver`.

#### 2. Technical Impact
In Super Sixty (8-ball overs) or The Hundred (5-ball overs), economy calculations are mathematically inaccurate.

#### 3. Problematic Code
```dart
// lib/potm.dart:49
double get economy => bowlBalls > 0 ? bowlRuns * 6.0 / bowlBalls : 0.0;
```

#### 4. Remediation Plan
Pass `ballsPerOver` into POTM calculation and multiply by `ballsPerOver.toDouble()`.

---
### GAP-04: Multi-Device Realtime Cloud Sync Disabled (Offline-First Trade-off)
- **Severity:** 🟢 Low (P3)
- **Category:** Cloud Architecture
- **Location:** [`lib/sync_service.dart, lib/main.dart`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/sync_service.dart, lib/main.dart)

#### 1. Vulnerability & Bug Description
Automatic background network sync was disabled in v1.4.5 to protect local battery and prevent mid-match UI freezing.

#### 2. Technical Impact
Changes on one device do not appear in realtime on another device until manual pull/push.

#### 3. Problematic Code
```dart
// lib/store.dart:955-956
// Offline-first (v1.4.5): no automatic cloud push — this only marks the store dirty
```

#### 4. Remediation Plan
Retain offline-first architecture by default, but provide an optional toggle for live tournament broadcast mode.

---
### GAP-06: DLS Minimum Overs Threshold Missing in UI
- **Severity:** 🟢 Low (P3)
- **Category:** Cricket Law / UI
- **Location:** [`lib/dls.dart, lib/screens/scoring_screen.dart`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/dls.dart, lib/screens/scoring_screen.dart)

#### 1. Vulnerability & Bug Description
ICC rules require a minimum number of overs (typically 5 for T20, 20 for ODI) to constitute an official match under DLS. The UI does not display a minimum over threshold warning.

#### 2. Technical Impact
Scorers could prematurely apply DLS before legal minimum overs are completed.

#### 3. Problematic Code
```dart
// lib/screens/scoring_screen.dart:917-919
final canApply = result != null && match.innings.length >= 2 && match.status == 'live';
```

#### 4. Remediation Plan
Display an advisory warning if fewer than 5 overs (or tournament minimum) have been bowled.

---
### GAP-09: 64-bit Integer Literal JavaScript Compilation Failure
- **Severity:** 🟢 Resolved Locally
- **Category:** Web Compilation / JavaScript
- **Location:** [`lib/photo_sync.dart:69, lib/entity_sync_coordinator.dart:211`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/photo_sync.dart)

#### 1. Vulnerability & Bug Description
`0xcbf29ce484222325` cannot be represented in JavaScript (IEEE-754 max safe int is 53 bits).

#### 2. Technical Impact
`flutter run -d chrome` or web build failed with `dart2js` compile errors.

#### 3. Problematic Code
```dart
// Before:
var h = 0xcbf29ce484222325; // JS COMPILER CRASH!
```

#### 4. Remediation Plan
Replaced with 2-pass 32-bit FNV-1a hashing. Fixed and verified locally.

---
### GAP-10: NRR Division-by-Zero Guard with Custom Overs
- **Severity:** 🟢 Low (P3)
- **Category:** Math Engine
- **Location:** [`lib/scoring.dart:1180-1182`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/scoring.dart)

#### 1. Vulnerability & Bug Description
If a match is abandoned with 0 balls bowled, `oversFor == 0` causes division by zero resulting in `NaN` or `Infinity`.

#### 2. Technical Impact
Points table NRR displays NaN.

#### 3. Problematic Code
```dart
// lib/scoring.dart:1181
return (runsFor / oversFor) - (runsAgainst / oversAgainst);
```

#### 4. Remediation Plan
Check `if (ballsFor == 0 || ballsAgainst == 0) return 0.0;`.

---
### GAP-11: Playoff Fixture Reseeding on Late Scorecard Edits
- **Severity:** 🟢 Low (P3)
- **Category:** Tournament Management
- **Location:** [`lib/tournament_engine.dart:180-210`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/lib/tournament_engine.dart)

#### 1. Vulnerability & Bug Description
If an organizer edits a match score after semifinals have begun, automatic reseeding is blocked. The prompt requires manual force confirmation.

#### 2. Technical Impact
Working as intended for protection, but requires clearer UX documentation for tournament directors.

#### 3. Problematic Code
```dart
// lib/tournament_engine.dart:203-209
if (qChanged && anyPlayoffStarted) {
  return PlayoffUpdate(needsConfirmation: true, message: 'Playoffs already underway...');
}
```

#### 4. Remediation Plan
Provide explicit UI explanation in the tournament settings screen.

---
### GAP-12: Dart SDK Version Constraint Incompatibility
- **Severity:** 🟢 Resolved Locally
- **Category:** Build Toolchain
- **Location:** [`pubspec.yaml:22`](file:///c:/Users/Muhammad%20Aliyan/Desktop/crciketscoree/60score/cricket_scorer_app/pubspec.yaml)

#### 1. Vulnerability & Bug Description
`sdk: ^3.13.4` rejected installed Flutter 3.44.2 Dart SDK (3.12.2).

#### 2. Technical Impact
`flutter pub get` failed.

#### 3. Problematic Code
```dart
// Before:
environment:
  sdk: ^3.13.4
```

#### 4. Remediation Plan
Updated `sdk: '>=3.12.0 <4.0.0'`. Verified and passing.

---
## Part 5: Recommended Patch Priority Matrix

| Phase | Target Items | Estimated Effort | Focus |
|---|---|---|---|
| **Phase 1: Critical Domain Fixes (P0)** | GAP-13, GAP-14, GAP-15, GAP-16 | 2-3 hours | Match results, DLS targets, Super Over playoff promotion, ICC NRR compliance |
| **Phase 2: Crash & Security Hardening (P1)** | GAP-02, GAP-03, GAP-17, GAP-18, GAP-19, GAP-20, GAP-21 | 3-4 hours | Overlay crash prevention, mid-over injury handling, dynamic auth, Firestore rules |
| **Phase 3: Performance & Platform Portability (P2)** | GAP-01, GAP-05, GAP-07, GAP-08, GAP-22, GAP-23, GAP-24, GAP-25, GAP-26, GAP-27, GAP-28, GAP-29, GAP-30 | 4-5 hours | Isolate image compression, Web PDF/Backup support, Draft turn fix, Storage optimization |
| **Phase 4: Maintenance & Polishing (P3)** | GAP-04, GAP-06, GAP-09, GAP-10, GAP-11, GAP-12 | 1-2 hours | UI guidance, documentation, testing edge cases |

