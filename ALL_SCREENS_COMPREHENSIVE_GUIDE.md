# 60Score — All Screens Comprehensive UX & Architecture Guide

This comprehensive guide details every screen across the **60Score** (formerly STUMPS) application. It documents the current UX structure, sections, user interactions, offline data bindings, and modernization status.

---

## 📑 Summary of Application Screens (32 Total)

| Domain Category | Screen Count | Key Responsibility |
|---|:---:|---|
| **1. Home & App Navigation** | 11 | Central feed, search, account login, settings, backups, diagnostics |
| **2. Live Match Scoring Engine** | 5 | Setup, Playing XI lineups, Toss, Ball-by-ball scoring, Super Over |
| **3. Scorecard & Analytics** | 2 | Detailed scorecard, commentary, graphs (Worm, Manhattan), edit mode |
| **4. Tournaments & League Engine** | 9 | Tournament dashboard, Fixtures, Points Table, NRR calculator, Playoffs |
| **5. Teams, Players & Stats** | 4 | Clubs, rosters, player profiles, global leaderboards, registration |
| **6. Draft & Auction** | 1 | Live player draft, round picks, category management, team budget |

---

## 1. 🏠 Home & Core Navigation Hub

### 1.1 `HomeScreen` (`lib/views/screens/home/home_screen.dart`)
- **Purpose**: The main central dashboard of the entire application. Displays live matches, quick actions, active tournament cards, and directories.
- **Current UX Sections**:
  1. **Sticky Top Header**: Athletic `60Score` vector brand badge, quick search input pill ("Search matches, teams..."), notification bell, and user avatar.
  2. **Filter Pills Row**: Horizontal filter buttons:
     - `ALL FEED`: Aggregated local + cloud matches.
     - `LIVE (count)`: Live in-progress matches with red pulsating dot.
     - `TOURNAMENTS`: Strictly matches associated with a tournament.
     - `CLUBS & TEAMS`: Friendly, club, and bilateral matches.
  3. **Live & Recent Matches Carousel**: Horizontal left-to-right scrollable cards. Displays batting team, scores, overs, run rate (CRR/RRR), and striker indicator.
  4. **My Profile Quick Access Card**: Displays current signed-in user/player name, registered team, and role summary.
  5. **Quick Actions Grid**: Fast start cards:
     - `Create Match` (Single match setup)
     - `Tournaments` (Tournament management)
     - `Clubs & Teams` (Squad rosters)
     - `Stats Center` (Leaderboards & NRR)
  6. **Active Tournaments Spotlight**: Highlights currently active tournaments with stage (e.g. Playoffs, Group Stage) and quick standings link.
  7. **Directories Section**: Navigation cards to Teams, Players, and Archives.

### 1.2 `ScorerHomeScreen` (`lib/views/screens/home/scorer_home_screen.dart`)
- **Purpose**: Fast-lane scoring hub tailored specifically for official scorers.
- **Current UX Sections**:
  1. **Active Match Banner**: If a match is currently in-progress locally, offers a 1-tap "Resume Scoring" button.
  2. **My Offline Matches**: Filterable list (Live, Upcoming, Completed) of matches created on this specific device.
  3. **New Match FAB**: Large primary Floating Action Button to launch `MatchSetupScreen`.

### 1.3 `LoginScreen` (`lib/views/screens/home/login_screen.dart`)
- **Purpose**: User authentication gate supporting Google Sign-In, Email/Password login, and Offline Guest Mode.
- **Current UX Sections**:
  1. **Brand Hero**: 60Score vector logo with subtitle *"Offline-first Cricket Scorer & League Manager"*.
  2. **Google Sign-In Button**: 1-tap OAuth login.
  3. **Email & Password Form**: Clean text fields with visibility toggle and validation.
  4. **Forgot Password Link**: Triggers Firebase password reset link via email.
  5. **Continue as Guest Button**: Clean secondary action allowing 100% offline access without an account.

### 1.4 `ProfileSetupScreen` (`lib/views/screens/home/profile_setup_screen.dart`)
- **Purpose**: First-time profile configuration after signup or guest upgrade.
- **Current UX Sections**:
  1. **Display Name Input**: Full name or nickname.
  2. **Playing Role Selector**: Chips for Batter, Bowler, All-Rounder, Wicket-Keeper.
  3. **Batting Style**: Right-hand / Left-hand batter.
  4. **Bowling Style**: Right-arm / Left-arm (Fast, Medium, Spin).
  5. **Team Affiliation Dropdown**: Select existing club or leave independent.

