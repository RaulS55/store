import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../models/email.dart';
import '../../theme/tokens.dart';
import 'auth_layout.dart';
import 'invite_ref.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _showCode = false;
  bool _obscurePassword = true;
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

  String? _emailValidator(String? value) {
    if (!isValidEmail(value ?? '')) {
      return 'Ingresá un email válido.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
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
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText);
    return AuthLayout(
      title: 'Iniciar sesión',
      subtitle: invite == null
          ? 'Ingresá tus credenciales para continuar'
          : 'Ingresá para unirte al equipo.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textInputAction: TextInputAction.next,
              validator: _emailValidator,
              decoration: const InputDecoration(
                hintText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              textInputAction: invite == null && _showCode
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: invite == null && _showCode
                  ? null
                  : (_) => session.isBusy ? null : _submit(),
              decoration: InputDecoration(
                hintText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
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
                  hintText: 'Código de invitación',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
            ],
            if (invite == null && !_showCode)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _revealCode,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: session.isBusy ? null : _submit,
              child: Text(session.isBusy ? 'Ingresando…' : 'Ingresar'),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('¿No tenés cuenta? ', style: muted),
                TextButton(
                  onPressed: () {
                    final path = invite == null
                        ? '/registro'
                        : invite.appendTo('/registro');
                    context.go(path);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
