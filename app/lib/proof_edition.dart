import 'models.dart';

/// Labeled layout preview used when the live Tiramisu feed is empty.
/// Copy matches the synthetic seed dispatches. Not on-chain.
/// The live `arkiv_query` path is always tried first; this list is dropped
/// automatically once entities exist.
class ProofEdition {
  static const banner =
      'SYNTHETIC DEMO — live Arkiv query returned no entities. These cards are layout-only and disappear automatically once Tiramisu has stories.';

  static List<ArkivEntity> get stories {
    final list = _stories.map(_story).toList();
    list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  static ArkivEntity? entity(String key) {
    if (key.startsWith('proof-cap-')) {
      final storyKey = 'proof-${key.substring('proof-cap-'.length)}';
      return captureFor(storyKey);
    }
    for (final s in stories) {
      if (s.key == key) return s;
    }
    return null;
  }

  static ArkivEntity? captureFor(String storyKey) {
    final s = entity(storyKey);
    if (s == null || !s.hasCapture) return null;
    final id = storyKey.replaceFirst('proof-', '');
    return ArkivEntity(
      key: 'proof-cap-$id',
      owner: s.creator,
      creator: s.creator,
      createdAt: s.createdAt,
      expiresAt: s.expiresAt,
      payload: {
        'kind': 'capture',
        'note': 'Proof-edition hash for layout. Not an Arkiv entity.',
      },
      attributes: {
        'type': Attr('str', 'capture'),
        'chain_root': Attr('bytes32', s.captureRoot),
        'frame_count': Attr('uint', 1),
        'fps': Attr('uint', 1),
        'start_ms': Attr('uint', s.createdAtMs),
        'capture_ts_ms': Attr('uint', s.createdAtMs),
        'city': Attr('str', s.city),
        'district': Attr('str', s.district),
        'geo_cell': Attr('str', s.geoCell),
      },
    );
  }

  static bool isProof(String key) => key.startsWith('proof-');

  static const puneCell = '18.5,73.9';

  static Corroboration? corroborationFor(ArkivEntity story) {
    final cluster = stories.where((s) => s.district == 'Pune').toList();
    if (story.district != 'Pune' || cluster.length < 2) return null;
    final ts = story.captureTsMs;
    final window = 30 * 60 * 1000;
    final inWindow = cluster.where((s) => (s.captureTsMs - ts).abs() <= window).toList();
    if (inWindow.length < 2) return null;
    final witnesses = inWindow.map((s) {
      final cap = captureFor(s.key)!;
      return Witness(
        creator: s.creator,
        nid: _nids[_creators.entries.firstWhere((e) => e.value.toLowerCase() == s.creator.toLowerCase(), orElse: () => const MapEntry('A', '')).key] ?? s.creator,
        captureTs: s.captureTsMs,
        chainRoot: cap.attr('chain_root'),
        entityKey: cap.key,
        district: 'Pune',
      );
    }).toList();
    return Corroboration(
      district: 'Pune',
      geoCell: puneCell,
      windowStart: ts - window,
      windowEnd: ts + window,
      witnesses: witnesses,
      synthetic: true,
    );
  }

  static ArkivEntity? captureByRoot(String root) {
    final want = root.toLowerCase();
    for (final s in stories) {
      final cap = captureFor(s.key);
      if (cap != null && cap.attr('chain_root').toLowerCase() == want) return cap;
    }
    return null;
  }

  static List<ArkivEntity> get takedowns => [
        ArkivEntity(
          key: 'proof-td-1',
          owner: _creators['B']!,
          creator: _creators['B']!,
          createdAt: '${DateTime.now().millisecondsSinceEpoch - 8 * 3600 * 1000}',
          expiresAt: '0',
          payload: {
            'notes': 'Synthetic takedown log for the demo tracker. Not a real notice.',
            'synthetic': true,
            'disclaimer': 'Synthetic or self-reported. Not legal advice.',
          },
          attributes: {
            'type': Attr('str', 'takedown'),
            'platform': Attr('str', 'X'),
            'law_cited': Attr('str', 'IT Act s.79 (synthetic citation)'),
            'authority_named': Attr('str', 'false'),
            'notice_date_ms': Attr('uint', DateTime.utc(2026, 9, 15).millisecondsSinceEpoch),
            'created_at_ms': Attr('uint', DateTime.now().millisecondsSinceEpoch - 8 * 3600 * 1000),
          },
        ),
      ];
}

const _hashes = {
  's1': '0x7c1a9e2b4d6f80123456789abcdef0123456789abcdef0123456789abcdef01',
  's2': '0x11b0c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef2',
  's3': '0x22c1d4e5f607890123456789abcdef0123456789abcdef0123456789abcdef03',
  's4': '0x33d2e5f60718190123456789abcdef0123456789abcdef0123456789abcdef14',
  's5': '0x44e3f6071829020123456789abcdef0123456789abcdef0123456789abcdef25',
  's6': '0x55f40718293030123456789abcdef0123456789abcdef0123456789abcdef36',
  's7': '0x66051829304140123456789abcdef0123456789abcdef0123456789abcdef47',
  's8': '0x77162930415250123456789abcdef0123456789abcdef0123456789abcdef58',
};

const _creators = {
  'A': '0x2E1733523b5704Cf431378618Cc5E74bB1248997',
  'B': '0xf96c7F67F72301038Ec538E422e0d52e7Dd81cCF',
  'C': '0x68F0Ee5526e28e9072A9Fa398d91A5a867001645',
};

const _nids = {
  'A': '0x06ffb52d39bcf94137fd80cd418163a22c52ec478b54e83c66fccb3ee9b7361f',
  'B': '0x11aa0000000000000000000000000000000000000000000000000000000000b2',
  'C': '0x22bb0000000000000000000000000000000000000000000000000000000000c3',
};

class _Seed {
  final String id;
  final String journalist;
  final String city;
  final String state;
  final String category;
  final String title;
  final String body;
  final int minutesAgo;
  final String district;
  final String geoCell;
  const _Seed(
    this.id,
    this.journalist,
    this.city,
    this.state,
    this.category,
    this.title,
    this.body,
    this.minutesAgo, {
    this.district = '',
    this.geoCell = '',
  });
}

const _stories = <_Seed>[
  _Seed(
    's1',
    'A',
    'Mumbai',
    'Maharashtra',
    'civic',
    'King tide at a western suburb jetty, 12 Oct 2026 (synthetic)',
    'SYNTHETIC DISPATCH — none of the people named here are real.\n\n'
        'By 6:40am the water was already over the first step of the jetty. '
        'Shopkeepers on the approach road had moved generators onto crates. '
        'A municipal pump truck arrived, then left: the driver said the outfall was blocked with plastic.\n\n'
        'This is a fictional ground report written for the Swatantra demo. '
        'It stands in for the kind of civic footage that is routinely taken down as \'out of context\'.',
    180,
    district: 'Mumbai',
    geoCell: '19.1,72.9',
  ),
  _Seed(
    's2',
    'B',
    'Pune',
    'Maharashtra',
    'civic',
    'FC Road after a burst main, from the south kerb (synthetic)',
    'SYNTHETIC DISPATCH — fictional names, composite scene.\n\n'
        'Water over the tramlines of memory: a burst main, bikes pushed onto the divider. '
        'Three desks sampled the same Pune junction within twenty minutes — that is the corroboration.\n\n'
        'Not a report of a specific pipe. The point is independent witnesses on Arkiv.',
    15,
    district: 'Pune',
    geoCell: '18.5,73.9',
  ),
  _Seed(
    's3',
    'A',
    'Pune',
    'Maharashtra',
    'civic',
    'Same FC Road flood, west flyover (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'From the flyover the water made a sheet as far as the bus depot. '
        'A second capture, a second nullifier, the same district cell, twelve minutes from the first still.',
    22,
    district: 'Pune',
    geoCell: '18.5,73.9',
  ),
  _Seed(
    's4',
    'C',
    'Pune',
    'Maharashtra',
    'civic',
    'Third desk, same Pune junction, eight minutes on (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'A third journalist, a third chain root, still Pune district, still the same 0.1° cell. '
        'Corroborated by 3 independent witnesses — none of them named.',
    8,
    district: 'Pune',
    geoCell: '18.5,73.9',
  ),
  _Seed(
    's5',
    'A',
    'Ranchi',
    'Jharkhand',
    'labour',
    'Night shift at a coal siding off Hazaribagh road (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'Headlamps, a whistle, a wagon that did not move for forty minutes. '
        'No real worker is identified. The journalist entity is a test-mode Anon Aadhaar nullifier.',
    28 * 60,
    district: 'Ranchi',
    geoCell: '23.3,85.3',
  ),
  _Seed(
    's6',
    'C',
    'Imphal',
    'Manipur',
    'civic',
    'NH-2 convoy wait, none of the names are real (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'A line of trucks on the shoulder, engines off to save fuel. '
        'This is not a report of a specific day\'s blockade. It is a placeholder for ground copy that platforms bury.',
    36 * 60,
    district: 'Imphal West',
    geoCell: '24.8,93.9',
  ),
  _Seed(
    's7',
    'B',
    'Hyderabad',
    'Telangana',
    'labour',
    'Gig kitchen riders after a platform outage, Gachibowli (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'Riders sat on their bikes outside a dark cloud kitchen. '
        'The app status in this copy is invented. Tips on this story are Tiramisu test GLM only.',
    44 * 60,
    district: 'Hyderabad',
    geoCell: '17.4,78.5',
  ),
  _Seed(
    's8',
    'B',
    'Kolkata',
    'West Bengal',
    'civic',
    'Howrah approach waterlogging, municipal pump (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'Knee-deep water at a flyover mouth, one pump, two men in reflective vests. '
        'Fictional. The protected link should still resolve from Arkiv after a hypothetical takedown.',
    52 * 60,
    district: 'Howrah',
    geoCell: '22.6,88.3',
  ),
];

ArkivEntity _story(_Seed s) {
  final ms = DateTime.now().millisecondsSinceEpoch - s.minutesAgo * 60 * 1000;
  final creator = _creators[s.journalist]!;
  return ArkivEntity(
    key: 'proof-${s.id}',
    owner: creator,
    creator: creator,
    createdAt: '$ms',
    expiresAt: '0',
    payload: {
      'title': s.title,
      'body': s.body,
      'mediaUrl': 'asset:web/seed/${s.id}.jpg',
      'captureRoot': _hashes[s.id],
    },
    attributes: {
      'type': Attr('str', 'story'),
      'city': Attr('str', s.city),
      'state': Attr('str', s.state),
      'category': Attr('str', s.category),
      'created_at_ms': Attr('uint', ms),
      'capture_ts_ms': Attr('uint', ms),
      'district': Attr('str', s.district),
      'geo_cell': Attr('str', s.geoCell),
      'capture_key': Attr('key', 'proof-cap-${s.id}'),
    },
  );
}
