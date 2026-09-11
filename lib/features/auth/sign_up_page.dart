import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../theme/tokens.dart';
import 'auth_layout.dart';
import 'invite_ref.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  InviteRef? get _invite {
    return InviteRef.fromQuery(GoRouterState.of(context).uri);
  }

  bool get _hasCode => _code.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() => _error = null);
    final invite = _invite;
    final skipCompany = invite != null || _hasCode;
    try {
      await context.read<SessionStore>().signUp(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        companyName: skipCompany ? null : _company.text,
        inviteCompanyId: invite?.companyId,
        inviteId: invite?.invitationId,
        inviteCode: _code.text,
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
      title: 'Crear cuenta',
      subtitle: invite == null
          ? 'Tu cuenta queda como propietaria de la empresa.'
          : 'Tu cuenta se une al equipo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          if (invite == null && !_hasCode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
              ),
            ),
          ],
          const SizedBox(height: 12),
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
            textInputAction: invite == null
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted: invite == null
                ? null
                : (_) => session.isBusy ? null : _submit(),
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          if (invite == null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => session.isBusy ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Código de invitación',
              ),
            ),
          ],
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
            child: Text(session.isBusy ? 'Creando…' : 'Crear cuenta'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              final path = invite == null
                  ? '/ingresar'
                  : invite.appendTo('/ingresar');
              context.go(path);
            },
            child: const Text('Ya tengo cuenta'),
          ),
        ],
      ),
    );
  }
}
