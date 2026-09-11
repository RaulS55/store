import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../theme/tokens.dart';
import 'auth_layout.dart';
import 'invite_ref.dart';

class AcceptInvitePage extends StatefulWidget {
  const AcceptInvitePage({
    super.key,
    required this.companyId,
    required this.invitationId,
  });

  final String companyId;
  final String invitationId;

  @override
  State<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends State<AcceptInvitePage> {
  String? _error;
  var _accepting = false;

  InviteRef get _invite {
    return InviteRef(
      companyId: widget.companyId,
      invitationId: widget.invitationId,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAccept());
  }

  Future<void> _maybeAccept() async {
    if (!mounted || _accepting) return;
    final session = context.read<SessionStore>();
    if (!session.hasIdentity) return;
    if (session.isSignedIn && session.companyId == widget.companyId) {
      context.go('/');
      return;
    }
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await session.acceptInvitation(widget.companyId, widget.invitationId);
      if (mounted) context.go('/');
    } on SessionException catch (error) {
      if (mounted) {
        setState(() {
          _accepting = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    if (session.hasIdentity && _error == null && !_accepting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAccept());
    }
    return AuthLayout(
      title: 'Invitación al equipo',
      subtitle: session.hasIdentity
          ? 'Estamos uniendo tu cuenta a la empresa.'
          : 'Ingresá o creá una cuenta con el email invitado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.stockLow),
            ),
            const SizedBox(height: 16),
          ],
          if (!session.hasIdentity) ...[
            FilledButton(
              onPressed: () => context.go(_invite.appendTo('/ingresar')),
              child: const Text('Ingresar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(_invite.appendTo('/registro')),
              child: const Text('Crear cuenta'),
            ),
          ] else if (_accepting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.terracotta,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
