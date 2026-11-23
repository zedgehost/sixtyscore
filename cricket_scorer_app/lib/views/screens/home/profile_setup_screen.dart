// 60Score / STUMPS - First-Time After-Login Cricket Profile Setup (Onboarding)
// Shown automatically after a user's first Google Sign-In so they can confirm
// their display name, cricket role, batting/bowling styles, jersey number, and city.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/services/auth/auth_service.dart';
import 'package:cricket_scorer_app/services/storage/store.dart';

class ProfileSetupScreen extends StatefulWidget {
  final Store? store;
  final bool gateMode;
  final VoidCallback? onCompleted;

  const ProfileSetupScreen({
    super.key,
    this.store,
    this.gateMode = true,
    this.onCompleted,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _jerseyCtrl;

  String _role = 'All-Rounder';
  String _battingStyle = 'Right-hand bat';
  String _bowlingStyle = 'Right-arm fast-medium';

  bool _saving = false;
  String? _error;

  static const List<Map<String, dynamic>> _roles = [
    {'label': 'All-Rounder', 'icon': Icons.sports_cricket},
    {'label': 'Batter', 'icon': Icons.sports_baseball},
    {'label': 'Bowler', 'icon': Icons.speed},
    {'label': 'Wicket-Keeper', 'icon': Icons.sports_handball},
    {'label': 'Scorer', 'icon': Icons.edit_note},
  ];

  static const List<String> _battingStyles = [
    'Right-hand bat',
    'Left-hand bat',
  ];

  static const List<String> _bowlingStyles = [
    'Right-arm fast-medium',
    'Right-arm spin',
    'Left-arm fast',
    'Left-arm spin',
    'None',
  ];

  @override
  void initState() {
    super.initState();
    final u = _auth.cpanelUser;
    _nameCtrl = TextEditingController(
      text: (u != null && u.displayName.isNotEmpty) ? u.displayName : '',
    );
    _cityCtrl = TextEditingController(text: u?.city ?? '');
    _jerseyCtrl = TextEditingController(text: '${u?.jerseyNumber ?? 7}');
    if (u != null && u.cricketRole.isNotEmpty) _role = u.cricketRole;
    if (u != null && u.battingStyle.isNotEmpty) _battingStyle = u.battingStyle;
    if (u != null && u.bowlingStyle.isNotEmpty) _bowlingStyle = u.bowlingStyle;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _jerseyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final jersey = int.tryParse(_jerseyCtrl.text.trim()) ?? 7;

    final result = await _auth.completeOnboarding(
      name: name,
      cricketRole: _role,
      battingStyle: _battingStyle,
      bowlingStyle: _bowlingStyle,
      jerseyNumber: jersey.clamp(0, 999),
      city: city,
    );

    if (!mounted) return;

    if (result.status != AuthStatus.ok) {
      setState(() {
        _saving = false;
        _error = result.message ?? 'Could not save profile setup.';
      });
      return;
    }

    // Sync active Store profile immediately
    final store = widget.store;
    if (store != null) {
      final u = _auth.cpanelUser;
      await store.ensureProfile(
        displayName: name,
        contact: u?.email ?? _auth.currentEmail,
        role: _role,
        battingStyle: _battingStyle,
        bowlingStyle: _bowlingStyle,
        jerseyNumber: jersey.clamp(0, 999),
        city: city,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else if (!widget.gateMode && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _auth.cpanelUser;
    final userCode = u?.userCode ?? widget.store?.effectiveUserCode ?? '';

    return Scaffold(
      backgroundColor: PitchTheme.surface,
      appBar: AppBar(
        backgroundColor: PitchTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.gateMode,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: PitchTheme.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: PitchTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: PitchTheme.primaryContainer,
                        backgroundImage:
                            (u?.avatarUrl != null && u!.avatarUrl!.isNotEmpty)
                                ? NetworkImage(u.avatarUrl!)
                                : null,
                        child: (u?.avatarUrl == null || u!.avatarUrl!.isEmpty)
                            ? const Icon(Icons.sports_cricket,
                                color: PitchTheme.tertiaryFixed, size: 26)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WELCOME TO 60SCORE',
                              style: TextStyle(
                                color: PitchTheme.tertiaryFixed,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              u?.email ?? 'Google Account Connected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userCode.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: PitchTheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ID: $userCode',
                                  style: const TextStyle(
                                    color: PitchTheme.onSecondaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PitchTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: PitchTheme.error.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: PitchTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),

                // Main Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: PitchTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color:
                            PitchTheme.outlineVariant.withValues(alpha: 0.5)),
                    boxShadow: PitchTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Player Identity',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tell teammates your cricket role so scorecards and squads match your real style.',
                        style: TextStyle(
                          color: PitchTheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDec(
                          label: 'Full Name / Scorecard Name *',
                          hint: 'e.g. Muhammad Aliyan',
                          icon: Icons.person_outline,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 2) {
                            return 'Enter at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Playing Role
                      const Text(
                        'Cricket Role *',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _roles.map((item) {
                          final label = item['label'] as String;
                          final icon = item['icon'] as IconData;
                          final selected = _role == label;
                          return ChoiceChip(
                            avatar: Icon(
                              icon,
                              size: 16,
                              color: selected
                                  ? PitchTheme.tertiaryFixed
                                  : PitchTheme.primary,
                            ),
                            label: Text(label),
                            selected: selected,
                            selectedColor: PitchTheme.primary,
                            backgroundColor: PitchTheme.surfaceContainerLow,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : PitchTheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                            onSelected: (_) => setState(() => _role = label),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Batting Style
                      const Text(
                        'Batting Style',
                        style: TextStyle(
                          color: PitchTheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _battingStyles.map((style) {
                          final selected = _battingStyle == style;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: style == _battingStyles.first ? 8 : 0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    setState(() => _battingStyle = style),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? PitchTheme.secondaryContainer
                                        : PitchTheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? PitchTheme.secondary
                                          : PitchTheme.outlineVariant
                                              .withValues(alpha: 0.5),
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    style,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? PitchTheme.onSecondaryContainer
                                          : PitchTheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Bowling Style
                      DropdownButtonFormField<String>(
                        initialValue: _bowlingStyles.contains(_bowlingStyle)
                            ? _bowlingStyle
                            : _bowlingStyles.first,
                        isExpanded: true,
                        decoration: _inputDec(
                          label: 'Bowling Style',
                          hint: 'Select bowling arm & pace',
                          icon: Icons.sports_cricket_outlined,
                        ),
                        items: _bowlingStyles
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _bowlingStyle = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // City & Jersey No Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cityCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDec(
                                label: 'City (Optional)',
                                hint: 'e.g. Lahore',
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _jerseyCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: _inputDec(
                                label: 'Jersey #',
                                hint: '7',
                                icon: Icons.tag,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PitchTheme.primary,
                      foregroundColor: PitchTheme.tertiaryFixed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: PitchTheme.tertiaryFixed,
                                strokeWidth: 2.2),
                          )
                        : const Text(
                            'Save Profile & Continue',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: PitchTheme.secondary, size: 20),
      filled: true,
      fillColor: PitchTheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: PitchTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PitchTheme.secondary, width: 1.5),
      ),
    );
  }
}
