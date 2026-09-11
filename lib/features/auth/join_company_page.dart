import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../theme/tokens.dart';
import 'auth_layout.dart';

class JoinCompanyPage extends StatefulWidget {
  const JoinCompanyPage({super.key});

  @override
  State<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends State<JoinCompanyPage> {
  final _code = TextEditingController();
  final _company = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _company.dispose();
    super.dispose();
  }

  Future<void> _joinWithCode() async {
    setState(() => _error = null);
    try {
      await context.read<SessionStore>().joinWithInviteCode(_code.text);
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _createCompany() async {
    setState(() => _error = null);
    try {
      await context.read<SessionStore>().createOwnedCompany(_company.text);
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _signOut() async {
    setState(() => _error = null);
    try {
      await context.read<SessionStore>().signOut();
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    return AuthLayout(
      title: 'Unirse a una empresa',
      subtitle: 'Ingresá un código de invitación o creá tu propia empresa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enabled: !session.isBusy,
            decoration: const InputDecoration(
              labelText: 'Código de invitación',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: session.isBusy ? null : _joinWithCode,
            child: Text(session.isBusy ? 'Uniendo…' : 'Unirse con código'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _company,
            textCapitalization: TextCapitalization.words,
            enabled: !session.isBusy,
            decoration: const InputDecoration(
              labelText: 'Nombre de la empresa',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: session.isBusy ? null : _createCompany,
            child: const Text('Crear empresa'),
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
          TextButton(
            onPressed: session.isBusy ? null : _signOut,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