### 1.5 `PublicMatchesScreen` (`lib/views/screens/home/public_matches_screen.dart`)
- **Purpose**: Full searchable, paginated/filtered list of all live, scheduled, and past matches.
- **Current UX Sections**:
  1. **Search & Filter Bar**: Filter by tournament name, team name, or ground/venue.
  2. **Tabbed Views**: `Live Now`, `Upcoming`, `Completed`.
  3. **Match Cards List**: Detailed cards with full team names, scores, overs, and result descriptions.

### 1.6 `CompletedMatchesScreen` (`lib/views/screens/home/completed_matches_screen.dart`)
- **Purpose**: Match history archive for finished games with winner badges and Player of the Match awards.
- **Current UX Sections**:
  1. **Year / Season Selector**: Filter past matches by year or tournament season.
  2. **Match Summary Cards**: Scores, winning margin (e.g. *"Won by 14 runs"*), Player of the Match name, and Scorecard link.

### 1.7 `SettingsScreen` (`lib/views/screens/home/settings_screen.dart`)
- **Purpose**: App-wide configurations, account management, sync status, and storage settings.
- **Current UX Sections**:
  1. **Account Info Card**: Displays UID, User Code, and Sign-out button.
  2. **Sync Settings**: Manual "Sync Now" button, last synced timestamp, and auto-sync toggles.
  3. **Storage & Data**: Cache clearer, database size indicator, and Backup & Restore navigation.
  4. **Developer Tools**: Link to `DebugInfoScreen` and system log viewer.

### 1.8 `BackupScreen` (`lib/views/screens/home/backup_screen.dart`)
- **Purpose**: Offline-first disaster recovery. Export and import entire SQLite / SharedPreferences data.
- **Current UX Sections**:
  1. **Export Database**: Generates a verified JSON backup file to phone storage or shares via system sheet.
  2. **Import Database**: File picker allowing restoration of all matches, teams, and tournament history.
  3. **Auto-Backup History**: Displays list of last 14 automatic daily local snapshots.

### 1.9 `DebugInfoScreen` (`lib/views/screens/home/debug_info_screen.dart`)
- **Purpose**: Diagnostics and crash logs for bug triage and technical audits.
- **Current UX Sections**:
  1. **System Health Metrics**: Firebase status, SQLite status, SharedPreferences storage health.
  2. **Recent Errors Log**: Stack traces of recent uncaught exceptions.
  3. **Copy Diagnostic Report**: 1-click clipboard export for developer debugging.

### 1.10 `AboutScreen` (`lib/views/screens/home/about_screen.dart`)
- **Purpose**: App credits, license information, version numbers, and developer contact.
- **Current UX Sections**:
  1. **App Identity**: Vector logo, version `1.5.6+39`.
  2. **Open Source Licenses**: Flutter and third-party dependencies.
  3. **Privacy Policy Link**: Legal terms for offline and online services.

### 1.11 `TrashScreen` (`lib/views/screens/home/trash_screen.dart`)
- **Purpose**: Recycle bin for accidentally deleted matches or teams.
- **Current UX Sections**:
  1. **Soft-Deleted Items List**: Matches and teams marked with deletion timestamps.
  2. **Restore Action**: Returns item to active store.
  3. **Permanent Purge Action**: Irreversibly deletes items to free local storage.

---

## 2. 🏏 Live Match Scoring Engine

### 2.1 `MatchSetupScreen` (`lib/views/screens/scoring/match_setup_screen.dart`)
- **Purpose**: Create a new match, configure playing conditions, rules, and teams.
- **Current UX Sections**:
  1. **Team Selection**: Team A and Team B dropdowns with option to quickly create a new team inline.
  2. **Match Type**: Friendly / Bilateral vs Tournament Match (linked to a tournament).
  3. **Overs & Balls Configuration**: Overs limit (e.g. 5, 10, 20), Balls per over (default 6).
  4. **Ground / Venue & Date**: Venue name and match kickoff schedule.
  5. **Ball Type**: Leather Ball / Tape Ball / Tennis Ball.

