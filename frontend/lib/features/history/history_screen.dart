import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../models/transaction.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';
import '../../widgets/transaction_tile.dart';
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
  Object? _error;

  @override
  void initState() {
    super.initState();
    _playerId = widget.initialPlayerId;
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (reset) {
      _page = 1;
      _items.clear();
      _hasMore = true;
    }

    try {
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
    } catch (error) {
      // Before this, a failed page left the spinner turning forever and the
      // exception went nowhere.
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    _page += 1;
    await _load();
  }

  void _applyFilter(VoidCallback change) {
    setState(change);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersListProvider);
    final playerNames = <String, String>{
      for (final p in playersAsync.value ?? const []) p.id: p.fullName,
    };
    final filtered = _playerId != null || _kind != null || _range != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (filtered)
            TextButton(
              onPressed: () => _applyFilter(() {
                _playerId = null;
                _kind = null;
                _range = null;
              }),
              child: const Text('Effacer'),
            ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: Column(
        children: [
          _Filters(
            selectedPlayerId: _playerId,
            selectedKind: _kind,
            selectedRange: _range,
            onPlayerChanged: (id) => _applyFilter(() => _playerId = id),
            onKindChanged: (kind) => _applyFilter(() => _kind = kind),
            onRangeChanged: (range) => _applyFilter(() => _range = range),
          ),
          Expanded(child: _body(playerNames)),
        ],
      ),
    );
  }

  Widget _body(Map<String, String> playerNames) {
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: () => _load(reset: true));
    }
    if (_loading && _items.isEmpty) {
      return PageBody.wide(
        child: ListView(
          padding: const EdgeInsets.only(top: Gap.lg),
          children: [
            for (var i = 0; i < 8; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.sm),
                child: SkeletonBox(height: 38, radius: Radii.sm),
              ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aucun mouvement',
        message: _playerId != null || _kind != null || _range != null
            ? 'Aucun mouvement ne correspond à ces filtres.'
            : "Rien n'a encore été enregistré dans cet espace.",
      );
    }

    // Grouped by day, because a ledger is read by session ("what happened
    // after Saturday's match"), not as one undifferentiated stream.
    final groups = <String, List<Transaction>>{};
    for (final tx in _items) {
      groups.putIfAbsent(_dayLabel(tx.createdAt.toLocal()), () => []).add(tx);
    }

    return PageBody.wide(
      child: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        children: [
          for (final entry in groups.entries) ...[
            _DayHeader(label: entry.key),
            for (final tx in entry.value)
              TransactionTile(
                transaction: tx,
                leadingLabel: _playerId == null
                    ? (playerNames[tx.playerId] ?? '—')
                    : null,
              ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(Gap.lg),
              child: LoadingView(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: ErrorView(error: _error!, onRetry: _loadMore),
            )
          else if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Charger plus'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final _dayFormat = DateFormat('EEEE d MMMM', 'fr_FR');

String _dayLabel(DateTime date) {
  final today = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final reference = DateTime(today.year, today.month, today.day);
  final difference = reference.difference(day).inDays;
  if (difference == 0) return "Aujourd'hui";
  if (difference == 1) return 'Hier';
  return _dayFormat.format(date);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.xs),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Filters as chips rather than dropdowns: on a phone, three bare
/// `DropdownButton`s stacked in a `Wrap` gave no sense of what was active.
/// A selected chip is visibly on.
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
    final dateFormat = DateFormat('d MMM', 'fr_FR');
    final players = playersAsync.value ?? const [];
    final selectedPlayer = players
        .where((p) => p.id == selectedPlayerId)
        .firstOrNull;

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        children: [
          const SizedBox(width: 0),
          PopupMenuButton<String?>(
            tooltip: 'Filtrer par joueur',
            onSelected: onPlayerChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Tous les joueurs')),
              for (final p in players)
                PopupMenuItem(value: p.id, child: Text(p.fullName)),
            ],
            child: _FilterChipLike(
              label: selectedPlayer?.fullName ?? 'Tous les joueurs',
              icon: Icons.person_outline,
              selected: selectedPlayerId != null,
            ),
          ),
          const SizedBox(width: Gap.sm),
          PopupMenuButton<TransactionKind?>(
            tooltip: 'Filtrer par type',
            onSelected: onKindChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Tous les types')),
              for (final kind in TransactionKind.values)
                PopupMenuItem(value: kind, child: Text(kind.label)),
            ],
            child: _FilterChipLike(
              label: selectedKind?.label ?? 'Tous les types',
              icon: Icons.category_outlined,
              selected: selectedKind != null,
            ),
          ),
          const SizedBox(width: Gap.sm),
          InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: () async {
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: now,
                initialDateRange: selectedRange,
              );
              if (range != null) onRangeChanged(range);
            },
            child: _FilterChipLike(
              label: selectedRange == null
                  ? 'Période'
                  : '${dateFormat.format(selectedRange!.start)} – '
                        '${dateFormat.format(selectedRange!.end)}',
              icon: Icons.date_range_outlined,
              selected: selectedRange != null,
              onClear: selectedRange == null
                  ? null
                  : () => onRangeChanged(null),
            ),
          ),
          const SizedBox(width: Gap.lg),
        ],
      ),
    );
  }
}

class _FilterChipLike extends StatelessWidget {
  const _FilterChipLike({
    required this.label,
    required this.icon,
    required this.selected,
    this.onClear,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Gap.sm),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: selected ? scheme.secondaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: Gap.xs + 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: foreground),
          ),
          if (onClear != null) ...[
            const SizedBox(width: Gap.xs),
            InkWell(
              onTap: onClear,
              child: Icon(Icons.close, size: 15, color: foreground),
            ),
          ],
        ],
      ),
    );
  }
}
