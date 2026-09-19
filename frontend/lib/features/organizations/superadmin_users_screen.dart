import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../models/app_user.dart';
import '../../widgets/common.dart';
import '../../widgets/page_body.dart';
import '../../widgets/states.dart';

final allUsersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.watch(cagnotteRepositoryProvider).listUsers();
});

/// Human label for the org role carried by the account's Keycloak group.
/// `null` means the account has no space yet — not an error, just someone
/// who registered and hasn't created or been invited into one.
String _roleLabel(AppUser user) => switch (user.orgRole) {
  'admin' => 'Admin',
  'member' => 'Membre',
  'player' => 'Joueur',
  null => 'Sans rôle',
  final other => other,
};

/// Cross-space roster: every account of the instance, its role, and the
/// space it belongs to. Super-admin only — it's the one view that spans
/// organizations, which no space-level admin is allowed to see.
class SuperAdminUsersScreen extends ConsumerStatefulWidget {
  const SuperAdminUsersScreen({super.key});

  @override
  ConsumerState<SuperAdminUsersScreen> createState() =>
      _SuperAdminUsersScreenState();
}

class _SuperAdminUsersScreenState extends ConsumerState<SuperAdminUsersScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: usersAsync.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          error: err,
          onRetry: () => ref.invalidate(allUsersProvider),
        ),
        data: (users) {
          final query = _search.trim().toLowerCase();
          final filtered = query.isEmpty
              ? users
              : users.where((u) {
                  return u.username.toLowerCase().contains(query) ||
                      u.fullName.toLowerCase().contains(query) ||
                      (u.email ?? '').toLowerCase().contains(query) ||
                      (u.organizationName ?? '').toLowerCase().contains(query);
                }).toList();

          // The API already returns them grouped by space; keeping that
          // order and drawing the boundaries makes the listing answer the
          // question it exists for — who is in which space.
          final groups = <String, List<AppUser>>{};
          for (final user in filtered) {
            groups
                .putIfAbsent(
                  user.organizationName ?? 'Sans espace',
                  () => <AppUser>[],
                )
                .add(user);
          }

          return PageBody(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Gap.lg),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un nom, un email, un espace',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Effacer',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'Aucun compte',
                          message: query.isEmpty
                              ? "Cette instance n'a aucun compte enregistré."
                              : 'Aucun compte ne correspond à « $_search ».',
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref.refresh(allUsersProvider.future),
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: Gap.xxl),
                            children: [
                              for (final entry in groups.entries) ...[
                                SectionHeader(
                                  entry.key,
                                  trailing: Text(
                                    '${entry.value.length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ),
                                for (final user in entry.value)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Gap.sm,
                                    ),
                                    child: _UserCard(user: user),
                                  ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = user.organizationApproved == false;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Row(
        children: [
          InitialsAvatar(user.fullName, muted: !user.enabled),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!user.enabled) ...[
                      const SizedBox(width: Gap.sm),
                      Text(
                        'désactivé',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email ?? user.username,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (pending) ...[
                  const SizedBox(height: 2),
                  Text(
                    'espace en attente de validation',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          _RoleBadge(user: user),
        ],
      ),
    );
  }
}

/// The role, as a single pill. A super-admin who also holds a space role
/// gets two, because they really are two different powers.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (user.orgRole) {
      'admin' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'member' => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    Widget pill(String label, Color background, Color foreground, IconData? icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: Gap.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (user.superadmin)
          pill(
            'Super-admin',
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
            Icons.shield_outlined,
          ),
        if (user.superadmin && user.orgRole != null) const SizedBox(height: 4),
        if (!user.superadmin || user.orgRole != null)
          pill(_roleLabel(user), background, foreground, null),
      ],
    );
  }
}
