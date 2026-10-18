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
  CaptureChain({
    required this.root,
    required this.frameCount,
    required this.fps,
    required this.startMs,
    required this.endMs,
    required this.frameHashes,
  });
}