### 2.2 `MatchLineupsScreen` (`lib/views/screens/scoring/match_lineups_screen.dart`)
- **Purpose**: Select Playing XI/squads from registered team players before toss.
- **Current UX Sections**:
  1. **Team A / Team B Tab**: Switch between the two teams.
  2. **Player Roster Checklist**: Tap players to include/exclude from the active XI.
  3. **Role Designations**: Set Captain (C) and Wicket-Keeper (WK).
  4. **Add Bench Player**: Create a guest or substitute player on the fly.

### 2.3 `MatchTossScreen` (`lib/views/screens/scoring/match_toss_screen.dart`)
- **Purpose**: Conduct or record the coin toss and election (Bat / Bowl).
- **Current UX Sections**:
  1. **Interactive Coin Flip**: Tap to simulate Heads / Tails flip.
  2. **Toss Winner Selector**: Radio selector for Team A or Team B.
  3. **Elected To**: Bat First or Bowl First.
  4. **Start Innings Button**: Transitions directly to `ScoringScreen`.

### 2.4 `ScoringScreen` (`lib/views/screens/scoring/scoring_screen.dart`)
- **Purpose**: The primary telemetry engine for live ball-by-ball cricket scoring.
- **Current UX Sections**:
  1. **Scoreboard Header**:
     - Batting Team score (`142/3 in 15.4 Ov`), CRR, RRR, Target equation.
     - Striker (marked with 🏏 cricket bat icon) & Non-striker stats (Runs, Balls, 4s, 6s, SR).
     - Active Bowler stats (Overs, Maidens, Runs, Wickets, Economy).
  2. **This Over Timeline**: Horizontal chips showing current over events (e.g. `1`, `4`, `W`, `Wd`, `6`).
  3. **Scoring Keypad**:
     - Quick Runs: `0`, `1`, `2`, `3`, `4`, `6`.
     - Extras: `Wide`, `No Ball`, `Bye`, `Leg Bye`, `Penalty`.
     - Dismissal: `WICKET` button (triggers dismissal modal: Bowled, Caught, Run Out, LBW, Stumped, etc.).
  4. **Wagon Wheel Sheet (Modal)**: Interactive field diagram with labeled fielding positions (Long On, Long Off, Cover, Point, Mid Wicket, Third Man, Fine Leg, Square Leg) to plot shot direction.
  5. **DLS Calculator Sheet (Modal)**: Rain interruption handler; recalculates target according to standard Duckworth-Lewis-Stern regulations.
  6. **Mid-Over Actions**: Change Bowler, Retire Batsman, Swap Strike, End Innings early.
  7. **Undo Last Ball**: Instant rollback of the last event.

### 2.5 `SuperOverScreen` (`lib/views/screens/scoring/super_over_screen.dart`)
- **Purpose**: Handles tie-breaker Super Over setup and ball-by-ball resolution.
- **Current UX Sections**:
  1. **Super Over Team Order**: Select who bats first in the Super Over.
  2. **2-Wicket Limit Rule**: Strictly enforces ICC standard 2-wicket cap per super over.
  3. **Target Calculation**: 1-over target auto-derived from Innings 1 score.
  4. **Tie-of-Tie Handler**: Options for Boundary Countback or Second Super Over.

---

## 3. 📊 Scorecard & Analytics

### 3.1 `ScorecardScreen` (`lib/views/screens/scorecard/scorecard_screen.dart`)
- **Purpose**: Complete match statistics, digital scoresheet, and telemetry charts.
- **Current UX Sections**:
  1. **Header Hero**: Final match result banner, winning margin, Player of the Match.
  2. **Innings Tabs**: Toggle between Innings 1 and Innings 2.
  3. **Batting Table**: Batter name, dismissal description, Runs, Balls, 4s, 6s, Strike Rate.
  4. **Bowling Table**: Bowler name, Overs, Maidens, Runs, Wickets, Economy.
  5. **Fall of Wickets (FOW)**: Score and over at each wicket fall.
  6. **Partnerships**: Interactive bar charts for highest wicket partnerships.
  7. **Graphs Section**:
     - **Worm Chart**: Cumulative runs comparison over-by-over with labeled X-axis (Overs) and Y-axis (Runs).
     - **Manhattan Chart**: Bar chart of runs scored in every individual over with X/Y axes.
  8. **Export Actions**: Share scorecard screenshot or export official PDF match report.

