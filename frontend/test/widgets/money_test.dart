import 'package:app/core/design/theme.dart';
import 'package:app/widgets/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every widget under test needs the real theme: `MoelanColors` lives in a
/// `ThemeExtension`, and a widget that reaches for it under a bare
/// `MaterialApp` would throw.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark
        ? MoelanTheme.dark()
        : MoelanTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('formats cents as euros, never as a float', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText(-450)));
    expect(find.textContaining('4,50'), findsOneWidget);
    expect(find.textContaining('4.5'), findsNothing);
  });

  testWidgets('shows a debt and a credit in different colours', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Column(children: [MoneyText(-450), MoneyText(450)]),
      ),
    );
    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts, hasLength(2));
    expect(texts[0].style!.color, isNot(texts[1].style!.color));
  });

  testWidgets('a zero balance is neither red nor green', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText(0)));
    final BuildContext context = tester.element(find.byType(MoneyText));
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });

  testWidgets('signs a credit only when asked', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText(450, showSign: true)));
    expect(find.textContaining('+'), findsOneWidget);
  });

  testWidgets('uses tabular figures so a column of amounts lines up', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const MoneyText(1234)));
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(
      style.fontFeatures?.map((f) => f.feature),
      contains('tnum'),
    );
  });

  testWidgets('BalancePill renders in both light and dark themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _wrap(const BalancePill(-1200), brightness: brightness),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('12,00'), findsOneWidget);
    }
  });
}
