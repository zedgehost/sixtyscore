// Modern Pitch Dynamic Player Profile Screen for 60Score
// Displays the active player profile with deterministic Unique ID,
// comprehensive career telemetry across 4 dedicated tabs (Overview,
// Batting, Bowling & Fielding, Matches & Teams), and instant profile editing.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/services/auth/account_profile.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/home/debug_info_screen.dart';
import 'package:cricket_scorer_app/views/screens/home/login_screen.dart';
import 'package:cricket_scorer_app/views/screens/scorecard/scorecard_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Store store;
  final String? playerId;
  final String? playerName;

  const ProfileScreen({
    super.key,
    required this.store,
    this.playerId,
    this.playerName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Store get store => widget.store;

  bool get isOwnProfile =>
      widget.playerId == null ||
      widget.playerId == store.effectiveUserId ||
      (widget.playerName != null &&
          widget.playerName!.trim().isNotEmpty &&
          widget.playerName!.trim().toLowerCase() ==
              store.activeProfile.displayName.trim().toLowerCase());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, AuthService()]),
      builder: (context, _) {
        final AccountProfile profile = isOwnProfile
            ? store.activeProfile
            : store.getProfileForPlayer(widget.playerId!,
                playerName: widget.playerName);

        final CareerStats stats = isOwnProfile
            ? store.computeActiveProfileStats()
            : store.computeStatsForPlayer(widget.playerId!,
                playerName: profile.displayName);

        final auth = AuthService();

        return Scaffold(
          backgroundColor: PitchTheme.surface,
          appBar: AppBar(
            backgroundColor: PitchTheme.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isOwnProfile ? 'My Profile' : '${profile.displayName}\'s Profile',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isOwnProfile || store.findPlayer(profile.uid) != null)
                IconButton(
                  icon: const Icon(Icons.edit_note, color: PitchTheme.tertiaryFixed, size: 26),
                  tooltip: 'Edit Profile',
                  onPressed: () => _showEditProfileSheet(context, profile),
                ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white70, size: 22),
                tooltip: 'Debug & App Info',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DebugInfoScreen(store: store)),
                ),
              ),
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildHeaderCard(context, profile, auth),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: PitchTheme.primary,
                      unselectedLabelColor: PitchTheme.outline,
                      indicatorColor: PitchTheme.secondary,
                      indicatorWeight: 3.5,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Batting'),
                        Tab(text: 'Bowling & Fielding'),
                        Tab(text: 'Matches & Teams'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(profile, stats),
                _buildBattingTab(stats),
                _buildBowlingFieldingTab(stats),
                _buildMatchesAndTeamsTab(profile),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER CARD
  // ---------------------------------------------------------------------------
  Widget _buildHeaderCard(BuildContext context, AccountProfile profile, AuthService auth) {
    final userName = profile.displayName.isNotEmpty ? profile.displayName : 'Player';
    final initial = userName[0].toUpperCase();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: PitchTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          // Avatar with secondary border
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PitchTheme.primaryContainer,
              border: Border.all(color: PitchTheme.secondary, width: 2.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: PitchTheme.tertiaryFixed,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name and Verification Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (profile.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PitchTheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: PitchTheme.onSecondaryContainer, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIED',
                        style: TextStyle(
                          color: PitchTheme.onSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          color: PitchTheme.tertiaryFixed, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'UNVERIFIED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Contact or Local Status Subtitle
          Text(
            profile.isVerified && profile.contact.isNotEmpty
                ? profile.contact
                : 'Local Player • Not linked to email',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Unique ID Chip with One-Tap Copy
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: profile.userCode));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('60Score ID "${profile.userCode}" copied to clipboard!'),
                  backgroundColor: PitchTheme.secondary,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: PitchTheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: PitchTheme.secondaryContainer.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined, color: PitchTheme.tertiaryFixed, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'ID: ${profile.userCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, color: PitchTheme.tertiaryFixed, size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Attribute Chips (Role, Jersey, Styles, City)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeaderBadge(Icons.sports_cricket, profile.role),
                const SizedBox(width: 6),
                _buildHeaderBadge(Icons.tag, '#${profile.jerseyNumber}'),
                const SizedBox(width: 6),
                _buildHeaderBadge(Icons.sports, profile.battingStyleShort),
                if (profile.bowlingStyleShort != '-') ...[
                  const SizedBox(width: 6),
                  _buildHeaderBadge(Icons.sports_baseball, profile.bowlingStyleShort),
                ],
                if (profile.city.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildHeaderBadge(Icons.location_on_outlined, profile.city),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PitchTheme.tertiaryFixed, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OVERVIEW
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab(AccountProfile profile, CareerStats stats) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Text(
            'CAREER SNAPSHOT',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // 6 Key Stat Cards Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildMiniMetricCard('Matches', '${stats.matches}', Icons.sports_cricket),
              _buildMiniMetricCard('Total Runs', '${stats.runs}', Icons.trending_up),
              _buildMiniMetricCard('High Score', '${stats.highScore}', Icons.stars),
              _buildMiniMetricCard('Wickets', '${stats.wickets}', Icons.sports_baseball),
              _buildMiniMetricCard('Best Bowl', stats.bestFigures, Icons.military_tech),
              _buildMiniMetricCard('Catches', '${stats.catches}', Icons.pan_tool_alt),
            ],
          ),
          const SizedBox(height: 20),

          // Player Bio Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PitchTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.person_pin, color: PitchTheme.secondary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cricket Identity & Bio',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildBioRow('Playing Role', profile.role),
                _buildBioRow('Batting Style', profile.battingStyle),
                _buildBioRow('Bowling Style', profile.bowlingStyle),
                _buildBioRow('Jersey Number', '#${profile.jerseyNumber}'),
                _buildBioRow('City / Hometown', profile.city.isNotEmpty ? profile.city : 'Not Specified'),
                _buildBioRow('Contact', profile.contact.isNotEmpty ? profile.contact : 'Local Device Profile'),
                _buildBioRow('Account Scope', 'Ready for Live Online Sign-In'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.offline_bolt, color: PitchTheme.secondary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All career numbers update automatically as matches are scored on your device.',
                    style: TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cloud Account & Sync / Claim Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PitchTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      profile.isVerified
                          ? Icons.verified_user_rounded
                          : Icons.shield_outlined,
                      color: PitchTheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.isVerified
                            ? 'Verified 60Score Account'
                            : 'Claim / Verify Player Profile',
                        style: const TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  profile.isVerified
                      ? 'This player profile is verified and linked to ${profile.contact}. Match telemetry and career records are preserved with your 60Score ID.'
                      : 'This profile is currently managed locally on this device. Link an email to claim this profile, unlock verified status, and sync career figures.',
                  style: const TextStyle(
                    color: PitchTheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (!profile.isVerified) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LoginScreen(store: store)),
                        );
                      },
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text(
                        isOwnProfile
                            ? 'Sign in with Google'
                            : 'Link Google / Claim Profile',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PitchTheme.primary,
                        foregroundColor: PitchTheme.tertiaryFixed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bug_report_outlined, color: PitchTheme.outline),
                    title: const Text(
                      'Debug info',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PitchTheme.onSurface,
                      ),
                    ),
                    subtitle: const Text(
                      'App version, sync status, identity & local storage metrics',
                      style: TextStyle(fontSize: 11, color: PitchTheme.outline),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: PitchTheme.outline),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DebugInfoScreen(store: store)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: PitchTheme.secondary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: PitchTheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: PitchTheme.outline,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBioRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: PitchTheme.outline,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: PitchTheme.onSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: BATTING RECORDS
  // ---------------------------------------------------------------------------
  Widget _buildBattingTab(CareerStats stats) {
    final avg = stats.battingAverage.toStringAsFixed(2);
    final sr = stats.battingSR.toStringAsFixed(2);
    final boundaryRuns = (stats.fours * 4) + (stats.sixes * 6);
    final boundaryPct = stats.runs > 0
        ? ((boundaryRuns / stats.runs) * 100).toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BATTING TELEMETRY',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Main Batting Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PitchTheme.cardShadow,
            ),
            child: Column(
              children: [
                _buildStatTile('Innings Batted', '${stats.inningsBatted}'),
                const Divider(),
                _buildStatTile('Not Outs', '${stats.notOuts}'),
                const Divider(),
                _buildStatTile('Total Runs', '${stats.runs}', isHighlighted: true),
                const Divider(),
                _buildStatTile('Balls Faced', '${stats.ballsFaced}'),
                const Divider(),
                _buildStatTile('Highest Score', '${stats.highScore}', isHighlighted: true),
                const Divider(),
                _buildStatTile('Batting Average', avg),
                const Divider(),
                _buildStatTile('Strike Rate', sr, isHighlighted: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'BOUNDARIES & MILESTONES',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _buildMilestoneCard('Centuries (100s)', '${stats.hundreds}', Icons.military_tech),
              _buildMilestoneCard('Half-Centuries (50s)', '${stats.fifties}', Icons.stars),
              _buildMilestoneCard('Fours (4s)', '${stats.fours}', Icons.filter_4),
              _buildMilestoneCard('Sixes (6s)', '${stats.sixes}', Icons.filter_6),
              _buildMilestoneCard('Boundary Runs', '$boundaryRuns', Icons.speed),
              _buildMilestoneCard('Boundary %', '$boundaryPct%', Icons.pie_chart_outline),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: BOWLING & FIELDING
  // ---------------------------------------------------------------------------
  Widget _buildBowlingFieldingTab(CareerStats stats) {
    final overs = '${stats.ballsBowled ~/ 6}.${stats.ballsBowled % 6}';
    final econ = stats.economy.toStringAsFixed(2);
    final bowlAvg = stats.bowlingAverage.toStringAsFixed(2);
    final bowlSr = stats.bowlingSR.toStringAsFixed(2);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BOWLING TELEMETRY',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PitchTheme.cardShadow,
            ),
            child: Column(
              children: [
                _buildStatTile('Overs Bowled', overs),
                const Divider(),
                _buildStatTile('Balls Bowled', '${stats.ballsBowled}'),
                const Divider(),
                _buildStatTile('Runs Conceded', '${stats.runsConceded}'),
                const Divider(),
                _buildStatTile('Wickets Taken', '${stats.wickets}', isHighlighted: true),
                const Divider(),
                _buildStatTile('Best Bowling (BBM)', stats.bestFigures, isHighlighted: true),
                const Divider(),
                _buildStatTile('Economy Rate', econ),
                const Divider(),
                _buildStatTile('Bowling Average', bowlAvg),
                const Divider(),
                _buildStatTile('Bowling Strike Rate', bowlSr),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'FIELDING & DISMISSALS',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              _buildMilestoneCard('Catches', '${stats.catches}', Icons.pan_tool_alt),
              _buildMilestoneCard('Run Outs', '${stats.runOuts}', Icons.run_circle_outlined),
              _buildMilestoneCard('Stumpings', '${stats.stumpings}', Icons.sports_cricket),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: PitchTheme.outline,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? PitchTheme.primary : PitchTheme.onSurface,
                fontSize: isHighlighted ? 15 : 13.5,
                fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: PitchTheme.cardShadow,
        border: Border.all(color: PitchTheme.surfaceContainerLow),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PitchTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: PitchTheme.secondary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: PitchTheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: PitchTheme.outline,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: MATCHES & TEAMS
  // ---------------------------------------------------------------------------
  Widget _buildMatchesAndTeamsTab(AccountProfile profile) {
    final targetName = profile.displayName.trim().toLowerCase();
    final targetUid = profile.uid;
    final targetCode = profile.userCode;

    // Filter teams player belongs to
    final myTeams = store.teams.where((t) {
      return t.players.any((p) =>
          p.name.trim().toLowerCase() == targetName ||
          p.id == targetUid ||
          (p.userCode != null && p.userCode == targetCode));
    }).toList();

    // Filter matches player played in
    final myMatches = store.matches.where((m) {
      final inXiA = m.xiA.contains(targetUid);
      final inXiB = m.xiB.contains(targetUid);
      final teamA = store.teamById(m.teamAId);
      final teamB = store.teamById(m.teamBId);
      final inA = teamA != null &&
          teamA.players.any((p) =>
              p.name.trim().toLowerCase() == targetName ||
              p.id == targetUid ||
              (p.userCode != null && p.userCode == targetCode));
      final inB = teamB != null &&
          teamB.players.any((p) =>
              p.name.trim().toLowerCase() == targetName ||
              p.id == targetUid ||
              (p.userCode != null && p.userCode == targetCode));
      return inXiA || inXiB || inA || inB || (isOwnProfile && m.creatorId == targetUid);
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TEAMS SECTION
          const Text(
            'TEAMS PLAYED FOR',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (myTeams.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No teams found with this player yet.\nAdd this player to any squad to link team stats.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PitchTheme.outline, fontSize: 12),
                ),
              ),
            )
          else
            ...myTeams.map((team) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: PitchTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: PitchTheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            color: PitchTheme.tertiaryFixed,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: const TextStyle(
                              color: PitchTheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${team.players.length} Squad Members',
                            style: const TextStyle(
                              color: PitchTheme.outline,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 20),

          // MATCHES SECTION
          const Text(
            'MATCH PERFORMANCE LOG',
            style: TextStyle(
              color: PitchTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (myMatches.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PitchTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No match appearances recorded yet.',
                  style: TextStyle(color: PitchTheme.outline, fontSize: 12),
                ),
              ),
            )
          else
            ...myMatches.map((m) {
              final teamA = store.teamById(m.teamAId)?.name ?? 'Team A';
              final teamB = store.teamById(m.teamBId)?.name ?? 'Team B';
              final isCreator = m.canUserScore(store.effectiveUserId, userCode: store.effectiveUserCode);

              // Extract player's batting and bowling figures in this match
              var runs = 0;
              var balls = 0;
              var didBat = false;
              var wkts = 0;
              var runsConceded = 0;
              var didBowl = false;

              for (final inn in m.innings) {
                inn.batting.forEach((pid, fig) {
                  final pName = store.playerName(pid).toLowerCase();
                  if (pName == targetName || pid == targetUid) {
                    if (fig.batted) {
                      didBat = true;
                      runs += fig.runs;
                      balls += fig.balls;
                    }
                  }
                });
                inn.bowling.forEach((pid, fig) {
                  final pName = store.playerName(pid).toLowerCase();
                  if (pName == targetName || pid == targetUid) {
                    if (fig.legalBalls > 0) {
                      didBowl = true;
                      wkts += fig.wickets;
                      runsConceded += fig.runs;
                    }
                  }
                });
              }

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScorecardScreen(store: store, match: m),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: PitchTheme.cardShadow,
                    border: Border.all(color: PitchTheme.surfaceContainerLow),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$teamA vs $teamB',
                              style: const TextStyle(
                                color: PitchTheme.onSurface,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: m.status == 'completed'
                                  ? PitchTheme.secondaryContainer
                                  : PitchTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              m.status.toUpperCase(),
                              style: TextStyle(
                                color: m.status == 'completed'
                                    ? PitchTheme.onSecondaryContainer
                                    : PitchTheme.tertiaryFixed,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (didBat) ...[
                            const Icon(Icons.sports_cricket, size: 14, color: PitchTheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              'Bat: $runs ($balls)',
                              style: const TextStyle(
                                color: PitchTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (didBowl) ...[
                            const Icon(Icons.sports_baseball, size: 14, color: PitchTheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              'Bowl: $wkts/$runsConceded',
                              style: const TextStyle(
                                color: PitchTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (!didBat && !didBowl) ...[
                            Flexible(
                              child: Text(
                                isCreator ? 'Match Creator / Scorer' : 'Squad Member',
                                style: const TextStyle(
                                  color: PitchTheme.outline,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const Spacer(),
                          const Text(
                            'Match Centre →',
                            style: TextStyle(
                              color: PitchTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT PROFILE BOTTOM SHEET
  // ---------------------------------------------------------------------------
  void _showEditProfileSheet(BuildContext context, AccountProfile profile) {
    final nameCtrl = TextEditingController(text: profile.displayName);
    final jerseyCtrl = TextEditingController(text: '${profile.jerseyNumber}');
    final cityCtrl = TextEditingController(text: profile.city);
    final contactCtrl = TextEditingController(text: profile.contact);

    var role = profile.role;
    var battingStyle = profile.battingStyle;
    var bowlingStyle = profile.bowlingStyle;

    final roles = ['All-Rounder', 'Batter', 'Bowler', 'Wicket-Keeper'];
    final batStyles = ['Right-hand bat', 'Left-hand bat'];
    final bowlStyles = [
      'Right-arm fast-medium',
      'Right-arm fast',
      'Right-arm medium',
      'Right-arm spin',
      'Left-arm fast',
      'Left-arm spin',
      'None'
    ];

    if (!roles.contains(role)) role = roles.first;
    if (!batStyles.contains(battingStyle)) battingStyle = batStyles.first;
    if (!bowlStyles.contains(bowlingStyle)) bowlingStyle = bowlStyles.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              decoration: const BoxDecoration(
                color: PitchTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Player Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: PitchTheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Display Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Player Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Playing Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sports_cricket),
                      ),
                      items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => role = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Batting Style
                    DropdownButtonFormField<String>(
                      initialValue: battingStyle,
                      decoration: const InputDecoration(
                        labelText: 'Batting Style',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sports),
                      ),
                      items: batStyles.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => battingStyle = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Bowling Style
                    DropdownButtonFormField<String>(
                      initialValue: bowlingStyle,
                      decoration: const InputDecoration(
                        labelText: 'Bowling Style',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sports_baseball),
                      ),
                      items: bowlStyles.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => bowlingStyle = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Jersey Number & City Row
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: jerseyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jersey #',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City / Region',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_city),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Contact
                    TextField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact (Email / Phone)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: PitchTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final newName = nameCtrl.text.trim();
                          final newJersey = int.tryParse(jerseyCtrl.text.trim()) ?? 7;
                          final newCity = cityCtrl.text.trim();
                          final newContact = contactCtrl.text.trim();

                          final updated = profile.copyWith(
                            displayName: newName.isNotEmpty ? newName : 'Player',
                            role: role,
                            battingStyle: battingStyle,
                            bowlingStyle: bowlingStyle,
                            jerseyNumber: newJersey,
                            city: newCity,
                            contact: newContact,
                          );

                          if (isOwnProfile) {
                            await store.saveActiveProfile(updated);
                          } else {
                            final pl = store.findPlayer(profile.uid);
                            if (pl != null) {
                              pl.name = newName.isNotEmpty ? newName : pl.name;
                              pl.role = role;
                              pl.battingStyle = battingStyle;
                              pl.bowlingStyle = bowlingStyle;
                              pl.jerseyNo = newJersey;
                              pl.city = newCity;
                              if (newContact.contains('@')) {
                                pl.email = newContact;
                                pl.isVerified = true;
                              }
                              await store.persist();
                            }
                          }
                          if (ctx.mounted) Navigator.pop(sheetCtx);
                        },
                        child: const Text(
                          'Save Profile Changes',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: PitchTheme.surfaceContainerLowest,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
