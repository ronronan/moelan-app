import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cagnotte_repository.dart';
import '../../models/consumable_type.dart';
import '../../models/fine_type.dart';
import '../../models/player.dart';
import '../../models/transaction.dart';

final playersListProvider = FutureProvider<List<Player>>((ref) {
  return ref.watch(cagnotteRepositoryProvider).listPlayers();
});

final playerDetailProvider = FutureProvider.family<Player, String>((ref, id) {
  return ref.watch(cagnotteRepositoryProvider).getPlayer(id);
});

final playerTransactionsProvider = FutureProvider.family<List<Transaction>, String>((
  ref,
  playerId,
) {
  return ref.watch(cagnotteRepositoryProvider).listPlayerTransactions(playerId);
});

final consumableTypesProvider = FutureProvider<List<ConsumableType>>((ref) {
  return ref.watch(cagnotteRepositoryProvider).listConsumableTypes();
});

final fineTypesProvider = FutureProvider<List<FineType>>((ref) {
  return ref.watch(cagnotteRepositoryProvider).listFineTypes();
});

/// Call after any write that changes a player's balance or the ledger, so
/// the dashboard, the detail screen and its history all pick it up.
void invalidatePlayerData(WidgetRef ref, String playerId) {
  ref.invalidate(playersListProvider);
  ref.invalidate(playerDetailProvider(playerId));
  ref.invalidate(playerTransactionsProvider(playerId));
}
