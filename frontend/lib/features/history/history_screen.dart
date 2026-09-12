import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/cagnotte_repository.dart';
import '../../core/format.dart';
import '../../models/transaction.dart';
import '../players/players_providers.dart';

const _pageSize = 30;

/// Global transaction history with filters (player, kind, date range) and
/// "load more" pagination. [initialPlayerId] pre-filters when reached from
/// a player's own detail screen.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({this.initialPlayerId, super.key});

  final String? initialPlayerId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _playerId;
  TransactionKind? _kind;
  DateTimeRange? _range;

  final List<Transaction> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _playerId = widget.initialPlayerId;
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() => _loading = true);
    if (reset) {
      _page = 1;
      _items.clear();
      _hasMore = true;
    }

    final results = await ref
        .read(cagnotteRepositoryProvider)
        .listTransactions(
          playerId: _playerId,
          kind: _kind == null ? null : transactionKindToJson(_kind!),
          from: _range?.start,
          to: _range?.end,
          page: _page,
          pageSize: _pageSize,
        );

    if (!mounted) return;
    setState(() {
      _items.addAll(results);
      _hasMore = results.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    _page += 1;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersListProvider);
    final playerNames = {
      for (final p in playersAsync.value ?? []) p.id: p.fullName,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: Column(
        children: [
          _Filters(
            selectedPlayerId: _playerId,
            selectedKind: _kind,
            selectedRange: _range,
            onPlayerChanged: (id) {
              setState(() => _playerId = id);
              _load(reset: true);
            },
            onKindChanged: (kind) {
              setState(() => _kind = kind);
              _load(reset: true);
            },
            onRangeChanged: (range) {
              setState(() => _range = range);
              _load(reset: true);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Aucune transaction.'))
                : ListView(
                    children: [
                      for (final tx in _items)
                        _HistoryTile(
                          transaction: tx,
                          playerName: playerNames[tx.playerId] ?? '—',
                        ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: _loadMore,
                              child: const Text('Charger plus'),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({
    required this.selectedPlayerId,
    required this.selectedKind,
    required this.selectedRange,
    required this.onPlayerChanged,
    required this.onKindChanged,
    required this.onRangeChanged,
  });

  final String? selectedPlayerId;
  final TransactionKind? selectedKind;
  final DateTimeRange? selectedRange;
  final ValueChanged<String?> onPlayerChanged;
  final ValueChanged<TransactionKind?> onKindChanged;
  final ValueChanged<DateTimeRange?> onRangeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersListProvider);
    final dateFormat = DateFormat('dd/MM/yy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          playersAsync.when(
            data: (players) => DropdownButton<String?>(
              value: selectedPlayerId,
              hint: const Text('Tous les joueurs'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tous les joueurs'),
                ),
                for (final p in players)
                  DropdownMenuItem(value: p.id, child: Text(p.fullName)),
              ],
              onChanged: onPlayerChanged,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          DropdownButton<TransactionKind?>(
            value: selectedKind,
            hint: const Text('Tous les types'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les types'),
              ),
              for (final kind in TransactionKind.values)
                DropdownMenuItem(value: kind, child: Text(_kindLabel(kind))),
            ],
            onChanged: onKindChanged,
          ),
          TextButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(
              selectedRange == null
                  ? 'Période'
                  : '${dateFormat.format(selectedRange!.start)} - '
                        '${dateFormat.format(selectedRange!.end)}',
            ),
            onPressed: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: now,
                initialDateRange: selectedRange,
              );
              onRangeChanged(range);
            },
          ),
          if (selectedRange != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Effacer la période',
              onPressed: () => onRangeChanged(null),
            ),
        ],
      ),
    );
  }

  String _kindLabel(TransactionKind kind) => switch (kind) {
    TransactionKind.beer => 'Bière',
    TransactionKind.soft => 'Soft',
    TransactionKind.fine => 'Amende',
    TransactionKind.credit => 'Crédit',
    TransactionKind.manualAdjustment => 'Ajustement',
  };
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.transaction, required this.playerName});

  final Transaction transaction;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amountCents > 0;
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    return ListTile(
      leading: Icon(_iconFor(transaction.kind)),
      title: Text('$playerName · ${_labelFor(transaction.kind)}'),
      subtitle: Text(
        dateFormat.format(transaction.createdAt.toLocal()) +
            (transaction.note != null ? ' · ${transaction.note}' : ''),
      ),
      trailing: Text(
        formatCents(transaction.amountCents),
        style: TextStyle(
          color: positive
              ? Colors.green.shade700
              : Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _iconFor(TransactionKind kind) => switch (kind) {
    TransactionKind.beer => Icons.sports_bar,
    TransactionKind.soft => Icons.local_drink,
    TransactionKind.fine => Icons.gavel,
    TransactionKind.credit => Icons.add_card,
    TransactionKind.manualAdjustment => Icons.build,
  };

  String _labelFor(TransactionKind kind) => switch (kind) {
    TransactionKind.beer => 'Bière',
    TransactionKind.soft => 'Soft',
    TransactionKind.fine => 'Amende',
    TransactionKind.credit => 'Crédit',
    TransactionKind.manualAdjustment => 'Ajustement',
  };
}
