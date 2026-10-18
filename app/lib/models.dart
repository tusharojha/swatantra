class ArkivEntity {
  final String key;
  final String owner;
  final String creator;
  final String createdAt;
  final String expiresAt;
  final Map<String, dynamic> payload;
  final Map<String, Attr> attributes;

  ArkivEntity({
    required this.key,
    required this.owner,
    required this.creator,
    required this.createdAt,
    required this.expiresAt,
    required this.payload,
    required this.attributes,
  });

  String attr(String name, [String fallback = '']) {
    final v = attributes[name]?.value;
    if (v == null) return fallback;
    return '$v';
  }

  String get title => '${payload['title'] ?? ''}';
  String get body => '${payload['body'] ?? ''}';
  String get mediaUrl => '${payload['mediaUrl'] ?? ''}';
  String get city => attr('city');
  String get state => attr('state');
  String get category => attr('category');
  String get type => attr('type');
  int get createdAtMs => int.tryParse(attr('created_at_ms', '0')) ?? 0;
  String get captureKey => attr('capture_key');
  String get captureRoot => '${payload['captureRoot'] ?? ''}';
  bool get hasCapture => captureKey.isNotEmpty || captureRoot.isNotEmpty;
  String get district => attr('district');
  String get geoCell => attr('geo_cell');
  int get captureTsMs =>
      int.tryParse(attr('capture_ts_ms', attr('start_ms', '0'))) ?? createdAtMs;

  factory ArkivEntity.fromJson(Map<String, dynamic> j) {
    final attrs = <String, Attr>{};
    final raw = j['attributes'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          attrs['$k'] = Attr('${v['type']}', v['value']);
        }
      });
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          attrs['${item['name']}'] = Attr('${item['type']}', item['value']);
        }
      }
    }
    Map<String, dynamic> payload = {};
    final p = j['payload'];
    if (p is Map<String, dynamic>) {
      payload = p;
    } else if (p is Map) {
      payload = Map<String, dynamic>.from(p);
    }
    return ArkivEntity(
      key: '${j['key'] ?? ''}',
      owner: '${j['owner'] ?? ''}',
      creator: '${j['creator'] ?? ''}',
      createdAt: '${j['createdAt'] ?? ''}',
      expiresAt: '${j['expiresAt'] ?? ''}',
      payload: payload,
      attributes: attrs,
    );
  }
}

class Attr {
  final String type;
  final dynamic value;
  Attr(this.type, this.value);
}

class CaptureChain {
  final String root;
  final int frameCount;
  final int fps;
  final int startMs;
  final int endMs;
  final List<String> frameHashes;
  final String district;
  final String geoCell;
  CaptureChain({
    required this.root,
    required this.frameCount,
    required this.fps,
    required this.startMs,
    required this.endMs,
    required this.frameHashes,
    this.district = '',
    this.geoCell = '',
  });
}

class Witness {
  final String creator;
  final String nid;
  final int captureTs;
  final String chainRoot;
  final String entityKey;
  final String district;
  const Witness({
    required this.creator,
    required this.nid,
    required this.captureTs,
    required this.chainRoot,
    required this.entityKey,
    required this.district,
  });

  String get anonId {
    final id = nid.isNotEmpty ? nid : creator;
    if (id.length < 12) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
  }
}

class Corroboration {
  final String district;
  final String geoCell;
  final int windowStart;
  final int windowEnd;
  final List<Witness> witnesses;
  final bool synthetic;
  const Corroboration({
    required this.district,
    required this.geoCell,
    required this.windowStart,
    required this.windowEnd,
    required this.witnesses,
    this.synthetic = false,
  });

  Set<String> get distinctIds =>
      witnesses.map((w) => w.nid.isNotEmpty ? w.nid.toLowerCase() : w.creator.toLowerCase()).toSet();

  int get count => distinctIds.length;
  bool get ok => count >= 2;
}
