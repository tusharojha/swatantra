import 'package:flutter_test/flutter_test.dart';
import 'package:swatantra/main.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const SwatantraApp());
    expect(find.text('Swatantra'), findsWidgets);
  });
}
