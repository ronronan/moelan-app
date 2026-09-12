import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';

class CreateOrganizationScreen extends ConsumerStatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  ConsumerState<CreateOrganizationScreen> createState() =>
      _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState
    extends ConsumerState<CreateOrganizationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .createOrganization(name, email);
      // The new group membership only shows up in a *fresh* token — refresh
      // now so the router picks up the space without a manual re-login.
      await ref.read(oidcManagerProvider).refreshToken();
      ref.invalidate(meStatusProvider);
    } catch (e) {
      if (mounted) setState(() => _error = "Impossible de créer l'espace : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon espace')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Créez la caisse noire de votre équipe. Un administrateur "
                  "devra valider votre espace avant que vous puissiez "
                  "commencer à l'utiliser.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nom de l'équipe",
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de contact',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Créer l'espace"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async => ref.read(oidcManagerProvider).logout(),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
