import 'package:flutter_test/flutter_test.dart';
import 'package:anime_friends/main.dart';

void main() {
  testWidgets('Feed opens by default and navigation works',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnimeFriendsApp());

    expect(find.text('Your feed is quiet'), findsOneWidget);

    await tester.tap(find.text('Anime').last);
    await tester.pumpAndSettle();

    expect(find.text('Anime catalogue'), findsOneWidget);
  });
}
