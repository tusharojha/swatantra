import 'models.dart';

/// Labeled layout preview used when the live Tiramisu feed is empty.
/// Copy matches the synthetic seed dispatches. Not on-chain.
/// The live `arkiv_query` path is always tried first; this list is dropped
/// automatically once entities exist.
class ProofEdition {
  static const banner =
      'SYNTHETIC DEMO — live Arkiv query returned no entities. These cards are layout-only and disappear automatically once Tiramisu has stories.';

  static List<ArkivEntity> get stories => _stories.map(_story).toList();

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
        'city': Attr('str', s.city),
      },
    );
  }

  static bool isProof(String key) => key.startsWith('proof-');

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

class _Seed {
  final String id;
  final String journalist;
  final String city;
  final String state;
  final String category;
  final String title;
  final String body;
  final int hoursAgo;
  const _Seed(this.id, this.journalist, this.city, this.state, this.category, this.title, this.body, this.hoursAgo);
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
    3,
  ),
  _Seed(
    's2',
    'B',
    'Delhi',
    'Delhi',
    'protest',
    'Phones on SOS after 9pm near ITO, 10 Oct 2026 (synthetic)',
    'SYNTHETIC DISPATCH — fictional names, composite scene.\n\n'
        'Around 21:10, four of five handsets in a small press huddle showed SOS-only. '
        'A printed order was not produced. A traffic constable shrugged and pointed at the sky.\n\n'
        'This story exists so a reader can still open a protected Arkiv link if a platform later removes a similar post.',
    8,
  ),
  _Seed(
    's3',
    'A',
    'Chennai',
    'Tamil Nadu',
    'environment',
    'Ennore creek after overnight rain — sludge line (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'A grey line of sludge sat on the mangrove edge at first light. '
        'Fisherfolk (composite, unnamed) said the smell was diesel and tannery, not tide.\n\n'
        'Capture proof is a SHA-256 chain of the demo still, not a claim about a real creek that morning.',
    14,
  ),
  _Seed(
    's4',
    'C',
    'Guwahati',
    'Assam',
    'environment',
    'Sandbags on a Brahmaputra ghat, October 2026 (synthetic)',
    'SYNTHETIC DISPATCH.\n\n'
        'Sandbags two-high along a ghat that is usually a tea stall. '
        'The stall owner in this copy is fictional. The point is the hash: the still can be checked against Arkiv.',
    20,
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
    28,
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
    36,
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
    44,
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
    52,
  ),
];

ArkivEntity _story(_Seed s) {
  final ms = DateTime.now().millisecondsSinceEpoch - s.hoursAgo * 3600 * 1000;
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
      'capture_key': Attr('key', 'proof-cap-${s.id}'),
    },
  );
}
