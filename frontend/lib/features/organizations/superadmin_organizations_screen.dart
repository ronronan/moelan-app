import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cagnotte_repository.dart';
import '../../models/organization.dart';

final pendingOrganizationsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) {
      return ref.watch(cagnotteRepositoryProvider).listPendingOrganizations();
    });

class SuperAdminOrganizationsScreen extends ConsumerWidget {
  const SuperAdminOrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Espaces en attente')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingOrganizationsProvider.future),
        child: pendingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Erreur : $err')),
          data: (orgs) {
            if (orgs.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Aucun espace en attente.')),
                  ),
                ],
              );
            }
            return ListView(
              children: [
                for (final org in orgs)
                  ListTile(
                    title: Text(org.name),
                    subtitle: Text(org.contactEmail),
                    trailing: FilledButton(
                      onPressed: () async {
                        await ref
                            .read(cagnotteRepositoryProvider)
                            .approveOrganization(org.id);
                        ref.invalidate(pendingOrganizationsProvider);
                      },
                      child: const Text('Valider'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
