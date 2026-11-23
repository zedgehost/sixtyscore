// Per-account profile for 60Score (v1.3.1 batch, feature #3).
// Every signed-in or local account gets its own profile: a display name, the
// account contact (email or phone) and a UNIQUE user code. The code is
// derived deterministically from the uid, so it is stable on
// every device without any server round-trip or extra Firestore path —
// the profile itself lives inside the account's own scoped data and
// rides the normal backup sync (users/{uid}/backup/app_data).
import 'package:cricket_scorer_app/services/storage/store.dart';
export 'package:cricket_scorer_app/services/auth/user_code.dart';

/// The app owner's email. Pre-v1.3.1 (unscoped) on-device data may
/// only ever be claimed into THIS account — it is the owner's data;
/// any other account starts with its own empty workspace and the
/// legacy keys stay untouched so the owner can still claim later.
const String kOwnerEmail = 'xharitarar550@gmail.com';

/// Deterministic 6-character user code for [uid], e.g. "60S-K7QX2M".
/// Two FNV-1a passes over the uid give enough spread; the result is
/// rendered in uppercase base36. Same uid → same code, on any device,
/// forever.
String userCodeForUid(String uid) {
  int fnv(String s, int seed) {
    var h = seed;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  final h = fnv(uid, 0x811C9DC5) ^ (fnv(uid, 0x9E3779B9) << 1);
  const space = 2176782336; // 36^6
  var v = h % space;
  const digits = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final buf = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buf.write(digits[v % 36]);
    v ~/= 36;
  }
  return '60S-${buf.toString()}';
}

/// One account's profile, stored in that account's own data scope.
/// Fully architected for offline use now and future cloud auth integration.
class AccountProfile {
  final String uid;
  String displayName;

  /// Email address, or phone number for phone-OTP accounts.
  String contact;
  final String userCode;

  /// Player cricket attributes
  String role; // Batter / Bowler / All-Rounder / Wicket-Keeper
  String battingStyle; // e.g. Right-hand bat / Left-hand bat
  String bowlingStyle; // e.g. Right-arm fast-medium, Left-arm spin, None
  int jerseyNumber;
  String city;

  /// Audit timestamps and sync flag for future live auth / cloud backend
  String? createdAt;
  String? updatedAt;
  bool isSynced;
  bool isVerified;

  AccountProfile({
    required this.uid,
    required this.displayName,
    required this.contact,
    required this.userCode,
    this.role = 'All-Rounder',
    this.battingStyle = 'Right-hand bat',
    this.bowlingStyle = 'Right-arm fast-medium',
    this.jerseyNumber = 7,
    this.city = '',
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.isVerified = false,
  });

  bool get isUnverified => !isVerified;
  String get verificationStatusLabel =>
      isVerified ? 'Verified Player' : 'Unverified • Local Profile';

  factory AccountProfile.create({
    required String uid,
    String? displayName,
    String? contact,
    String? role,
    String? battingStyle,
    String? bowlingStyle,
    int? jerseyNumber,
    String? city,
    String? createdAt,
    String? updatedAt,
    bool? isVerified,
  }) {
    final effectiveContact = contact ?? '';
    final verified = isVerified ?? (effectiveContact.contains('@'));
    return AccountProfile(
      uid: uid,
      displayName: defaultProfileName(displayName, effectiveContact),
      contact: effectiveContact,
      userCode: userCodeForUid(uid),
      role: role ?? 'All-Rounder',
      battingStyle: battingStyle ?? 'Right-hand bat',
      bowlingStyle: bowlingStyle ?? 'Right-arm fast-medium',
      jerseyNumber: jerseyNumber ?? 7,
      city: city ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: false,
      isVerified: verified,
    );
  }

  /// Compact batting style representation (e.g. "RHB" or "LHB")
  String get battingStyleShort {
    final s = battingStyle.toLowerCase();
    if (s.contains('left')) return 'LHB';
    return 'RHB';
  }

