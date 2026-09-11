class InviteRef {
  const InviteRef({required this.companyId, required this.invitationId});

  final String companyId;
  final String invitationId;

  static InviteRef? fromQuery(Uri uri) {
    final companyId = uri.queryParameters['companyId']?.trim() ?? '';
    final invitationId = uri.queryParameters['invitationId']?.trim() ?? '';
    if (companyId.isEmpty || invitationId.isEmpty) return null;
    return InviteRef(companyId: companyId, invitationId: invitationId);
  }

  String get query => 'companyId=$companyId&invitationId=$invitationId';

  String appendTo(String path) => '$path?$query';
}
