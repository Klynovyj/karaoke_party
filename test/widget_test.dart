import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_party/app.dart';

void main() {
  testWidgets('Startscreen rendert', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KaraokePartyApp()));
    await tester.pump();

    expect(find.text('Karaoke Party'), findsWidgets);
    expect(find.text('Spieler verwalten'), findsOneWidget);
  });
}
