import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/consumable_type.dart';
import '../models/fine_type.dart';
import '../models/me_status.dart';
import '../models/monthly_stat.dart';
import '../models/organization.dart';
import '../models/player.dart';
import '../models/transaction.dart';
import 'api_client.dart';
import 'auth/auth_providers.dart';

/// Talks to every `/api/*` route: players, consumable/fine type config, and
/// the actions (consumptions/fines/credits) that write to the ledger.
class CagnotteRepository {
  CagnotteRepository(this._dio);

  final Dio _dio;

  Future<List<Player>> listPlayers() async {
    final res = await _dio.get('/api/players');
    return (res.data as List).map((e) => Player.fromJson(e)).toList();
  }

  Future<Player> getPlayer(String id) async {
    final res = await _dio.get('/api/players/$id');
    return Player.fromJson(res.data);
  }

  Future<Player> createPlayer(String firstName, String lastName) async {
    final res = await _dio.post(
      '/api/players',
      data: {'first_name': firstName, 'last_name': lastName},
    );
    return Player.fromJson(res.data);
  }

  Future<List<ConsumableType>> listConsumableTypes() async {
    final res = await _dio.get('/api/consumable-types');
    return (res.data as List).map((e) => ConsumableType.fromJson(e)).toList();
  }

  Future<ConsumableType> patchConsumableType(
    String id, {
    int? priceCents,
    String? label,
    bool? active,
  }) async {
    final res = await _dio.patch(
      '/api/consumable-types/$id',
      data: {'price_cents': ?priceCents, 'label': ?label, 'active': ?active},
    );
    return ConsumableType.fromJson(res.data);
  }

  Future<List<FineType>> listFineTypes() async {
    final res = await _dio.get('/api/fine-types');
    return (res.data as List).map((e) => FineType.fromJson(e)).toList();
  }

  Future<FineType> createFineType(
    String code,
    String label,
    int amountCents,
  ) async {
    final res = await _dio.post(
      '/api/fine-types',
      data: {'code': code, 'label': label, 'amount_cents': amountCents},
    );
    return FineType.fromJson(res.data);
  }

  Future<FineType> patchFineType(
    String id, {
    int? amountCents,
    String? label,
    bool? active,
  }) async {
    final res = await _dio.patch(
      '/api/fine-types/$id',
      data: {'amount_cents': ?amountCents, 'label': ?label, 'active': ?active},
    );
    return FineType.fromJson(res.data);
  }

  Future<Transaction> recordConsumption(
    String playerId,
    String consumableTypeId,
  ) async {
    final res = await _dio.post(
      '/api/players/$playerId/consumptions',
      data: {'consumable_type_id': consumableTypeId},
    );
    return Transaction.fromJson(res.data);
  }

  Future<Transaction> recordFine(
    String playerId,
    String fineTypeId, {
    String? note,
  }) async {
    final res = await _dio.post(
      '/api/players/$playerId/fines',
      data: {'fine_type_id': fineTypeId, 'note': ?note},
    );
    return Transaction.fromJson(res.data);
  }

  Future<Transaction> recordCredit(
    String playerId,
    int amountCents, {
    String? note,
  }) async {
    final res = await _dio.post(
      '/api/players/$playerId/credits',
      data: {'amount_cents': amountCents, 'note': ?note},
    );
    return Transaction.fromJson(res.data);
  }

  Future<List<Transaction>> listPlayerTransactions(String playerId) async {
    final res = await _dio.get('/api/players/$playerId/transactions');
    return (res.data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Player> invitePlayer(String playerId, String email) async {
    final res = await _dio.post(
      '/api/players/$playerId/invite',
      data: {'email': email},
    );
    return Player.fromJson(res.data);
  }

  Future<MeStatus> getMeStatus() async {
    final res = await _dio.get('/api/me');
    return MeStatus.fromJson(res.data);
  }

  Future<Organization> createOrganization(
    String name,
    String contactEmail,
  ) async {
    final res = await _dio.post(
      '/api/organizations',
      data: {'name': name, 'contact_email': contactEmail},
    );
    return Organization.fromJson(res.data);
  }

  Future<List<Organization>> listPendingOrganizations() async {
    final res = await _dio.get('/api/organizations/pending');
    return (res.data as List).map((e) => Organization.fromJson(e)).toList();
  }

  /// Super-admin only: every space, approved or not, to browse into.
  Future<List<Organization>> listOrganizations() async {
    final res = await _dio.get('/api/organizations');
    return (res.data as List).map((e) => Organization.fromJson(e)).toList();
  }

  /// Super-admin only: a given org's players, read-only (the operator isn't
  /// a member of that org, so none of the write endpoints apply to them).
  Future<List<Player>> listPlayersForOrg(String orgId) async {
    final res = await _dio.get('/api/organizations/$orgId/players');
    return (res.data as List).map((e) => Player.fromJson(e)).toList();
  }

  Future<Organization> approveOrganization(String id) async {
    final res = await _dio.patch('/api/organizations/$id/approve');
    return Organization.fromJson(res.data);
  }

  /// The backend replaces both fields unconditionally, so every call must
  /// send the full desired state for each — there's no "leave untouched"
  /// value, and omitting one would silently clear it. `null` clears that
  /// field.
  Future<Organization> patchMyOrganization({
    required int? targetCents,
    required int? debtAlertThresholdCents,
  }) async {
    final res = await _dio.patch(
      '/api/organizations/me',
      data: {
        'target_cents': targetCents,
        'debt_alert_threshold_cents': debtAlertThresholdCents,
      },
    );
    return Organization.fromJson(res.data);
  }

  Future<List<Transaction>> listTransactions({
    String? playerId,
    String? kind,
    DateTime? from,
    DateTime? to,
    int? page,
    int? pageSize,
  }) async {
    final res = await _dio.get(
      '/api/transactions',
      queryParameters: {
        'player_id': ?playerId,
        'kind': ?kind,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        'page': ?page,
        'page_size': ?pageSize,
      },
    );
    return (res.data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<List<MonthlyStat>> getMonthlyStats(int year) async {
    final res = await _dio.get(
      '/api/stats/monthly',
      queryParameters: {'year': year},
    );
    return (res.data as List).map((e) => MonthlyStat.fromJson(e)).toList();
  }

  /// M16 scaffolding — see `core/push/push_notifications.dart`.
  Future<void> registerDeviceToken(String token, String platform) async {
    await _dio.post(
      '/api/me/device-tokens',
      data: {'token': token, 'platform': platform},
    );
  }
}

final cagnotteRepositoryProvider = Provider<CagnotteRepository>((ref) {
  return CagnotteRepository(ref.watch(apiClientProvider));
});

/// Null while logged out (there's nothing to fetch yet); refetches whenever
/// the signed-in user changes, e.g. after a token refresh picks up newly
/// granted group membership (see `create_organization_screen.dart`).
final meStatusProvider = FutureProvider<MeStatus?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  return ref.watch(cagnotteRepositoryProvider).getMeStatus();
});