### 3.2 `ScorecardEditScreen` (`lib/views/screens/scorecard/scorecard_edit_screen.dart`)
- **Purpose**: Official retroactive editor for correcting scoring errors after or during a game.
- **Current UX Sections**:
  1. **Event Log List**: Chronological ball-by-ball list of every delivery in the match.
  2. **Ball Edit Dialog**: Edit runs credited, extras attributed, batter/bowler assigned, or wicket type.
  3. **Recalculate Integrity Check**: Auto-recalculates total runs, wickets, and bowler figures upon saving.

---

## 4. 🏆 Tournaments & League Engine

### 4.1 `TournamentsScreen` (`lib/views/screens/tournament/tournaments_screen.dart`)
- **Purpose**: List of all tournaments managed locally or published to the cloud.
- **Current UX Sections**:
  1. **Create Tournament Card / Button**: Launches creation wizard.
  2. **Tournament Cards List**:
     - Tournament Name, Ball Type, Team Count, Stage (e.g. League Stage, Semi-Finals, Completed).
  3. **Filter Tabs**: `All`, `Ongoing`, `Upcoming`, `Completed`.

### 4.2 `TournamentDetailScreen` (`lib/views/screens/tournament/tournament_detail_screen.dart`)
- **Purpose**: The central operations room for a specific tournament.
- **Current UX Sections**:
  1. **Header Banner**: Tournament Name, format, status badge, and Owner controls.
  2. **Tabs Navigation**:
     - **Fixtures Tab**: Scheduled, live, and completed tournament matches grouped by round/stage.
     - **Points Table Tab**: Teams ranked by Points, NRR, Wins, Losses, Tied, NR.
     - **Teams Tab**: Participating squads and roster sizes.
     - **Playoffs Tab**: Auto-scheduled semi-finals, eliminators, and grand final bracket.
  3. **Owner Action Drawer**: Add Fixtures, Auto-Generate Schedule, Publish to Cloud, Export Standings PDF.

### 4.3 `TournamentStatsScreen` (`lib/views/screens/tournament/tournament_stats.dart`)
- **Purpose**: Tournament-wide player leaderboards and individual achievements.
- **Current UX Sections**:
  1. **Orange Cap / Leading Run Scorers**: Top batters ranked by total tournament runs.
  2. **Purple Cap / Leading Wicket Takers**: Top bowlers ranked by total wickets and bowling average.
  3. **Most Sixes / Fours**: Boundary hitters leaderboard.
  4. **Best Individual Inning**: Highest individual scores in the tournament.

### 4.4 `NrrCalculatorScreen` (`lib/views/screens/tournament/nrr_calculator_screen.dart`)
- **Purpose**: Interactive ICC standard Net Run Rate calculator and scenario planner.
- **Current UX Sections**:
  1. **Current Stats Inputs**: Total Runs Scored, Overs Faced, Runs Conceded, Overs Bowled.
  2. **Upcoming Match Target Simulator**:
     - "If Team A scores X in 20 overs, how many runs can they concede to maintain NRR?"
     - "If chasing, how quickly must they reach the target to overtake rival team in NRR?"
  3. **Formula & Calculation Breakdown**: Mathematical explanation step-by-step.

### 4.5 `QualificationChancesScreen` (`lib/views/screens/tournament/qualification_chances_screen.dart`)
- **Purpose**: Monte Carlo / mathematical scenario simulator for playoff qualification.
- **Current UX Sections**:
  1. **Remaining Matches Matrix**: Select hypothetical Win/Loss for remaining games.
  2. **Projected Points Table**: Real-time updated standings based on hypothetical outcomes.
  3. **Qualification Verdict**: Clear status badges: *"Qualified"*, *"Eliminated"*, *"Depends on NRR"*.

### 4.6 `FixtureDetailScreen` (`lib/views/screens/tournament/fixture_detail_screen.dart`)
- **Purpose**: Detailed card for an individual scheduled tournament fixture.
- **Current UX Sections**:
  1. **Fixture Header**: Stage/Round name, Match number, Venue, and Scheduled Date/Time.
  2. **Team Matchup**: Logos, Team A vs Team B.
  3. **Scoring Action**: "Start Match" button (for tournament organizers/scorers) or "View Live Scorecard".

### 4.7 `FixtureEditScreen` (`lib/views/screens/tournament/fixture_edit_screen.dart`)
- **Purpose**: Reschedule or edit fixture parameters.
- **Current UX Sections**:
  1. **Date & Time Picker**: Update scheduled start.
  2. **Venue Selector**: Change playing ground.
  3. **Team Substitution**: Update assigned teams if playoff seedings changed.

