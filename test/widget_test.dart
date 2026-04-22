import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_match/main.dart';

void main() {
  testWidgets('App starts and shows Mahjong Match title', (WidgetTester tester) async {
    await tester.pumpWidget(const MahjongMatchApp());
    await tester.pumpAndSettle();
    expect(find.text('Mahjong'), findsOneWidget);
  });
}
