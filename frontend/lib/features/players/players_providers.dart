import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../models/consumable_type.dart';
import '../../models/fine_type.dart';
import '../../models/player.dart';
import '../../models/transaction.dart';

/// Every provider below watches `currentUserProvider` purely to be
/// invalidated when the signed-in identity changes (login, logout, a
/// different account in the same browser session) — otherwise a
/// `FutureProvider` caches its result forever and the next account to sign
/// in would see the previous one's org data until something else happened
/// to invalidate it.
final playersListProvider = FutureProvider<List<Player>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(cagnotteRepositoryProvider).listPlayers();
});

final playerDetailProvider = FutureProvider.family<Player, String>((ref, id) {
  ref.watch(currentUserProvider);
  return ref.watch(cagnotteRepositoryProvider).getPlayer(id);
});

final playerTransactionsProvider =
    FutureProvider.family<List<Transaction>, String>((ref, playerId) {
      ref.watch(currentUserProvider);
      return ref
          .watch(cagnotteRepositoryProvider)
          .listPlayerTransactions(playerId);
    });

final consumableTypesProvider = FutureProvider<List<ConsumableType>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(cagnotteRepositoryProvider).listConsumableTypes();
});

final fineTypesProvider = FutureProvider<List<FineType>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(cagnotteRepositoryProvider).listFineTypes();
});

/// Call after any write that changes a player's balance or the ledger, so
/// the dashboard, the detail screen and its history all pick it up.
void invalidatePlayerData(WidgetRef ref, String playerId) {
  ref.invalidate(playersListProvider);
  ref.invalidate(playerDetailProvider(playerId));
  ref.invalidate(playerTransactionsProvider(playerId));
}
