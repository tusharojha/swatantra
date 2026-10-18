import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swatantra/arkiv/anon.dart';
import 'package:swatantra/arkiv/hash.dart';
import 'package:swatantra/geo/districts.dart';
import 'package:swatantra/arkiv/write.dart';
import 'package:swatantra/main.dart';
import 'package:swatantra/proof_edition.dart';
import 'package:swatantra/theme.dart';
import 'package:swatantra/widgets/bits.dart';

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
    expect(ProofEdition.banner, contains('SYNTHETIC DEMO'));
    expect(ProofEdition.stories, isNotEmpty);
    expect(ProofEdition.isProof(ProofEdition.stories.first.key), isTrue);
    expect(ProofEdition.takedowns.first.attr('platform'), 'X');
    expect(ProofEdition.captureByRoot(ProofEdition.stories.first.captureRoot), isNotNull);
    final pune = ProofEdition.stories.where((s) => s.district == 'Pune').toList();
    expect(pune.length, 3);
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
}
