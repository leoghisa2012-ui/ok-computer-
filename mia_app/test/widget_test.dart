import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mia_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home opens calendar and school pages', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('ok computer'), findsNWidgets(2));
    expect(find.text('Il mio calendario'), findsOneWidget);
    expect(find.text('School'), findsNWidgets(2));

    await tester.tap(find.text('Apri le tue materie scolastiche'));
    await tester.pumpAndSettle();

    for (final subject in [
      'Matematica',
      'Italiano',
      'Latino',
      'Geostoria',
      'Fisica',
      'Disegno',
      'Scienze',
      'Inglese',
      'Religione',
    ]) {
      await tester.scrollUntilVisible(find.text(subject), 200);
      expect(find.text(subject), findsOneWidget);
    }

    await tester.drag(find.byType(GridView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematica'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Matematica'), findsOneWidget);
    expect(find.text('Aggiungi file'), findsOneWidget);
  });

  testWidgets('adds a homework task and keeps it after reopening', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Visualizza e organizza i tuoi compiti'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggiungi compito'));
    await tester.pumpAndSettle();

    expect(find.text('Scegli la materia'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Matematica'), findsOneWidget);

    final subjectList = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        )
        .last;
    await tester.scrollUntilVisible(
      find.text('Religione'),
      200,
      scrollable: subjectList,
    );
    expect(find.text('Religione'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Matematica'),
      -200,
      scrollable: subjectList,
    );

    await tester.tap(find.text('Matematica'));
    await tester.pumpAndSettle();

    expect(find.text('Compito di Matematica'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ripassare storia');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Ripassare storia'), findsOneWidget);
    expect(find.text('Matematica'), findsOneWidget);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Ripassare storia'), findsOneWidget);
    expect(find.text('Matematica'), findsOneWidget);
  });
}
