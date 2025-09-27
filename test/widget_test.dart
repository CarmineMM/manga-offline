// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/app/app.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/presentation/widgets/empty_state.dart';

void main() {
  setUp(() async {
    await configureDependencies();
  });

  testWidgets('Displays library empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const MangaOfflineApp());

    final emptyFinder = find.byType(EmptyState);
    var attempts = 0;
    while (attempts < 10 && emptyFinder.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 50));
      attempts++;
    }

    expect(
      emptyFinder,
      findsOneWidget,
      reason: 'Library should render an empty state once data loads',
    );
    final emptyWidget = tester.widget<EmptyState>(emptyFinder);
    expect(emptyWidget.message, contains('Aún no tienes mangas descargados'));
    expect(find.text('Biblioteca'), findsWidgets);
  });
}