  /// Compact bowling style representation (e.g. "RAFM", "ROB", "LAF", "SLA")
  String get bowlingStyleShort {
    final s = bowlingStyle.toLowerCase();
    if (s.contains('none') || s.isEmpty) return '-';
    final arm = s.contains('left') ? 'L' : 'R';
    if (s.contains('spin') || s.contains('off-break') || s.contains('break')) {
      return arm == 'L' ? 'SLA' : 'OB';
    }
    if (s.contains('fast-medium') || s.contains('medium-fast')) {
      return '${arm}AFM';
    }
    if (s.contains('fast')) return '${arm}AF';
    if (s.contains('medium')) return '${arm}AM';
    return '${arm}A';
  }

  /// Formatted player summary subtitle, e.g. "All-Rounder (RHB • RAFM)"
  String get roleSummary {
    final bShort = battingStyleShort;
    final bowlShort = bowlingStyleShort;
    if (bowlShort == '-') {
      return '$role ($bShort)';
    }
    return '$role ($bShort • $bowlShort)';
  }

  /// Name fallback chain: the auth display name, else the email
  /// prefix, else a neutral 'Player'.
  static String defaultProfileName(String? displayName, String? contact) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    if (contact != null && contact.contains('@')) {
      final prefix = contact.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'Player';
  }

  AccountProfile copyWith({
    String? displayName,
    String? contact,
    String? role,
    String? battingStyle,
    String? bowlingStyle,
    int? jerseyNumber,
    String? city,
    bool? isSynced,
    bool? isVerified,
  }) {
    return AccountProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      contact: contact ?? this.contact,
      userCode: userCode,
      role: role ?? this.role,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      city: city ?? this.city,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      isSynced: isSynced ?? this.isSynced,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'contact': contact,
        'userCode': userCode,
        'role': role,
        'battingStyle': battingStyle,
        'bowlingStyle': bowlingStyle,
        'jerseyNumber': jerseyNumber,
        'city': city,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isSynced': isSynced,
        'isVerified': isVerified,
      };

  factory AccountProfile.fromJson(Map<String, dynamic> j) => AccountProfile(
        uid: j['uid'] as String? ?? '',
        displayName: j['displayName'] as String? ?? 'Player',
        contact: j['contact'] as String? ?? '',
        userCode: j['userCode'] as String? ?? '',
        role: j['role'] as String? ?? 'All-Rounder',
        battingStyle: j['battingStyle'] as String? ?? 'Right-hand bat',
        bowlingStyle: j['bowlingStyle'] as String? ?? 'Right-arm fast-medium',
        jerseyNumber: (j['jerseyNumber'] as num?)?.toInt() ?? 7,
        city: j['city'] as String? ?? '',
        createdAt: j['createdAt'] as String?,
        updatedAt: j['updatedAt'] as String?,
        isSynced: j['isSynced'] as bool? ?? false,
        isVerified: j['isVerified'] as bool? ?? (j['contact'] != null && (j['contact'] as String).contains('@')),
      );
}

/// "My Stats" totals for the profile screen — computed ONLY from the
/// currently active identity's own store data. Runs/wickets come from
/// the shared career engine (completed matches), never re-implemented.
class AccountTotals {
  final int tournaments;
  final int matches;
  final int teams;
  final int players;
  final int totalRuns;
  final int totalWickets;

  const AccountTotals({
    required this.tournaments,
    required this.matches,
    required this.teams,
    required this.players,
    required this.totalRuns,
    required this.totalWickets,
  });

  static AccountTotals fromStore(Store store) {
    final playerIds = <String>{
      for (final t in store.teams)
        for (final p in t.players) p.id,
      for (final r in store.regPlayers) r.id,
    };
    var runs = 0;
    var wickets = 0;
    for (final c in store.getOrComputeCareerStats().values) {
      runs += c.runs;
      wickets += c.wickets;
    }
    return AccountTotals(
      tournaments: store.tournaments.length,
      matches: store.matches.length,
      teams: store.teams.length,
      players: playerIds.length,
      totalRuns: runs,
      totalWickets: wickets,
    );
  }
}
