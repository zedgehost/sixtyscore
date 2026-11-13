// Deterministic user code generator for 60Score.
// Generates stable 6-character uppercase base36 user codes e.g. "60S-K7QX2M".
// Pure Dart with zero external dependencies so it can be used across models,
// domain engines, and auth services.

/// Deterministic 6-character user code for [uid], e.g. "60S-K7QX2M".
/// Two FNV-1a passes over the uid give enough spread; the result is
/// rendered in uppercase base36. Same uid -> same code, on any device, forever.
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

/// Deterministic 6-character team code for [teamId], e.g. "TM-K7QX2M".
/// Matches the same FNV-1a hash spread so any team gets a stable permanent
/// shareable identifier that can be used for searching and profile sharing.
String teamCodeForId(String teamId) {
  int fnv(String s, int seed) {
    var h = seed;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  final h = fnv(teamId, 0x811C9DC5) ^ (fnv(teamId, 0x9E3779B9) << 1);
  const space = 2176782336; // 36^6
  var v = h % space;
  const digits = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final buf = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buf.write(digits[v % 36]);
    v ~/= 36;
  }
  return 'TM-${buf.toString()}';
}
