// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:manga_offline/app/app.dart';

void main() {
  testWidgets('Displays library placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const MangaOfflineApp());

    expect(
      find.text('¡Bienvenido! Aquí aparecerán tus mangas descargados.'),
      findsOneWidget,
    );
  });
}
