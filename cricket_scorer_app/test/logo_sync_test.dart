import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scorer_app/core/constants/preset_team_logos.dart';
import 'package:cricket_scorer_app/core/constants/preset_player_avatars.dart';
import 'package:cricket_scorer_app/models/models.dart';
import 'package:cricket_scorer_app/models/remote_match_summary.dart';

void main() {
  group('Team & Player Preset Catalogs', () {
    test('TeamPresetCatalog has 20 unique valid presets', () {
      expect(TeamPresetCatalog.presets.length, 20);
      final ids = TeamPresetCatalog.presets.map((e) => e.id).toSet();
      expect(ids.length, 20);
      for (final p in TeamPresetCatalog.presets) {
        expect(p.id.startsWith('preset:'), isTrue);
        expect(p.name.isNotEmpty, isTrue);
        expect(p.defaultCode.isNotEmpty, isTrue);
        expect(TeamPresetCatalog.findById(p.id), isNotNull);
      }
    });

    test('PlayerPresetCatalog has 10 unique valid presets', () {
      expect(PlayerPresetCatalog.presets.length, 10);
      final ids = PlayerPresetCatalog.presets.map((e) => e.id).toSet();
      expect(ids.length, 10);
    });
  });

  group('Logo & ShortCode Serialization', () {
    test('Team toJson/fromJson preserves logo and shortCode', () {
      final t = Team(
        id: 'team_1',
        name: 'Lahore Lions',
        logo: 'preset:lions',
        shortCode: 'LHR',
      );
      final json = t.toJson();
      expect(json['logo'], 'preset:lions');
      expect(json['shortCode'], 'LHR');

      final restored = Team.fromJson(json);
      expect(restored.logo, 'preset:lions');
      expect(restored.shortCode, 'LHR');
      expect(restored.displayCode, 'LHR');
    });

    test('Team fromJson is backward compatible when logo/shortCode omitted', () {
      final legacy = Team.fromJson({
        'id': 'team_legacy',
        'name': 'Karachi Kings',
        'players': [],
      });
      expect(legacy.logo, '');
      expect(legacy.shortCode, '');
      expect(legacy.displayCode, 'KK');
    });

    test('RemoteMatchSummary preserves team_a_logo, team_b_logo, team_a_code, team_b_code', () {
      final rm = RemoteMatchSummary.fromJson({
        'id': 'match_1',
        'team_a_id': 't_a',
        'team_b_id': 't_b',
        'team_a_name': 'aSD',
        'team_b_name': 'SDWA',
        'team_a_logo': 'preset:sharks',
        'team_b_logo': 'preset:dragons',
        'team_a_code': 'ASD',
        'team_b_code': 'SD',
      });
      expect(rm.teamALogo, 'preset:sharks');
      expect(rm.teamBLogo, 'preset:dragons');
      expect(rm.teamACode, 'ASD');
      expect(rm.teamBCode, 'SD');

      final back = rm.toJson();
      expect(back['team_a_logo'], 'preset:sharks');
      expect(back['team_b_logo'], 'preset:dragons');
      expect(back['team_a_code'], 'ASD');
      expect(back['team_b_code'], 'SD');
    });
  });
}
