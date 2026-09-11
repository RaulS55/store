import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../theme/tokens.dart';
import 'auth_layout.dart';
import 'invite_ref.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InviteRef? get _invite {
    return InviteRef.fromQuery(GoRouterState.of(context).uri);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final invite = _invite;
    try {
      await context.read<SessionStore>().signIn(
        email: _email.text,
        password: _password.text,
        inviteCompanyId: invite?.companyId,
        inviteId: invite?.invitationId,
      );
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final invite = _invite;
    return AuthLayout(
      title: 'Ingresar',
      subtitle: invite == null
          ? 'Usá el email de tu cuenta.'
          : 'Ingresá para unirte al equipo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => session.isBusy ? null : _submit(),
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.stockLow),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: session.isBusy ? null : _submit,
            child: Text(session.isBusy ? 'Ingresando…' : 'Ingresar'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              final path = invite == null
                  ? '/registro'
                  : invite.appendTo('/registro');
              context.go(path);
            },
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
