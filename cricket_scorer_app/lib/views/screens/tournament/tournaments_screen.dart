// 60Score / STUMPS - Modernized Tournaments Screen & Creation System
// Pitch Dynamic design system tokens, responsive zero-overflow layout,
// multi-format leagues, overs selection, team quick-add, and offline auto-sync.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/services/api/cpanel_api_client.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/services/sync/cpanel_sync_service.dart';
import 'package:cricket_scorer_app/services/sync/publish_service.dart';
import 'package:cricket_scorer_app/views/screens/home/scorer_home_screen.dart';
import 'package:cricket_scorer_app/views/screens/tournament/published_search_screen.dart';
import 'package:cricket_scorer_app/views/widgets/guest_guard.dart';

/// Shows a modernized Pitch Dynamic tournament creation or editing modal dialog.
Future<Tournament?> showTournamentEditDialog(
  BuildContext context,
  Store store,
  Tournament? existing,
) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final venueCtrl = TextEditingController(text: existing?.venue ?? '');
  var logoBase64 = existing?.logoBase64 ?? '';
  var oversLimit = existing?.oversLimit ?? 8;
  var format = existing?.format.isNotEmpty == true ? existing!.format : 'Round Robin';
  var ballType = existing?.ballType.isNotEmpty == true ? existing!.ballType : 'Tennis Ball';
  var startDateIso = existing?.startDateIso.isNotEmpty == true
      ? existing!.startDateIso
      : DateTime.now().toIso8601String().substring(0, 10);

  final selectedTeamIds = List<String>.from(existing?.teamIds ?? []);

  final standardOvers = [5, 6, 8, 10, 12, 15, 20, 50];
  var isCustomOvers = !standardOvers.contains(oversLimit);
  final customOversCtrl = TextEditingController(text: isCustomOvers ? '$oversLimit' : '');

  Future<void> pickLogo(StateSetter setD) async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (img != null) {
        final bytes = await img.readAsBytes();
        setD(() => logoBase64 = base64Encode(bytes));
      }
    } catch (_) {}
  }

  Future<void> quickCreateTeam(BuildContext ctx, StateSetter setD) async {
    final teamNameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quick Add Team',
          style: TextStyle(
            color: PitchTheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: teamNameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Rawalpindi Strikers',
            filled: true,
            fillColor: PitchTheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PitchTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (teamNameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(c, true);
              }
            },
            child: const Text('Add Team', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && teamNameCtrl.text.trim().isNotEmpty) {
      final newTeam = Team(
        id: Store.newId('team'),
        name: teamNameCtrl.text.trim(),
      );
      await store.upsertTeam(newTeam);
      setD(() {
        if (!selectedTeamIds.contains(newTeam.id)) {
          selectedTeamIds.add(newTeam.id);
        }
      });
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
    }
  }

  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) {
        return Dialog(
          backgroundColor: PitchTheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                  decoration: BoxDecoration(
                    color: PitchTheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PitchTheme.tertiaryFixed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.emoji_events,
                            color: PitchTheme.primaryContainer,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              existing == null ? 'Create Tournament' : 'Edit Tournament',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Setup format, overs, venue & teams',
                              style: TextStyle(
                                color: PitchTheme.tertiaryFixed,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(c, false),
                      ),
                    ],
                  ),
                ),

                // Form Body
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Tournament Name
                        const Text(
                          'TOURNAMENT NAME *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: PitchTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. Islamabad Super League 2026',
                            prefixIcon: const Icon(Icons.military_tech_outlined, color: PitchTheme.secondary),
                            filled: true,
                            fillColor: PitchTheme.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: PitchTheme.secondary, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Tournament Format
                        const Text(
                          'COMPETITION FORMAT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: PitchTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              for (final f in ['Round Robin', 'League + Playoffs', 'Knockout'])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(f),
                                    selected: format == f,
                                    selectedColor: PitchTheme.primary,
                                    backgroundColor: PitchTheme.surfaceContainerLow,
                                    labelStyle: TextStyle(
                                      color: format == f ? PitchTheme.tertiaryFixed : PitchTheme.onSurface,
                                      fontWeight: format == f ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    onSelected: (val) {
                                      if (val) setD(() => format = f);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Overs & Ball Type
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overs Selector
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'OVERS PER INNINGS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: PitchTheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    initialValue: isCustomOvers ? -1 : oversLimit,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: PitchTheme.surfaceContainerLow,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    items: [
                                      ...standardOvers.map((o) => DropdownMenuItem(
                                            value: o,
                                            child: Text(
                                              '$o Overs',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          )),
                                      const DropdownMenuItem(
                                        value: -1,
                                        child: Text(
                                          'Custom...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: PitchTheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      setD(() {
                                        if (v == -1) {
                                          isCustomOvers = true;
                                          final parsed = int.tryParse(customOversCtrl.text.trim());
                                          if (parsed != null && parsed > 0) {
                                            oversLimit = parsed;
                                          }
                                        } else {
                                          isCustomOvers = false;
                                          oversLimit = v ?? 8;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Ball Type
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'BALL TYPE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: PitchTheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: ballType,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: PitchTheme.surfaceContainerLow,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Tennis Ball', child: Text('Tennis Ball', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'Tape Ball', child: Text('Tape Ball', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'Leather Ball', child: Text('Leather Ball', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (v) => setD(() => ballType = v ?? 'Tennis Ball'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isCustomOvers) ...[
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CUSTOM OVERS (1 - 100)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: PitchTheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: customOversCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  hintText: 'Enter number of overs (e.g. 2, 4, 7, 25)',
                                  prefixIcon: const Icon(Icons.sports_cricket, size: 18, color: PitchTheme.secondary),
                                  filled: true,
                                  fillColor: PitchTheme.surfaceContainerLow,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: PitchTheme.secondary, width: 1.5),
                                  ),
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val.trim());
                                  if (parsed != null && parsed > 0 && parsed <= 100) {
                                    oversLimit = parsed;
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // 4. Venue & Date
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'VENUE / GROUND',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: PitchTheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: venueCtrl,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. National Stadium',
                                      prefixIcon: const Icon(Icons.stadium_outlined, color: PitchTheme.secondary, size: 20),
                                      filled: true,
                                      fillColor: PitchTheme.surfaceContainerLow,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'START DATE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: PitchTheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: c,
                                        initialDate: DateTime.tryParse(startDateIso) ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setD(() => startDateIso = picked.toIso8601String().substring(0, 10));
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: PitchTheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 18, color: PitchTheme.secondary),
                                          const SizedBox(width: 8),
                                          Text(
                                            startDateIso,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. Tournament Logo Uploader
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PitchTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: PitchTheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                child: logoBase64.isEmpty
                                    ? const Icon(Icons.emoji_events_outlined, color: PitchTheme.secondary, size: 28)
                                    : Image.memory(
                                        base64Decode(logoBase64),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.emoji_events_outlined, color: PitchTheme.outline),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tournament Emblem / Logo',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Upload square graphic for fixture banners',
                                      style: TextStyle(color: PitchTheme.outline, fontSize: 11),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => pickLogo(setD),
                                          child: Text(
                                            logoBase64.isEmpty ? '+ Pick Image' : 'Change Image',
                                            style: const TextStyle(
                                              color: PitchTheme.secondary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (logoBase64.isNotEmpty) ...[
                                          const SizedBox(width: 14),
                                          InkWell(
                                            onTap: () => setD(() => logoBase64 = ''),
                                            child: const Text(
                                              'Remove',
                                              style: TextStyle(
                                                color: PitchTheme.error,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 6. Participating Teams Selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PARTICIPATING TEAMS (${selectedTeamIds.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: PitchTheme.onSurfaceVariant,
                              ),
                            ),
                            Row(
                              children: [
                                if (store.teams.isNotEmpty) ...[
                                  InkWell(
                                    onTap: () {
                                      setD(() {
                                        if (selectedTeamIds.length == store.teams.length) {
                                          selectedTeamIds.clear();
                                        } else {
                                          selectedTeamIds
                                            ..clear()
                                            ..addAll(store.teams.map((e) => e.id));
                                        }
                                      });
                                    },
                                    child: Text(
                                      selectedTeamIds.length == store.teams.length ? 'Deselect All' : 'Select All',
                                      style: const TextStyle(
                                        color: PitchTheme.secondary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                InkWell(
                                  onTap: () => quickCreateTeam(context, setD),
                                  child: const Text(
                                    '+ New Team',
                                    style: TextStyle(
                                      color: PitchTheme.secondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (store.teams.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PitchTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: PitchTheme.outline),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No teams in database yet. Tap "+ New Team" to add participating squads.',
                                    style: TextStyle(fontSize: 11.5, color: PitchTheme.outline),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final team in store.teams)
                                FilterChip(
                                  label: Text(team.name),
                                  selected: selectedTeamIds.contains(team.id),
                                  selectedColor: PitchTheme.secondaryContainer,
                                  checkmarkColor: PitchTheme.onSecondaryContainer,
                                  backgroundColor: PitchTheme.surfaceContainerLow,
                                  labelStyle: TextStyle(
                                    color: selectedTeamIds.contains(team.id)
                                        ? PitchTheme.onSecondaryContainer
                                        : PitchTheme.onSurface,
                                    fontWeight: selectedTeamIds.contains(team.id)
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  onSelected: (selected) {
                                    setD(() {
                                      if (selected) {
                                        selectedTeamIds.add(team.id);
                                      } else {
                                        selectedTeamIds.remove(team.id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLowest,
                    border: Border(top: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.3))),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(c, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: PitchTheme.outlineVariant.withValues(alpha: 0.6)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: PitchTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a tournament name.')),
                              );
                              return;
                            }
                            if (isCustomOvers) {
                              final parsed = int.tryParse(customOversCtrl.text.trim());
                              if (parsed == null || parsed <= 0 || parsed > 100) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid number of overs (1-100).')),
                                );
                                return;
                              }
                              oversLimit = parsed;
                            }
                            Navigator.pop(c, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PitchTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            existing == null ? 'Create Tournament' : 'Save Changes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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
  );

  if (saved != true || nameCtrl.text.trim().isEmpty) return null;

  if (existing == null) {
    final t = Tournament(
      id: Store.newId('tournament'),
      name: nameCtrl.text.trim(),
      teamIds: selectedTeamIds,
      venue: venueCtrl.text.trim(),
      logoBase64: logoBase64,
      oversLimit: oversLimit,
      format: format,
      ballType: ballType,
      startDateIso: startDateIso,
      creatorId: store.effectiveUserId,
      published: true,
    );
    await store.upsertTournament(t);
    unawaited(() async {
      try {
        final client = CpanelApiClient();
        await client.init();
        CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
      } catch (_) {}
    }());
    return t;
  }

  existing.name = nameCtrl.text.trim();
  existing.venue = venueCtrl.text.trim();
  existing.logoBase64 = logoBase64;
  existing.oversLimit = oversLimit;
  existing.format = format;
  existing.ballType = ballType;
  existing.startDateIso = startDateIso;
  existing.teamIds = selectedTeamIds;
  if (existing.creatorId.isEmpty) {
    existing.creatorId = store.effectiveUserId;
  }
  await store.persistTournamentsOnly();
  unawaited(() async {
    try {
      final client = CpanelApiClient();
      await client.init();
      CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
    } catch (_) {}
  }());
  return existing;
}

/// Modern Pitch Dynamic Tournament Card
class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final int teamCount;
  final int matchCount;
  final bool loggedIn;
  final VoidCallback onTap;
  final VoidCallback onTogglePublish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TournamentCard({
    super.key,
    required this.tournament,
    required this.teamCount,
    required this.matchCount,
    required this.loggedIn,
    required this.onTap,
    required this.onTogglePublish,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final doneCount = t.qualificationFinalized ? matchCount : 0;
    final progress = matchCount > 0 ? (doneCount / matchCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with Trophy/Logo & Chips
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: PitchTheme.tertiaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: t.logoBase64.isNotEmpty
                          ? Image.memory(
                              base64Decode(t.logoBase64),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.emoji_events,
                                color: PitchTheme.primaryContainer,
                                size: 24,
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.emoji_events,
                                color: PitchTheme.primaryContainer,
                                size: 24,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: const TextStyle(
                                    color: PitchTheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: PitchTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${t.oversLimit}O',
                                  style: const TextStyle(
                                    color: PitchTheme.tertiaryFixed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.format.toUpperCase()} • ${t.ballType}',
                                  style: const TextStyle(
                                    color: PitchTheme.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (t.published) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: PitchTheme.secondaryContainer.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Published',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: PitchTheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Info Row (Venue, Teams, Matches)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: PitchTheme.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        t.venue.isNotEmpty ? t.venue : 'Ground to be scheduled',
                        style: const TextStyle(color: PitchTheme.onSurfaceVariant, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: PitchTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups, size: 13, color: PitchTheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            '$teamCount Teams',
                            style: const TextStyle(
                              color: PitchTheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. Progress Track
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$matchCount Fixtures Scheduled',
                        style: const TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% Done',
                      style: const TextStyle(
                        color: PitchTheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : (matchCount > 0 ? 0.05 : 0.0),
                    backgroundColor: PitchTheme.surfaceContainer,
                    valueColor: const AlwaysStoppedAnimation<Color>(PitchTheme.secondary),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Flexible(
                            child: Text(
                              'View Details',
                              style: TextStyle(
                                color: PitchTheme.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 13, color: PitchTheme.secondary),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loggedIn)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: Icon(
                              t.published ? Icons.public : Icons.public_off,
                              size: 19,
                              color: t.published ? PitchTheme.secondary : PitchTheme.outline,
                            ),
                            tooltip: t.published ? 'Unpublish' : 'Publish',
                            onPressed: onTogglePublish,
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.edit, size: 19, color: PitchTheme.onSurfaceVariant),
                          tooltip: 'Edit Tournament',
                          onPressed: onEdit,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.delete_outline, size: 19, color: PitchTheme.error),
                          tooltip: 'Delete Tournament',
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern Tournaments Screen with search, filters, pull-to-refresh & empty states
class TournamentsScreen extends StatefulWidget {
  final Store store;
  const TournamentsScreen({super.key, required this.store});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  Store get store => widget.store;
  String _searchFilter = '';
  String _selectedTab = 'All'; // 'All', 'Active', 'Completed'

  @override
  void initState() {
    super.initState();
    store.addListener(_onChanged);
    AuthService().addListener(_onChanged);
    store.purgeOrphanTournamentMatches();
  }

  @override
  void dispose() {
    store.removeListener(_onChanged);
    AuthService().removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _editTournament(Tournament? existing) async {
    if (!await requireSignedInAction(
      context,
      store,
      actionLabel: 'create or edit tournaments',
    )) {
      return;
    }
    if (!mounted) return;
    final t = await showTournamentEditDialog(context, store, existing);
    if (t != null && mounted) setState(() {});
  }

  Future<void> _togglePublish(Tournament t) async {
    if (!await requireSignedInAction(
      context,
      store,
      actionLabel: 'publish tournaments',
    )) {
      return;
    }
    if (!mounted) return;
    final wasPublished = t.published;
    final svc = PublishService();
    final err = wasPublished ? await svc.unpublish(store, t) : await svc.publish(store, t);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ??
              (wasPublished
                  ? 'Unpublished — tournament is now local.'
                  : 'Published — anyone can view standings in Explore.'),
        ),
      ),
    );
  }

  Future<void> _deleteTournament(Tournament t) async {
    if (!await requireSignedInAction(
      context,
      store,
      actionLabel: 'delete tournaments',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: PitchTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Tournament?'),
        content: Text(
          'Delete "${t.name}"? This will permanently delete this tournament and ALL of its scheduled, live, and completed matches across all screens, devices, and server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: PitchTheme.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PitchTheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (t.published) PublishService().deletePublishedDoc(t.id);
      await store.deleteTournament(t.id);
      unawaited(() async {
        try {
          final client = CpanelApiClient();
          await client.init();
          await client.deleteTournament(t.id);
          CpanelSyncService(store: store, apiClient: client).triggerAutoSync();
        } catch (_) {}
      }());
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = store.effectiveUserId;
    var list = store.tournaments.where((t) {
      if (t.creatorId.isEmpty) return true;
      return uid.isNotEmpty && t.creatorId == uid;
    }).toList();

    // Search filter
    if (_searchFilter.trim().isNotEmpty) {
      final q = _searchFilter.trim().toLowerCase();
      list = list.where((t) => t.name.toLowerCase().contains(q) || t.venue.toLowerCase().contains(q)).toList();
    }

    // Tab filter
    if (_selectedTab == 'Completed') {
      list = list.where((t) => t.qualificationFinalized).toList();
    } else if (_selectedTab == 'Active') {
      list = list.where((t) => !t.qualificationFinalized).toList();
    }

    final loggedIn = AuthService().isLoggedIn;

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      appBar: AppBar(
        backgroundColor: PitchTheme.primary,
        elevation: 0,
        title: const Text(
          'Tournaments',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.public, color: PitchTheme.tertiaryFixed),
            tooltip: 'Explore Public Tournaments',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PublishedSearchScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PitchTheme.primary,
        onPressed: () => _editTournament(null),
        icon: const Icon(Icons.add, color: PitchTheme.tertiaryFixed),
        label: const Text(
          'New Tournament',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        color: PitchTheme.primary,
        onRefresh: () async {
          try {
            final client = CpanelApiClient();
            await client.init();
            if (client.token != null && client.token!.isNotEmpty) {
              await CpanelSyncService(store: store, apiClient: client).pullAndMerge();
              if (mounted) setState(() {});
            }
          } catch (_) {}
        },
        child: Column(
          children: [
            // Filter & Search bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: PitchTheme.surfaceContainerLowest,
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchFilter = val),
                    decoration: InputDecoration(
                      hintText: 'Search tournaments by name or venue...',
                      hintStyle: const TextStyle(fontSize: 13, color: PitchTheme.outline),
                      prefixIcon: const Icon(Icons.search, size: 20, color: PitchTheme.secondary),
                      filled: true,
                      fillColor: PitchTheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final tab in ['All', 'Active', 'Completed'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tab),
                            selected: _selectedTab == tab,
                            selectedColor: PitchTheme.primary,
                            backgroundColor: PitchTheme.surfaceContainerLow,
                            labelStyle: TextStyle(
                              color: _selectedTab == tab ? PitchTheme.tertiaryFixed : PitchTheme.onSurface,
                              fontWeight: _selectedTab == tab ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedTab = tab);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Tournaments List or Empty State
            Expanded(
              child: list.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(
                                      color: PitchTheme.surfaceContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.emoji_events_outlined,
                                        size: 34,
                                        color: PitchTheme.secondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _searchFilter.isNotEmpty
                                        ? 'No Tournaments Match "$_searchFilter"'
                                        : 'No Tournaments Created Yet',
                                    style: const TextStyle(
                                      color: PitchTheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Create a league tournament to track team standings, generate automatic round-robin schedules, and crown champions.',
                                    style: TextStyle(
                                      color: PitchTheme.outline,
                                      fontSize: 12.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () => _editTournament(null),
                                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                    label: const Text(
                                      'Create Tournament',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PitchTheme.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final t = list[i];
                        final teamCount = t.teamIds.length;
                        final matchCount = store.matches.where((m) => m.tournamentId == t.id).length;
                        return TournamentCard(
                          tournament: t,
                          teamCount: teamCount,
                          matchCount: matchCount,
                          loggedIn: loggedIn,
                          onTogglePublish: () => _togglePublish(t),
                          onEdit: () => _editTournament(t),
                          onDelete: () => _deleteTournament(t),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentDetailScreen(
                                store: store,
                                tournament: t,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) setState(() {});
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
