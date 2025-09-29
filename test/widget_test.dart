// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/app/app.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/presentation/widgets/empty_state.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('Allows navigating to downloads tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MangaOfflineApp());

    await tester.tap(find.text('Descargas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Descargas'), findsWidgets);
    expect(find.text('Tu biblioteca offline'), findsNothing);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final tempDir = await Directory.systemTemp.createTemp('manga_offline_test');
    return tempDir.path;
  }
}
