import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swatantra/arkiv/anon.dart';
import 'package:swatantra/arkiv/hash.dart';
import 'package:swatantra/arkiv/write.dart';
import 'package:swatantra/main.dart';
import 'package:swatantra/theme.dart';

void main() {
  testWidgets('App loads with rangoli logo and brand palette', (tester) async {
    await tester.pumpWidget(const SwatantraApp());
    expect(find.text('Swatantra'), findsWidgets);
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

  test('capture chain is deterministic', () {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final a = hashChain([(bytes: bytes, timestampMs: 1700000000000)]);
    final b = hashChain([(bytes: bytes, timestampMs: 1700000000000)]);
    expect(a.root, b.root);
    expect(a.frameCount, 1);
    expect(a.root.startsWith('0x'), isTrue);
    expect(a.root.length, 66);
    final two = hashChain([
      (bytes: bytes, timestampMs: 1700000000000),
      (bytes: bytes, timestampMs: 1700000001000),
    ]);
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

  test('Ident32 is left-aligned UTF-8', () {
    final h = ident32Hex('app');
    expect(h.startsWith('0x617070'), isTrue);
    expect(h.length, 66);
  });
}
