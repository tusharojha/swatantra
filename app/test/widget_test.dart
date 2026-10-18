import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
