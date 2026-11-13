// 60Score / STUMPS - Guest Mode Read-Only Action Guard
// Guests can browse matches, scorecards, stats, and public tournaments.
// Any create/edit/live-scoring action prompts a 1-tap Google Sign-In upgrade.

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/home/login_screen.dart';

/// Returns `true` if the user is allowed to perform create/score/edit actions.
/// When running in explicit Guest Mode (`AuthService().isRestrictedGuest`),
/// displays a Pitch Dynamic upgrade prompt with 1-tap Google Sign-In.
Future<bool> requireSignedInAction(
  BuildContext context,
  Store store, {
  String actionLabel = 'create or score matches',
}) async {
  final auth = AuthService();
  if (!auth.isRestrictedGuest) return true;

  final upgraded = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: PitchTheme.surfaceContainerLowest,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PitchTheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PitchTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: PitchTheme.onSecondaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guest Mode is View-Only',
                          style: TextStyle(
                            color: PitchTheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sign in with Google to unlock full access',
                          style: TextStyle(
                            color: PitchTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PitchTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'As a guest you can view matches, ball-by-ball scorecards, and stats. Please sign in with Google to $actionLabel.',
                  style: const TextStyle(
                    color: PitchTheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx, true);
                },
                icon: const Icon(Icons.login_rounded, size: 19),
                label: const Text(
                  'Sign In with Google',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PitchTheme.primary,
                  foregroundColor: PitchTheme.tertiaryFixed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx, false),
                child: const Text(
                  'Continue Viewing as Guest',
                  style: TextStyle(
                    color: PitchTheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (upgraded != true || !context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LoginScreen(store: store, gateMode: false),
    ),
  );
  return AuthService().isLoggedIn && !AuthService().needsOnboarding;
}
