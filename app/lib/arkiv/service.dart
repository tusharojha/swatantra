import '../models.dart';
import '../wallet.dart';
import 'js.dart';
import 'rpc.dart';
import 'write.dart' as w;

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

  /// Captures in the same district within ±30 minutes; distinct journalist nids.
  static Future<Corroboration?> corroborationFor({
    required String district,
    required int captureTsMs,
    String geoCell = '',
  }) async {
    if (district.isEmpty || captureTsMs == 0) return null;
    const window = 30 * 60 * 1000;
    final from = captureTsMs - window;
    final to = captureTsMs + window;
    List<ArkivEntity> caps = [];
    if (arkivJsAvailable) {
      try {
        final r = await arkivJs('queryCapturesInWindow', {
          'district': district,
          'tsMs': captureTsMs,
        });
        caps = (r['entities'] as List? ?? [])
            .map((e) => ArkivEntity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    if (caps.isEmpty) {
      final expr =
          "app = str('swatantra') AND type = str('capture') AND district = str('$district') "
          'AND capture_ts_ms >= u64($from) AND capture_ts_ms <= u64($to)';
      try {
        caps = (await rpc.query(expr, limit: 100)).entities;
      } catch (_) {
        return null;
      }
    }
    if (caps.isEmpty) return null;
    final journalists = await ofType('journalist');
    final nidByCreator = <String, String>{};
    for (final j in journalists) {
      nidByCreator[j.creator.toLowerCase()] = j.attr('nid');
    }
    final seen = <String>{};
    final witnesses = <Witness>[];
    for (final c in caps) {
      final nid = nidByCreator[c.creator.toLowerCase()] ?? '';
      final id = nid.isNotEmpty ? nid.toLowerCase() : c.creator.toLowerCase();
      if (seen.contains(id)) continue;
      seen.add(id);
      witnesses.add(Witness(
        creator: c.creator,
        nid: nid,
        captureTs: c.captureTsMs,
        chainRoot: c.attr('chain_root'),
        entityKey: c.key,
        district: c.district.isNotEmpty ? c.district : district,
      ));
    }
    return Corroboration(
      district: district,
      geoCell: geoCell,
      windowStart: from,
      windowEnd: to,
      witnesses: witnesses,
    );
  }

  static Future<Map<String, dynamic>> callWrite(String method, Map<String, dynamic> args) async {
    if (arkivJsAvailable) {
      return arkivJs(method, args);
    }
    if (WalletStore.privateKey == null) {
      throw StateError('Create a burner in Me first.');
    }
    switch (method) {
      case 'createStory':
        return w.createStoryDart(
          title: '${args['title'] ?? ''}',
          body: '${args['body'] ?? ''}',
          city: '${args['city'] ?? ''}',
          state: '${args['state'] ?? ''}',
          category: '${args['category'] ?? ''}',
          mediaUrl: '${args['mediaUrl'] ?? ''}',
          mediaHash: '${args['mediaHash'] ?? ''}',
          captureRoot: '${args['captureRoot'] ?? ''}',
          captureKey: args['captureKey'] as String?,
          journalistKey: args['journalistKey'] as String?,
          district: '${args['district'] ?? ''}',
          geoCell: '${args['geoCell'] ?? args['geo_cell'] ?? ''}',
          captureTsMs: args['captureTsMs'] as int? ?? args['startMs'] as int?,
        );
      case 'createCapture':
        return w.createCaptureDart(
          root: '${args['root']}',
          frameCount: args['frameCount'] as int,
          fps: args['fps'] as int? ?? 1,
          startMs: args['startMs'] as int,
          endMs: args['endMs'] as int,
          city: '${args['city'] ?? ''}',
          mediaUrl: '${args['mediaUrl'] ?? ''}',
          storyKey: args['storyKey'] as String?,
          district: '${args['district'] ?? ''}',
          geoCell: '${args['geoCell'] ?? args['geo_cell'] ?? ''}',
        );
      case 'createJournalist':
        return w.createJournalistDart(
          nullifier: '${args['nullifier']}',
          state: args['state'] as String?,
          displayName: '${args['displayName'] ?? ''}',
          bio: '${args['bio'] ?? ''}',
          groth16: args['groth16'] == true,
          ageAbove18: args['ageAbove18'] != false,
          stateRevealed: args['stateRevealed'] == true,
          proofHash: args['proofHash'] as String?,
        );
      case 'createTip':
        return w.createTipDart(
          storyKey: '${args['storyKey']}',
          to: '${args['to']}',
          amountEth: '${args['amountEth']}',
          note: '${args['note'] ?? ''}',
        );
      case 'createCorroboration':
        return w.createCorroborationDart(
          district: '${args['district'] ?? ''}',
          windowStartMs: args['windowStartMs'] as int? ?? 0,
          windowEndMs: args['windowEndMs'] as int? ?? 0,
          witnessCount: args['witnessCount'] as int? ?? 0,
          geoCell: '${args['geoCell'] ?? args['geo_cell'] ?? ''}',
          storyKey: args['storyKey'] as String?,
        );
      case 'createTakedown':
        return w.createTakedownDart(
          platform: '${args['platform'] ?? 'other'}',
          dateMs: args['dateMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          lawCited: '${args['lawCited'] ?? ''}',
          authorityNamed: args['authorityNamed'] == true,
          storyKey: args['storyKey'] as String?,
          notes: '${args['notes'] ?? ''}',
        );
      case 'extendStory':
        return w.extendStoryDart('${args['entityKey']}');
      case 'publishStoryWithCapture':
        final capArgs = Map<String, dynamic>.from(args['capture'] as Map);
        final cap = await w.createCaptureDart(
          root: '${capArgs['root']}',
          frameCount: capArgs['frameCount'] as int,
          fps: capArgs['fps'] as int? ?? 1,
          startMs: capArgs['startMs'] as int,
          endMs: capArgs['endMs'] as int,
          city: '${args['city'] ?? ''}',
          mediaUrl: '${args['mediaUrl'] ?? ''}',
          district: '${args['district'] ?? ''}',
          geoCell: '${args['geoCell'] ?? args['geo_cell'] ?? ''}',
        );
        final story = await w.createStoryDart(
          title: '${args['title'] ?? ''}',
          body: '${args['body'] ?? ''}',
          city: '${args['city'] ?? ''}',
          state: '${args['state'] ?? ''}',
          category: '${args['category'] ?? ''}',
          mediaUrl: '${args['mediaUrl'] ?? ''}',
          mediaHash: '${args['mediaHash'] ?? ''}',
          captureRoot: '${capArgs['root']}',
          captureKey: cap['entityKey'],
          journalistKey: args['journalistKey'] as String?,
          district: '${args['district'] ?? ''}',
          geoCell: '${args['geoCell'] ?? args['geo_cell'] ?? ''}',
          captureTsMs: capArgs['startMs'] as int?,
        );
        return {
          'storyKey': story['entityKey'],
          'captureKey': cap['entityKey'],
          'txHash': story['txHash'],
        };
      default:
        throw UnsupportedError('Write $method needs the JS bridge or a funded burner.');
    }
  }
}
