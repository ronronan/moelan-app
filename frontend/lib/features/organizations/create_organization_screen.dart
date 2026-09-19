import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/cagnotte_repository.dart';
import '../../core/design/tokens.dart';
import '../../core/error_message.dart';
import '../../widgets/page_body.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .createOrganization(
            _nameController.text.trim(),
            _emailController.text.trim(),
          );
      // The new group membership only shows up in a *fresh* token — refresh
      // now so the router picks up the space without a manual re-login.
      await ref.read(oidcManagerProvider).refreshToken();
      ref.invalidate(meStatusProvider);
    } catch (error) {
      if (mounted) setState(() => _error = humanizeError(error));
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer mon espace'),
        actions: [
          TextButton(
            onPressed: () async => ref.read(oidcManagerProvider).logout(),
            child: const Text('Se déconnecter'),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: CenteredPageBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.add_home_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                'La caisse noire de votre équipe',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                "Un administrateur devra valider votre espace avant que vous "
                "puissiez l'utiliser. Vous en serez l'administrateur.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: Gap.xxl),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nom de l'équipe",
                  hintText: 'Les Ours de Quimper',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "Donnez un nom à votre équipe"
                    : null,
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email de contact',
                  helperText: 'Reçoit les alertes de dette.',
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Email obligatoire';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Adresse invalide';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Gap.xl),
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
            ],
          ),
        ),
      ),
    );
  }
}
