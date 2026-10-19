import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swatantra/arkiv/anon.dart';
import 'package:swatantra/arkiv/hash.dart';
import 'package:swatantra/geo/districts.dart';
import 'package:swatantra/arkiv/write.dart';
import 'package:swatantra/auth.dart';
import 'package:swatantra/main.dart';
import 'package:swatantra/models.dart';
import 'package:swatantra/proof_edition.dart';
import 'package:swatantra/screens/journalist.dart';
import 'package:swatantra/screens/onboard.dart';
import 'package:swatantra/theme.dart';
import 'package:swatantra/widgets/bits.dart';
import 'package:swatantra/widgets/sheets.dart';

void main() {
  testWidgets('App loads with rangoli logo and brand palette', (tester) async {
    await tester.pumpWidget(const SwatantraApp());
    expect(find.text('Swatantra'), findsWidgets);
    expect(find.text('स्वतंत्र'), findsOneWidget);
    expect(find.text('Ground truth, unerasable.'), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/logo.png');

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.colorScheme.primary, Swa.magenta);
    expect(Swa.magenta, const Color(0xFFDC2460));
    expect(Swa.teal, const Color(0xFF089C9C));
    expect(Swa.saffron, const Color(0xFFF47C20));
  });

  test('capture chain is deterministic and district-bound', () {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final a = hashChain([(bytes: bytes, timestampMs: 1700000000000)], district: 'Pune', geoCell: '18.5,73.9');
    final b = hashChain([(bytes: bytes, timestampMs: 1700000000000)], district: 'Pune', geoCell: '18.5,73.9');
    expect(a.root, b.root);
    expect(a.frameCount, 1);
    expect(a.root.startsWith('0x'), isTrue);
    expect(a.root.length, 66);
    final other = hashChain([(bytes: bytes, timestampMs: 1700000000000)], district: 'Mumbai', geoCell: '19.1,72.9');
    expect(other.root, isNot(a.root));
    final two = hashChain([
      (bytes: bytes, timestampMs: 1700000000000),
      (bytes: bytes, timestampMs: 1700000001000),
    ], district: 'Pune', geoCell: '18.5,73.9');
    expect(two.frameCount, 2);
    expect(two.root, isNot(a.root));
  });

  test('Anon Aadhaar TEST MODE nullifier is stable', () {
    final a = testNullifier(bundledTestQr);
    final b = testNullifier('');
    expect(a, b);
    expect(a.startsWith('0x'), isTrue);
    expect(a.length, 66);
  });

  test('Devanagari dateline uses Noto-friendly digits', () {
    final d = DateTime.utc(2026, 10, 18);
    expect(editionDatelineHi(d), contains('अक्तूबर'));
    expect(editionDatelineHi(d), contains('२०२६'));
    expect(editionDateline(d), contains('OCTOBER'));
  });

  test('coarse district stamp never keeps a pin', () {
    expect(geoCellOf(18.5204, 73.8567), '18.5,73.9');
    final gps = stampFromLatLng(18.52, 73.86);
    expect(gps.district, 'Pune');
    expect(gps.selfDeclared, isFalse);
    expect(gps.geoCell, '18.5,73.9');
    final declared = stampDeclared('Pune');
    expect(declared.selfDeclared, isTrue);
    expect(declared.source, 'self-declared');
  });

  test('synthetic demo feed is labelled and switches off live keys', () {
    expect(ProofEdition.banner, isNotEmpty);
    expect(ProofEdition.stories, isNotEmpty);
    expect(ProofEdition.isProof(ProofEdition.stories.first.key), isTrue);
    expect(ProofEdition.takedowns.first.attr('platform'), 'X');
    expect(ProofEdition.captureByRoot(ProofEdition.stories.first.captureRoot), isNotNull);
    final pune = ProofEdition.stories.where((s) => s.district == 'Pune').toList();
    expect(pune.length, 3);
    expect(ProofEdition.stories.any((s) => s.title.contains('Sinhagad')), isTrue);
    expect(ProofEdition.stories.any((s) => s.title.toLowerCase().contains('synthetic')), isFalse);
    final c = ProofEdition.corroborationFor(pune.first);
    expect(c, isNotNull);
    expect(c!.ok, isTrue);
    expect(c.count, 3);
  });

  test('Ident32 is left-aligned UTF-8', () {
    final h = ident32Hex('app');
    expect(h.startsWith('0x617070'), isTrue);
    expect(h.length, 66);
  });

  test('formatGlm and sanitizeUi', () {
    expect(formatGlm('0'), '0 GLM');
    expect(formatGlm('1000000000000000'), '0.001 GLM');
    expect(sanitizeUi('Anon Aadhaar TEST MODE. Nullifier only.'), 'Anon Aadhaar. Nullifier only.');
    expect(sanitizeUi('bundled test identity'), 'saved identity');
    expect(sanitizeUi('GLM on testnet'), 'GLM on Tiramisu');
  });

  testWidgets('browse never asks for a wallet', (tester) async {
    await tester.pumpWidget(const SwatantraApp());
    await tester.pump();
    expect(find.textContaining('Needed to'), findsNothing);
    expect(find.text('Create wallet'), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('sign-in sheet appears for a gated action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: swatantraTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: ActionPill(
            icon: SwaI.tip,
            label: 'Tip',
            onTap: () => ensureSignedIn(context, action: 'tip this desk'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Tip'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Needed to tip this desk'), findsOneWidget);
    expect(find.text('Create wallet'), findsOneWidget);
    expect(find.text('Connect wallet'), findsOneWidget);
    expect(find.textContaining('TEST MODE'), findsNothing);
  });

  testWidgets('corroboration stamp is compact', (tester) async {
    final cluster = Corroboration(
      district: 'Pune',
      geoCell: '18.5,73.9',
      windowStart: 0,
      windowEnd: 1,
      witnesses: const [
        Witness(creator: '0xaaa', nid: '0x1111aaaa', captureTs: 1, chainRoot: '0x1', entityKey: '0xk1', district: 'Pune'),
        Witness(creator: '0xbbb', nid: '0x2222bbbb', captureTs: 2, chainRoot: '0x2', entityKey: '0xk2', district: 'Pune'),
        Witness(creator: '0xccc', nid: '0x3333cccc', captureTs: 3, chainRoot: '0x3', entityKey: '0xk3', district: 'Pune'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: swatantraTheme(),
      home: Scaffold(body: CorroborationStamp(cluster, expandable: true)),
    ));
    expect(find.text('Corroborated'), findsOneWidget);
    expect(find.text('3 witnesses'), findsOneWidget);
    expect(find.textContaining('INDEPENDENT WITNESSES'), findsNothing);
    await tester.tap(find.text('Corroborated'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pune'), findsWidgets);
  });

  testWidgets('onboarding card has a primary create action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: swatantraTheme(),
      home: const Scaffold(body: SingleChildScrollView(child: OnboardPanel())),
    ));
    expect(find.text('Create wallet'), findsOneWidget);
    expect(find.text('Connect wallet'), findsOneWidget);
    expect(find.textContaining('Stays on this device'), findsOneWidget);
    expect(find.textContaining('TEST MODE'), findsNothing);
  });

  testWidgets('journalist screen shows a proof stepper', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: swatantraTheme(),
      home: const Scaffold(body: JournalistScreen()),
    ));
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Generate proof'), findsOneWidget);
    expect(find.text('Verified seal'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Proving…'), findsNothing);
  });

  testWidgets('tip sheet has presets and confirm', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: swatantraTheme(),
      home: Scaffold(
        body: TipSheet(
          storyKey: '0xabc',
          to: '0x2e1733523b5704cf431378618cc5e74bb1248997',
          send: (amount) async => {'transferTx': '0xhash', 'entityKey': '0xent', 'amount': amount},
        ),
      ),
    ));
    expect(find.text('Support this desk'), findsOneWidget);
    expect(find.text('GLM 0.001'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    await tester.tap(find.text('Confirm tip'));
    await tester.pumpAndSettle();
    expect(find.text('Tip sent'), findsOneWidget);
    expect(find.text('On Arkiv'), findsOneWidget);
  });
}
