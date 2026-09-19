import 'package:app/core/design/theme.dart';
import 'package:app/widgets/cagnotte_card.dart';
import 'package:app/widgets/states.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark
        ? MoelanTheme.dark()
        : MoelanTheme.light(),
    home: Scaffold(body: child),
  );
}

DioException _dioError(int status, {Object? body}) {
  final options = RequestOptions(path: '/api/players');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  testWidgets('EmptyState carries the next step, not just the absence', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        EmptyState(
          icon: Icons.groups_outlined,
          title: 'Aucun joueur',
          message: "Ajoutez les membres de l'équipe.",
          action: FilledButton(
            onPressed: () => tapped = true,
            child: const Text('Ajouter un joueur'),
          ),
        ),
      ),
    );

    expect(find.text('Aucun joueur'), findsOneWidget);
    await tester.tap(find.text('Ajouter un joueur'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorView shows French, never the exception', (tester) async {
    await tester.pumpWidget(_wrap(ErrorView(error: _dioError(500))));
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('serveur'), findsOneWidget);
  });

  testWidgets('offers a retry only when retrying could help', (tester) async {
    await tester.pumpWidget(
      _wrap(ErrorView(error: _dioError(500), onRetry: () {})),
    );
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(ErrorView(error: _dioError(403), onRetry: () {})),
    );
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('CagnotteCard states the distance left, not just a percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CagnotteCard(totalCents: 124700, targetCents: 200000)),
    );
    expect(find.textContaining('62 %'), findsOneWidget);
    expect(find.textContaining('753,00'), findsOneWidget);
  });

  testWidgets('CagnotteCard celebrates instead of showing a negative gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CagnotteCard(totalCents: 250000, targetCents: 200000)),
    );
    expect(find.textContaining('Objectif atteint'), findsOneWidget);
    expect(find.textContaining('100 %'), findsOneWidget);
  });

  testWidgets('a zero objective is treated as no objective at all', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CagnotteCard(totalCents: 1000, targetCents: 0)),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('every shared state renders in dark mode', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            EmptyState(icon: Icons.groups_outlined, title: 'Vide'),
            CagnotteCard(totalCents: 100),
          ],
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
