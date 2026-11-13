import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/core/theme/theme.dart';
import 'package:cricket_scorer_app/views/widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _kVersion = '1.4.9';

  static const _kFeatures = <String>[
    'Match creation & custom rules',
    'Ball-by-ball live cricket scoring',
    'Tournaments & automated points tables',
    'Teams, squads & player career insights',
    'Player drafting & auction system',
    'Tournament leaderboards & statistics',
    'Knockout & playoff bracket automation',
    'Interactive scorecards & wagon wheels',
    'Local data backup & export',
  ];

  Widget _infoRow(String label, String value, {bool last = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: PitchTheme.outline,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: PitchTheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            color: PitchTheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PitchTheme.surface,
      appBar: AppBar(
        title: const Text('About 60Score'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const AppLogo(height: 96),
            const SizedBox(height: 16),
            const Text(
              '60Score',
              style: TextStyle(
                color: PitchTheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cricket Scoring, Simplified.',
              style: TextStyle(
                color: kCyan,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: PitchTheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'OFFLINE-FIRST CRICKET',
                style: TextStyle(
                  color: PitchTheme.tertiaryFixed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Offline-first cricket scoring for clubs, leagues, and tournaments. '
              'Score ball-by-ball, track points tables and NRR, and run '
              'playoffs — no account, no internet needed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PitchTheme.outline, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            const SectionTitle(icon: Icons.info_outline, title: 'App Info'),
            ScoreCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _infoRow('Application', '60Score'),
                  _infoRow('Edition', 'Offline First'),
                  _infoRow('Version', _kVersion, last: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle(icon: Icons.star_outline, title: 'Features'),
            ScoreCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Column(
                children: _kFeatures
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: kCyan,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                f,
                                style: const TextStyle(
                                  color: PitchTheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
