import 'package:app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase 0 scaffold renders an empty Fluent window', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FluentMusicApp()));

    expect(find.text('Fluent Music — Phase 0 scaffold'), findsOneWidget);
  });
}