### 4.8 `PublishedSearchScreen` (`lib/views/screens/tournament/published_search_screen.dart`)
- **Purpose**: Global cloud discovery for online published tournaments.
- **Current UX Sections**:
  1. **Search Bar**: Search by tournament name or 6-digit access code.
  2. **Results List**: Card results with organizer name, city, and live match counts.

### 4.9 `PublishedTournamentScreen` (`lib/views/screens/tournament/published_tournament_screen.dart`)
- **Purpose**: Read-only cloud tournament viewer for spectators and players.
- **Current UX Sections**:
  1. **Live Score ticker**: Current live tournament match scores.
  2. **Public Points Table & Fixtures**: Real-time read-only standings synced from server.

---

## 5. 🛡️ Teams, Players & Global Stats

### 5.1 `TeamsScreen` (`lib/views/screens/teams/teams_screen.dart`)
- **Purpose**: Manage cricket clubs, bilateral opponents, and local rosters.
- **Current UX Sections**:
  1. **Teams Grid / List**: Team logo, name, player count, and win/loss record.
  2. **Create Team Button**: Add new team dialog with logo picker and team color selector.
  3. **Team Detail Bottom Sheet**: View active squad players, match history, and delete/edit options.

### 5.2 `ProfileScreen` (`lib/views/screens/teams/profile_screen.dart`)
- **Purpose**: Detailed career stats and bio for an individual player or scorer.
- **Current UX Sections**:
  1. **Player Bio Header**: Avatar, Full Name, Verified badge, Playing Role, Batting/Bowling styles.
  2. **Batting Career Telemetry**: Matches, Innings, Runs, High Score, Average, Strike Rate, 50s, 100s.
  3. **Bowling Career Telemetry**: Overs, Wickets, Best Bowling Figures, Economy, 3W/5W hauls.
  4. **Recent Matches Log**: Performance cards for player's last 10 games.

### 5.3 `StatsScreen` (`lib/views/screens/teams/stats_screen.dart`)
- **Purpose**: Global app-wide player and team records across all matches scored locally.
- **Current UX Sections**:
  1. **Top Run Scorers**: All-time run charts.
  2. **Top Wicket Takers**: All-time bowling records.
  3. **Team Performance Matrix**: Win percentages, highest team totals, lowest defendable totals.

### 5.4 `RegistrationScreen` (`lib/views/screens/teams/registration_screen.dart`)
- **Purpose**: Player enrollment form for Super Sixty or local leagues.
- **Current UX Sections**:
  1. **Personal Information**: Full Name, Phone, CNIC/ID, Photo Upload.
  2. **Cricket Attributes**: Playing Category (Platinum, Diamond, Gold, Silver), Primary Role.
  3. **Payment / Registration Status**: Verified, Pending, or Draft pool entry.

---

## 6. 🎯 Draft & Auction Engine

### 6.1 `DraftScreen` (`lib/views/screens/draft/draft_screen.dart`)
- **Purpose**: Live player draft and auction system for tournament organizers.
- **Current UX Sections**:
  1. **Draft Order Bar**: Team turn order (Snake Draft or Traditional Round Robin).
  2. **Player Pool Browser**: Search available players, filter by Category (Platinum/Gold) and Playing Role.
  3. **Draft Action Panel**:
     - Pick player for active team.
     - Pass turn.
     - Real-time remaining team purse / budget counter.
  4. **Team Rosters Drawer**: Inspect each team's drafted squad in real-time.
  5. **Apply to Tournament**: 1-click roster export directly populating the tournament's official teams.

---

## 🎨 UI Design Modernization Checklist (Pitch Dynamic Standards)

- [x] **Roman Urdu Elimination**: All screens use clean, professional international cricket English.
- [x] **60Score Rebranding**: Consistent vector squircle logo badge across all screens.
- [x] **Wagon Wheel & Graph Labels**: Clear field zone names and X/Y axes for Worm and Manhattan charts.
- [ ] **Home Screen Clean Sports UI Overhaul**: Implementation of the new non-AI-feel clean white sports cards and 4-card action grid.
- [ ] **Scoring Screen Top Bar Polishing**: Clean striker indicator and international status pills.
