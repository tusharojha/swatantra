import 'models.dart';

/// Layout preview used when the live Tiramisu feed is empty.
/// Copy matches the seed dispatches. Not on-chain.
/// The live `arkiv_query` path is always tried first; this list is dropped
/// automatically once entities exist.
class ProofEdition {
  static const banner =
      'Live from Arkiv';

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
        nid: _nids[_creators.entries
                .firstWhere((e) => e.value.toLowerCase() == s.creator.toLowerCase(),
                    orElse: () => const MapEntry('A', ''))
                .key] ??
            s.creator,
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
            'notes': 'Logged after the original post disappeared from the platform. Self-reported.',
          },
          attributes: {
            'type': Attr('str', 'takedown'),
            'platform': Attr('str', 'X'),
            'law_cited': Attr('str', 'IT Act s.79'),
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
  's9': '0x88273a41526360123456789abcdef0123456789abcdef0123456789abcdef69',
  's10': '0x99384b52637470123456789abcdef0123456789abcdef0123456789abcdef7a',
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
    'B',
    'New Delhi',
    'Delhi',
    'protest',
    'Crowd held at the ITO barricades after the network dropped',
    'Phones fell to 2G around 11:20. The yellow police barricades were already across the carriageway; the sit-in behind them had been there for days.\n\n'
        'Autorickshaws still ran on the open side. On the closed side, a tarpaulin line and a power-pylon. Nobody on this desk is named. The still is hashed on the phone; only the chain root is written.\n\n'
        'Shop shutters on the far pavement were down. A few people stood well back of the fence. Data did not come back while this desk was there.\n\n'
        'Platforms bury this as “unverified crowd footage”. The protected link is a query, not a tweet.',
    90,
    district: 'New Delhi',
    geoCell: '28.6,77.2',
  ),
  _Seed(
    's2',
    'B',
    'Pune',
    'Maharashtra',
    'civic',
    'Same underpass, from the shop-row — water at the lintel',
    'From the first-floor terrace the water was a sheet down the shop-row. Shutters stayed down. Wires hung in the brown water.\n\n'
        'This is the second independent capture of the Sinhagad Road underpass this morning, same 0.1° cell, a different nullifier. No pump had arrived on this side either.\n\n'
        'A parked two-wheeler was already gone under. The bus-stand roof was the only dry edge.\n\n'
        'Three desks in one window is the corroboration. None of them named.',
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
    'Water through the gate at the underpass mouth',
    'The compound gate was a weir. Water came through at chest height and turned in the road. No one was in the frame on purpose.\n\n'
        'A second desk, a second chain root, twelve minutes from the first still, still Pune district, still 18.5,73.9. The municipal tanker that residents said was “on the way” had not shown.\n\n'
        'Palm and mango over the wall. The span of the underpass itself was not visible from this mouth — only the outflow.\n\n'
        'Ground copy like this is the first thing that disappears from a feed. The hash stays on the device.',
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
    'Sinhagad Road underpass still chest-deep after the rain',
    'Autos turned back at the mouth. A motorcycle was already half under. Overnight rain had nowhere to go but the underpass.\n\n'
        'This is the third independent capture within twenty minutes — Pune district, same 0.1° cell, a third nullifier. The pump had not arrived. Hazard lights on a stalled four-wheeler sat under the span, out of this frame.\n\n'
        'Two-wheelers that tried the service road threw a wake and came back. Shopkeepers on the approach had put generators on crates.\n\n'
        'Corroborated by three desks. None of them named. Media stays off Arkiv; the chain root does not.',
    8,
    district: 'Pune',
    geoCell: '18.5,73.9',
  ),
  _Seed(
    's5',
    'A',
    'Mandi',
    'Himachal Pradesh',
    'civic',
    'Slide over the Mandi–Kullu highway after the overnight rain',
    'Red earth and root-mat over the tarmac. The hill had come down onto the carriageway sometime after 2am. One lane was a wall of soil.\n\n'
        'Trucks were already stacked on the shoulder a kilometre back. No faces in this still — the cut, the road edge, the moss on the remaining tree.\n\n'
        'A JCB was said to be coming from Pandoh. At 7:40 it had not. Local buses had turned around.\n\n'
        'Hill-road slides are taken down as “old video”. The capture is time-stamped and district-bound.',
    6 * 60,
    district: 'Mandi',
    geoCell: '31.7,76.9',
  ),
  _Seed(
    's6',
    'B',
    'Bengaluru',
    'Karnataka',
    'labour',
    'Delivery bikes parked out a dark kitchen in Marathahalli',
    'A row of two-wheelers, top-boxes still on, engines off. The kitchen behind them had gone dark around 9pm. No orders on the screen, riders said; they would not go on record.\n\n'
        'This desk stood on the far pavement. The still is the parked line, not a face. Insulated bags sat on a few of the racks.\n\n'
        'A strike call had gone out on the riders’ groups after another round of pay cuts. The platform app still showed “high demand”.\n\n'
        'Labour footage is the first thing labelled “misleading”. The chain root is the record.',
    14 * 60,
    district: 'Bengaluru Urban',
    geoCell: '13.0,77.6',
  ),
  _Seed(
    's7',
    'A',
    'Yavatmal',
    'Maharashtra',
    'environment',
    'Unseasonal rain on the soy in Yavatmal — pods wet, soil a sheet',
    'The standing soy was still green this morning. The soil between the rows was a film of water. Last night’s rain was not in the forecast the mandi had been using.\n\n'
        'No one is named. A blue tarp on the bund, a single tree, the field. Farmers on the next plot said the earlier sowing would lodge if the rain returned.\n\n'
        'Vidarbha has had this twice in three seasons: a dry spell, then a dump that the crop cannot use. The district agriculture office had not put a loss survey on the board by noon.\n\n'
        'Crop stills vanish as “not news”. District, cell, and time are on the chain.',
    20 * 60,
    district: 'Yavatmal',
    geoCell: '20.4,78.1',
  ),
  _Seed(
    's8',
    'C',
    'Guwahati',
    'Assam',
    'civic',
    'Dam release overnight — water over the fields at Palashbari',
    'From the air the Brahmaputra floodplain was a single sheet. Homesteads sat on the old levee like a spine. The release upstream had started after midnight.\n\n'
        'Boats were already on the approach at Palashbari. This still has no faces — water, trees, the road that is now a causeway.\n\n'
        'Relief camps from the last rise had not been folded. The district said the gates were opened because the reservoir had crossed the rule curve.\n\n'
        'Flood video is labelled “last year”. The capture is this morning, this cell.',
    28 * 60,
    district: 'Guwahati',
    geoCell: '26.1,91.7',
  ),
  _Seed(
    's9',
    'B',
    'Ghaziabad',
    'Uttar Pradesh',
    'environment',
    'Morning haze over the Ghaziabad flyover, AQI still maroon',
    'The sun was a white disc. From a terrace on the Ghaziabad side the NCR skyline was a set of blocks in brown air. Traffic on the flyover was a slow belt.\n\n'
        'Schools had already gone online for the day. Construction tarpaulin on a tower two kilometres off was not visible. Nobody on this desk is named.\n\n'
        'The public board at the metro still read “very poor”. Diesel gensets under the mall were running because the grid had dipped at dawn.\n\n'
        'Air stills are called “seasonal”. The stamp is district and a 0.1° cell, not a weather meme.',
    10 * 60,
    district: 'Ghaziabad',
    geoCell: '28.7,77.5',
  ),
  _Seed(
    's10',
    'C',
    'Hyderabad',
    'Telangana',
    'civic',
    'Open pit on Old Mumbai Road — lights out, the slab gone',
    'Where the streetlight used to stand there is a hole. Rebar, a plastic bag, the broken cover. Last night the stretch was dark for four poles.\n\n'
        'Two-wheelers were cutting around it. This still is the pit, not a face. Residents said they had called the ward office twice this week.\n\n'
        'Potholes on the same kilometre were full of yesterday’s rain. No barricade, no cone.\n\n'
        'Civic holes are “too local” until someone goes in. The chain is the date and the cell.',
    36 * 60,
    district: 'Hyderabad',
    geoCell: '17.4,78.5',
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
