import '../models.dart';
import 'js.dart';
import 'rpc.dart';

class Arkiv {
  static final rpc = ArkivRpc();

  static Future<List<ArkivEntity>> feed({
    String? state,
    String? city,
    String? category,
    String? createdBy,
  }) async {
    if (arkivJsAvailable) {
      try {
        final r = await arkivJs('queryStories', {
          if (state != null) 'state': state,
          if (city != null) 'city': city,
          if (category != null) 'category': category,
          if (createdBy != null) 'createdBy': createdBy,
        });
        final list = (r['entities'] as List? ?? [])
            .map((e) => ArkivEntity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    final page = await rpc.stories(state: state, city: city, category: category, createdBy: createdBy);
    return page.entities;
  }

  static Future<ArkivEntity?> entity(String key) async {
    if (arkivJsAvailable) {
      try {
        final r = await arkivJs('getEntity', {'entityKey': key});
        return ArkivEntity.fromJson(r);
      } catch (_) {}
    }
    return rpc.getEntity(key);
  }

  static Future<List<ArkivEntity>> ofType(String type, {Map<String, String>? eq}) async {
    if (arkivJsAvailable) {
      try {
        final extra = <Map<String, dynamic>>[];
        eq?.forEach((k, v) {
          extra.add({'op': 'eq', 'name': k, 'kind': k == 'story_key' ? 'key' : (k == 'nid' || k == 'chain_root' ? 'bytes32' : 'str'), 'value': v});
        });
        final r = await arkivJs('queryEntities', {'type': type, 'extra': extra, 'limit': 100});
        return (r['entities'] as List? ?? [])
            .map((e) => ArkivEntity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    final parts = ["app = str('swatantra')", "type = str('$type')"];
    eq?.forEach((k, v) {
      if (k == 'story_key') {
        parts.add("story_key = key($v)");
      } else if (k == 'nid' || k == 'chain_root') {
        parts.add("$k = bytes32($v)");
      } else {
        parts.add("$k = str('$v')");
      }
    });
    final page = await rpc.query(parts.join(' AND '), limit: 100);
    page.entities.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return page.entities;
  }
}
