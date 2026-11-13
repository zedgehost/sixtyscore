// Modern Pitch Dynamic Profile Redirect
// Replaces the legacy draft registration pool with the active player profile dossier.
// Displays the authenticated/active player profile with telemetry across 4 tabs:
// Overview, Batting, Bowling & Fielding, Matches & Teams.
import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/views/screens/teams/profile_screen.dart';

class RegistrationScreen extends StatelessWidget {
  final Store store;
  const RegistrationScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(store: store);
  }
}
