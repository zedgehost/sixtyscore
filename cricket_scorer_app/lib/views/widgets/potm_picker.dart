// "Select Player of the Match" dialog.
//
// Shows the auto-generated shortlist (max 3, ranked by actual match stats).
// The user taps one candidate and confirms; "Skip" returns null so the
// caller can auto-select the highest-ranked candidate. The award is saved
// on the match (update, never duplicate).
import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/domain/potm/potm.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/views/widgets/player_avatar.dart';

/// Opens the dialog. Returns the chosen playerId, or null when skipped.
Future<String?> showPotmPickerDialog(
  BuildContext context,
  Store store,
  Match match,
) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (c) => _PotmDialog(store: store, match: match),
  );
}

class _PotmDialog extends StatefulWidget {
  final Store store;
  final Match match;
  const _PotmDialog({required this.store, required this.match});

  @override
  State<_PotmDialog> createState() => _PotmDialogState();
}

class _PotmDialogState extends State<_PotmDialog> {
  late final List<PotmCandidate> _candidates;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _candidates = potmShortlist(widget.match, widget.store);
    // Pre-select the previously saved award so edits show the current pick.
    if (widget.match.manOfMatchId.isNotEmpty &&
        _candidates.any((c) => c.playerId == widget.match.manOfMatchId)) {
      _selected = widget.match.manOfMatchId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PitchTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Select Player of the Match',
        style: TextStyle(
          color: PitchTheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.85).clamp(280.0, 480.0),
        child: _candidates.isEmpty
            ? const Text(
                'No eligible players with recorded figures in this match. '
                'You can still pick one manually from the playing XIs.',
                style: TextStyle(color: PitchTheme.outline),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Top performers by match impact — tap to select.',
                    style: TextStyle(
                      color: PitchTheme.outline,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _candidates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = _candidates[i];
                        final sel = _selected == c.playerId;
                        return InkWell(
                          onTap: () => setState(() => _selected = c.playerId),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? PitchTheme.secondary
                                    : PitchTheme.surfaceContainerLow,
                                width: sel ? 2 : 1,
                              ),
                              color: sel
                                  ? PitchTheme.secondaryContainer.withValues(alpha: 0.25)
                                  : PitchTheme.surfaceContainerLowest,
                            ),
                            child: Row(
                              children: [
                                PlayerAvatar(
                                  photoBase64: c.photoBase64.isEmpty
                                      ? null
                                      : c.photoBase64,
                                  role: c.role,
                                  name: c.name,
                                  radius: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (i == 0)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 4),
                                              child: Icon(
                                                Icons.emoji_events,
                                                size: 14,
                                                color: PitchTheme.secondary,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              c.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: PitchTheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        [
                                          if (c.teamName.isNotEmpty) c.teamName,
                                          c.role,
                                        ].join(' • '),
                                        style: const TextStyle(
                                          color: PitchTheme.outline,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.figureLine,
                                        style: const TextStyle(
                                          color: PitchTheme.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  const Icon(
                                    Icons.check_circle,
                                    color: PitchTheme.secondary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text(
            'Skip',
            style: TextStyle(color: PitchTheme.outline, fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PitchTheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
