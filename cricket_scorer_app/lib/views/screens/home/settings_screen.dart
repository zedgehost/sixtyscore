import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
// Settings screen (§26): notification preferences, data management
// (backup/restore, player import-export), reset app (§29), appearance
// note, and app info. Offline-first — no accounts, no cloud.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/views/screens/home/about_screen.dart';
import 'package:cricket_scorer_app/views/screens/home/backup_screen.dart';
import 'package:cricket_scorer_app/views/screens/home/login_screen.dart';
import 'package:cricket_scorer_app/views/screens/teams/profile_screen.dart';
import 'package:cricket_scorer_app/views/screens/home/trash_screen.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  final Store store;
  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kNotifMatch = 'set_notif_match';
  static const _kNotifBackup = 'set_notif_backup';

  bool _notifMatch = true;
  bool _notifBackup = true;
  bool _loadedPrefs = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifMatch = prefs.getBool(_kNotifMatch) ?? true;
      _notifBackup = prefs.getBool(_kNotifBackup) ?? true;
    } catch (_) {}
    if (mounted) setState(() => _loadedPrefs = true);
  }

  Future<void> _savePref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'Deletes all teams, players, matches, tournaments and drafts. '
          'The app is left completely empty — nothing is restored. '
          'Backups and exported files are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.store.resetApp();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App reset — all data deleted'),
      ),
    );
  }

  Future<void> _configureCpanelServer() async {
    final client = CpanelApiClient();
    await client.init();
    final ctrl = TextEditingController(text: client.baseUrl);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('cPanel Server Configuration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your cPanel API base URL (e.g. https://api.yourdomain.com/api):',
              style: TextStyle(fontSize: 13, color: PitchTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: PitchTheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                hintText: 'https://api.yourdomain.com/api',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PitchTheme.primary, foregroundColor: PitchTheme.tertiaryFixed),
            onPressed: () async {
              final newUrl = ctrl.text.trim();
              if (newUrl.isNotEmpty) {
                await client.setBaseUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server URL updated to: $newUrl'), backgroundColor: PitchTheme.primary),
                  );
                }
              }
            },
            child: const Text('Save URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncWithCpanel() async {
    final client = CpanelApiClient();
    await client.init();
    final syncService = CpanelSyncService(store: widget.store, apiClient: client);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting cloud sync to cPanel...'), duration: Duration(seconds: 1)),
    );
    final ok = await syncService.syncNow();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Full cloud sync complete! All matches, teams, tournaments, drafts & stats saved.'),
          backgroundColor: PitchTheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync note: Offline or no account token. Local data is 100% safe.'),
        ),
      );
    }
  }

  Future<void> _pullFromCpanel() async {
    final client = CpanelApiClient();
    await client.init();
    final syncService = CpanelSyncService(store: widget.store, apiClient: client);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restoring data from cPanel cloud...'), duration: Duration(seconds: 1)),
    );
    final counts = await syncService.pullAndMerge();
    if (!mounted) return;
    if (counts != null) {
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Restored $total items from cPanel MySQL cloud!'),
          backgroundColor: PitchTheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore note: Offline or sign in with Google first.'),
        ),
      );
    }
  }

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: PitchTheme.secondary),
      title: Text(title, style: const TextStyle(color: PitchTheme.onSurface, fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: PitchTheme.outline, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: PitchTheme.outline),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SectionTitle(
            icon: Icons.account_circle_outlined,
            title: 'Account & Sync',
          ),
          ScoreCard(
            padding: EdgeInsets.zero,
            child: AnimatedBuilder(
              animation: AuthService(),
              builder: (context, _) {
                final auth = AuthService();
                if (auth.isLoggedIn) {
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.verified_user,
                            color: kGreen),
                        title: const Text('Logged in',
                            style: TextStyle(color: PitchTheme.onSurface, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          auth.displayName,
                          style: const TextStyle(
                              color: PitchTheme.outline, fontSize: 12),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.storage_outlined,
                            color: PitchTheme.secondary),
                        title: const Text('Local data',
                            style: TextStyle(color: PitchTheme.onSurface, fontWeight: FontWeight.w700)),
                        // Fully local (v1.4.5): there is no cloud
                        // sync anymore — no auto sync, no manual
                        // sync, no auto retry. The old subtitles
                        // ('syncs automatically', 'will retry
                        // automatically') were false and are gone.
                        subtitle: const Text(
                          'Fully local — your data stays on this phone',
                          style: TextStyle(
                              color: PitchTheme.outline, fontSize: 12),
                        ),
                      ),
                      const Divider(height: 1),
                      _settingsRow(
                        icon: Icons.account_circle,
                        title: 'My Profile',
                        subtitle: 'Your 60Score ID and your own stats',
                        onTap: () => _open(ProfileScreen(store: store)),
                      ),
                      const Divider(height: 1),
                      _settingsRow(
                        icon: Icons.logout,
                        title: 'Log out',
                        subtitle:
                            'Your data stays saved under your account',
                        onTap: () async {
                          // Capture the navigator BEFORE the async
                          // gaps (the builder's context may be gone
                          // by the time they complete).
                          final nav = Navigator.of(context);
                          await auth.signOut();
                          // Hide this account's data right away: the
                          // store switches to the empty locked scope
                          // and the login gate returns, so nobody
                          // opening the app next can see or edit it.
                          await store.activateIdentity('locked');
                          nav.popUntil((r) => r.isFirst);
                        },
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _settingsRow(
                      icon: Icons.login,
                      title: 'Sign in with Google',
                      subtitle:
                          'Unlock match creation, live scoring & cloud sync',
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LoginScreen(store: store)));
                        if (mounted) setState(() {});
                      },
                    ),
                    const Divider(height: 1),
                    _settingsRow(
                      icon: Icons.account_circle,
                      title: 'My Profile',
                      subtitle: 'Log in to get your ID and stats',
                      onTap: () => _open(ProfileScreen(store: store)),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle(
            icon: Icons.cloud_sync_outlined,
            title: 'cPanel Cloud Backend',
          ),
          ScoreCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsRow(
                  icon: Icons.dns_outlined,
                  title: 'cPanel Server URL',
                  subtitle: 'Configure self-hosted cPanel API domain',
                  onTap: _configureCpanelServer,
                ),
                const Divider(height: 1),
                _settingsRow(
                  icon: Icons.sync,
                  title: 'Sync to cPanel MySQL',
                  subtitle: 'Push matches, teams, tournaments, drafts & stats',
                  onTap: _syncWithCpanel,
                ),
                const Divider(height: 1),
                _settingsRow(
                  icon: Icons.cloud_download_outlined,
                  title: 'Restore from cPanel Cloud',
                  subtitle: 'Pull & merge your saved cloud data on this device',
                  onTap: _pullFromCpanel,
                ),
              ],
            ),
          ),
          const SectionTitle(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 2),
            child: Text(
              'Preferences only — no cloud, reminders stay on this device.',
              style: TextStyle(color: PitchTheme.outline, fontSize: 13),
            ),
          ),
          ScoreCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _notifMatch,
                  onChanged: _loadedPrefs
                      ? (v) {
                          setState(() => _notifMatch = v);
                          _savePref(_kNotifMatch, v);
                        }
                      : null,
                  title: const Text(
                    'Match reminders',
                    style: TextStyle(color: PitchTheme.onSurface, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Remind before upcoming fixtures',
                    style: TextStyle(color: PitchTheme.outline, fontSize: 12),
                  ),
                  activeThumbColor: kCyan,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _notifBackup,
                  onChanged: _loadedPrefs
                      ? (v) {
                          setState(() => _notifBackup = v);
                          _savePref(_kNotifBackup, v);
                        }
                      : null,
                  title: const Text(
                    'Backup reminders',
                    style: TextStyle(color: PitchTheme.onSurface, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Remind when no recent backup exists',
                    style: TextStyle(color: PitchTheme.outline, fontSize: 12),
                  ),
                  activeThumbColor: kCyan,
                ),
              ],
            ),
          ),
          const SectionTitle(
            icon: Icons.storage_outlined,
            title: 'Data Management',
          ),
          ScoreCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsRow(
                  icon: Icons.backup,
                  title: 'Backup & Restore',
                  subtitle: 'Manual, automatic and Downloads backups',
                  onTap: () => _open(BackupScreen(store: store)),
                ),
                const Divider(height: 1),
                _settingsRow(
                  icon: Icons.person_outline_rounded,
                  title: 'My Player Profile',
                  subtitle: 'Telemetry, career stats & dossier',
                  onTap: () => _open(ProfileScreen(store: store)),
                ),
                const Divider(height: 1),
                _settingsRow(
                  icon: Icons.delete_sweep,
                  title: 'Trash',
                  subtitle: 'Restore or permanently delete removed items',
                  onTap: () => _open(TrashScreen(store: store)),
                ),
              ],
            ),
          ),
          const SectionTitle(
            icon: Icons.palette_outlined,
            title: 'Appearance',
          ),
          // Info only — the app ships with a single dark navy theme;
          // there is no stored theme preference to toggle.
          const ScoreCard(
            child: Row(
              children: [
                Icon(Icons.dark_mode, color: kGold),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dark theme (default)',
                    style: TextStyle(color: PitchTheme.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ScoreCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: kRed,
              ),
              title: const Text(
                'Reset App',
                style: TextStyle(
                  color: PitchTheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Advanced — permanently delete all data',
                style: TextStyle(color: PitchTheme.outline, fontSize: 12),
              ),
              iconColor: kRed,
              collapsedIconColor: PitchTheme.outline,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScoreButton(
                        label: 'Reset App',
                        icon: Icons.delete_forever,
                        kind: ScoreButtonKind.danger,
                        onPressed: _confirmReset,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(
            icon: Icons.info_outline,
            title: 'About & App Info',
          ),
          ScoreCard(
            padding: EdgeInsets.zero,
            child: _settingsRow(
              icon: Icons.info_outline,
              title: 'About 60Score',
              subtitle: 'Version, credits and description',
              onTap: () => _open(const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
