import 'package:app/core/design/theme.dart';
import 'package:app/core/design/tokens.dart';
import 'package:app/models/transaction.dart';
import 'package:app/widgets/cagnotte_card.dart';
import 'package:app/widgets/common.dart';
import 'package:app/widgets/money.dart';
import 'package:app/widgets/states.dart';
import 'package:app/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A single page showing every shared surface at once, rendered in both
/// themes. It is the design system's contract made visible: a change that
/// alters any component's colour, spacing or shape shows up here as a failed
/// golden, in the one place where all of them sit side by side.
///
/// Regenerate after a deliberate change:
/// `flutter test --update-goldens test/golden`
Widget _sheet(Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark
        ? MoelanTheme.dark()
        : MoelanTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Moelan'),
          actions: const [
            Icon(Icons.insights_outlined),
            SizedBox(width: Gap.lg),
            Icon(Icons.receipt_long_outlined),
            SizedBox(width: Gap.lg),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          children: [
            const CagnotteCard(
              totalCents: 124700,
              targetCents: 200000,
              playerCount: 14,
            ),
            const SectionHeader('Effectif'),
            for (final (name, cents) in const [
              ('Paul Durand', -450),
              ('Marc Petit', 1250),
              ('Léa Bernard', 0),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.md,
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(name),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      BalancePill(cents),
                    ],
                  ),
                ),
              ),
            const SectionHeader('Derniers mouvements'),
            for (final (kind, cents) in const [
              (TransactionKind.beer, -300),
              (TransactionKind.fine, -500),
              (TransactionKind.credit, 2000),
            ])
              TransactionTile(
                transaction: Transaction(
                  id: 'tx',
                  playerId: 'p',
                  kind: kind,
                  amountCents: cents,
                  quantity: kind == TransactionKind.beer ? 3 : 1,
                  note: null,
                  createdBy: 'test',
                  createdAt: DateTime(2026, 3, 12, 21, 30),
                ),
              ),
            const SectionHeader('Actions'),
            Wrap(
              spacing: Gap.md,
              runSpacing: Gap.sm,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Créditer')),
                OutlinedButton(onPressed: () {}, child: const Text('Refuser')),
                TextButton(onPressed: () {}, child: const Text('Annuler')),
              ],
            ),
            const SizedBox(height: Gap.lg),
            const TextField(
              decoration: InputDecoration(labelText: 'Montant', suffixText: 'EUR'),
            ),
            const SizedBox(height: Gap.xl),
            const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Aucun joueur pour le moment',
              message: "Ajoutez les membres de l'equipe.",
            ),
            const SizedBox(height: Gap.xl),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // `main.dart` does this before the first frame; a test builds widgets
  // without going through it, and `TransactionTile`'s French date format
  // throws without the locale data.
  setUpAll(() => initializeDateFormatting('fr_FR'));

  for (final brightness in Brightness.values) {
    testWidgets('design sheet — ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(420, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_sheet(brightness));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('design_sheet_${brightness.name}.png'),
      );
    });
  }
}
