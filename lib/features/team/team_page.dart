import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/session_exception.dart';
import '../../data/session_store.dart';
import '../../models/company_role.dart';
import '../../models/invitation.dart';
import '../../models/membership.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final _email = TextEditingController();
  String? _error;
  String? _copiedId;
  var _loading = true;
  var _inviting = false;
  String? _revokingId;
  String? _removingId;
  var _copiedKind = _CopiedKind.link;
  var _role = CompanyRole.employee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<SessionStore>();
    if (!session.canViewTeam) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      await session.loadTeam();
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar el equipo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    setState(() {
      _error = null;
      _inviting = true;
    });
    try {
      final invitation = await context.read<SessionStore>().inviteEmployee(
        _email.text,
        role: _role,
      );
      _email.clear();
      await _copy(invitation);
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _copy(Invitation invitation) async {
    final session = context.read<SessionStore>();
    await Clipboard.setData(
      ClipboardData(text: session.inviteShareUrl(invitation)),
    );
    if (mounted) {
      setState(() {
        _copiedId = invitation.id;
        _copiedKind = _CopiedKind.link;
      });
    }
  }

  Future<void> _copyCode(Invitation invitation) async {
    final code = invitation.code;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      setState(() {
        _copiedId = invitation.id;
        _copiedKind = _CopiedKind.code;
      });
    }
  }

  Future<void> _revoke(Invitation invitation) async {
    setState(() {
      _error = null;
      _revokingId = invitation.id;
    });
    try {
      await context.read<SessionStore>().revokeInvitation(invitation.id);
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  Future<void> _remove(Membership member) async {
    final companyName =
        context.read<SessionStore>().company?.name ?? 'la empresa';
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Eliminar del equipo',
      message:
          '¿Eliminar a ${member.displayName} de $companyName? Va a perder el acceso.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _error = null;
      _removingId = member.uid;
    });
    try {
      await context.read<SessionStore>().removeMember(member.uid);
    } on SessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Equipo',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            session.company?.name ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.stockLow),
            ),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.terracotta,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              'Miembros',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final member in session.members)
              _MemberTile(
                member: member,
                canRemove: session.isOwner && member.role != CompanyRole.owner,
                removing: _removingId == member.uid,
                onRemove: () => _remove(member),
              ),
            if (session.isOwner) ...[
              const SizedBox(height: 24),
              Text(
                'Invitar',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<CompanyRole>(
                showSelectedIcon: false,
                segments: [
                  for (final role in CompanyRole.assignable)
                    ButtonSegment<CompanyRole>(
                      value: role,
                      label: Text(role.label),
                    ),
                ],
                selected: {_role},
                onSelectionChanged: _inviting
                    ? null
                    : (selected) {
                        setState(() => _role = selected.first);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                enabled: !_inviting,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _inviting ? null : _invite,
                child: _inviting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Crear invitación'),
              ),
              if (session.pendingInvitations.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Pendientes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final invitation in session.pendingInvitations)
                  _InviteTile(
                    invitation: invitation,
                    copied: _copiedId == invitation.id,
                    copiedKind: _copiedKind,
                    revoking: _revokingId == invitation.id,
                    onCopyLink: () => _copy(invitation),
                    onCopyCode: () => _copyCode(invitation),
                    onRevoke: () => _revoke(invitation),
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

enum _CopiedKind { link, code }

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canRemove,
    required this.removing,
    required this.onRemove,
  });

  final Membership member;
  final bool canRemove;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.terracottaSoft,
        child: Text(
          member.displayName.isEmpty
              ? '?'
              : member.displayName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: AppColors.terracotta,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(member.displayName),
      subtitle: Text(member.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            member.role.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          if (canRemove) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: removing ? null : onRemove,
              icon: removing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.terracotta,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invitation,
    required this.copied,
    required this.copiedKind,
    required this.revoking,
    required this.onCopyLink,
    required this.onCopyCode,
    required this.onRevoke,
  });

  final Invitation invitation;
  final bool copied;
  final _CopiedKind copiedKind;
  final bool revoking;
  final VoidCallback onCopyLink;
  final VoidCallback onCopyCode;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final code = invitation.code;
    final subtitle = copied
        ? (copiedKind == _CopiedKind.code
              ? 'Código copiado · ${invitation.role.label}'
              : 'Enlace copiado · ${invitation.role.label}')
        : (code == null || code.isEmpty
              ? 'Pendiente · ${invitation.role.label}'
              : 'Pendiente · ${invitation.role.label} · $code');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(invitation.email),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (code != null && code.isNotEmpty)
            IconButton(
              tooltip: 'Copiar código',
              onPressed: revoking ? null : onCopyCode,
              icon: const Icon(Icons.pin_outlined),
            ),
          IconButton(
            tooltip: 'Copiar enlace',
            onPressed: revoking ? null : onCopyLink,
            icon: const Icon(Icons.link),
          ),
          IconButton(
            tooltip: 'Revocar',
            onPressed: revoking ? null : onRevoke,
            icon: revoking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.terracotta,
                    ),
                  )
                : const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
