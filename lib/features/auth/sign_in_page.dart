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
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _showCode = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  InviteRef? get _invite {
    return InviteRef.fromQuery(GoRouterState.of(context).uri);
  }

  void _revealCode() {
    setState(() => _showCode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
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
            textInputAction: invite == null && _showCode
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted: invite == null && _showCode
                ? null
                : (_) => session.isBusy ? null : _submit(),
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          if (invite == null && _showCode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              focusNode: _codeFocus,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => session.isBusy ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Código de invitación',
              ),
            ),
          ],
          if (invite == null && !_showCode)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _revealCode,
                child: const Text('¿Tenés un código de invitación?'),
              ),
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
