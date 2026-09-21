import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/company.dart';
import '../models/company_role.dart';
import '../models/email.dart';
import '../models/invitation.dart';
import '../models/membership.dart';
import 'auth_client.dart';
import 'company_access.dart';
import 'session_cache.dart';
import 'session_exception.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({
    required AuthClient auth,
    required CompanyAccess access,
    this.cache,
    this.authReadyTimeout = const Duration(seconds: 8),
  }) : _auth = auth,
       _access = access;

  final AuthClient _auth;
  final CompanyAccess _access;
  final SessionCache? cache;
  final Duration authReadyTimeout;

  StreamSubscription<AuthIdentity?>? _authSub;
  Timer? _readyTimeout;
  Completer<void>? _readyCompleter;
  int _loadGen = 0;

  bool _ready = false;
  bool _busy = false;
  bool _networkProfileLoaded = false;
  AuthIdentity? _identity;
  AppUser? _user;
  Company? _company;
  Membership? _membership;
  List<Membership> _members = const [];
  List<Invitation> _invitations = const [];

  bool get isReady => _ready;
  bool get isBusy => _busy;
  bool get hasIdentity => _identity != null;
  bool get isSignedIn =>
      _ready && _user != null && _company != null && _membership != null;
  bool get isOwner => _membership?.role == CompanyRole.owner;
  bool get canViewTeam => _membership?.role.canViewTeam ?? false;
  bool get canDeleteProduct => _membership?.role.canDeleteProduct ?? false;
  bool get canDeleteCustomer => _membership?.role.canDeleteCustomer ?? false;
  bool get canEditCompanySettings =>
      _membership?.role.canEditCompanySettings ?? false;
  bool get canManageLots => _membership?.role.canManageLots ?? false;
  bool get canViewLotStats => _membership?.role.canViewLotStats ?? false;
  bool get needsCompany => isReady && hasIdentity && !isSignedIn;

  AuthIdentity? get identity => _identity;
  AppUser? get user => _user;
  Company? get company => _company;
  Membership? get membership => _membership;
  String? get companyId => _company?.id;
  List<Membership> get members => List.unmodifiable(_members);
  List<Invitation> get invitations => List.unmodifiable(_invitations);
  List<Invitation> get pendingInvitations => [
    for (final invitation in _invitations)
      if (invitation.isPending) invitation,
  ];

  Future<void> get initialized {
    final pending = _readyCompleter;
    if (_ready || pending == null) return Future.value();
    return pending.future;
  }

  void start() {
    if (_authSub != null) return;
    _readyCompleter = Completer<void>();
    _authSub = _auth.authStateChanges.listen(_onAuthChanged);
    _readyTimeout?.cancel();
    _readyTimeout = Timer(authReadyTimeout, () {
      if (_ready || _identity != null) return;
      _clearSession();
      _markReady();
      notifyListeners();
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
    String? inviteCompanyId,
    String? inviteId,
    String? inviteCode,
  }) {
    return _run(() async {
      final identity = await _auth.signInWithEmail(
        email: email,
        password: password,
      );
      await _finishAuthenticated(
        identity: identity,
        displayName: identity.email,
        inviteCompanyId: inviteCompanyId,
        inviteId: inviteId,
        inviteCode: inviteCode,
      );
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    String? companyName,
    String? inviteCompanyId,
    String? inviteId,
    String? inviteCode,
  }) {
    return _run(() async {
      final name = displayName.trim();
      if (name.isEmpty) {
        throw const SessionException('Ingresá tu nombre.');
      }
      if (!isValidEmail(email)) {
        throw const SessionException('Ingresá un email válido.');
      }
      if (password.length < 6) {
        throw const SessionException(
          'La contraseña debe tener al menos 6 caracteres.',
        );
      }

      AuthIdentity? created;
      try {
        created = await _auth.createUserWithEmail(
          email: email,
          password: password,
        );
        await _finishAuthenticated(
          identity: created,
          displayName: name,
          companyName: companyName,
          inviteCompanyId: inviteCompanyId,
          inviteId: inviteId,
          inviteCode: inviteCode,
        );
      } catch (error) {
        if (created != null) {
          await _auth.signOut();
        }
        rethrow;
      }
    });
  }

  Future<void> signOut() {
    return _run(() async {
      final uid = _user?.id ?? _identity?.uid;
      await _auth.signOut();
      _clearSession();
      if (uid != null) await cache?.clear(uid);
    });
  }

  Future<Invitation> inviteEmployee(
    String email, {
    CompanyRole role = CompanyRole.employee,
  }) async {
    if (!role.isAssignable) {
      throw const SessionException('Elegí Administrador o Empleado.');
    }
    final current = _requireOwner();
    final invitation = await _access.createInvitation(
      companyId: current.company.id,
      companyName: current.company.name,
      email: email,
      invitedBy: current.user.id,
      role: role,
    );
    await loadTeam();
    return invitation;
  }

  Future<void> acceptInvitation(String companyId, String invitationId) {
    return _run(() async {
      final identity = _identity;
      if (identity == null) {
        throw const SessionException('Ingresá para aceptar la invitación.');
      }
      if (_user != null && _user!.companyId.isNotEmpty) {
        throw const SessionException('Ya pertenecés a una empresa.');
      }
      await _access.acceptInvitation(
        uid: identity.uid,
        email: identity.email,
        displayName: _displayNameFor(identity),
        companyId: companyId,
        invitationId: invitationId,
      );
      await _loadProfile(identity);
    });
  }

  Future<void> revokeInvitation(String invitationId) async {
    final current = _requireOwner();
    await _access.revokeInvitation(
      companyId: current.company.id,
      invitationId: invitationId,
    );
    await loadTeam();
  }

  Future<void> removeMember(String uid) async {
    final current = _requireOwner();
    if (uid == current.user.id) {
      throw const SessionException('No se puede sacar al propietario.');
    }
    await _access.removeMember(companyId: current.company.id, uid: uid);
    await loadTeam();
  }

  Future<void> joinWithInviteCode(String code) {
    return _run(() async {
      final identity = _identity;
      if (identity == null) {
        throw const SessionException('Ingresá para aceptar la invitación.');
      }
      if (isSignedIn) {
        throw const SessionException('Ya pertenecés a una empresa.');
      }
      await _acceptInviteByCode(identity, code);
      await _loadProfile(identity);
    });
  }

  Future<void> createOwnedCompany(String companyName) {
    return _run(() async {
      final identity = _identity;
      if (identity == null) {
        throw const SessionException('Ingresá para continuar.');
      }
      if (isSignedIn) {
        throw const SessionException('Ya pertenecés a una empresa.');
      }
      final name = companyName.trim();
      if (name.isEmpty) {
        throw const SessionException('Ingresá el nombre de la empresa.');
      }
      await _access.createOwnerCompany(
        uid: identity.uid,
        email: identity.email,
        displayName: _displayNameFor(identity),
        companyName: name,
      );
      await _loadProfile(identity);
    });
  }

  Future<void> setCompanyRubro(CompanyRubro rubro) async {
    final current = _requireOwnerOrAdmin();
    await _access.updateCompanyRubro(current.company.id, rubro);
    _company = current.company.copyWith(rubro: rubro);
    await _persistSessionCache();
    notifyListeners();
  }

  Future<void> setCompanyPhone(String? phone) async {
    final current = _requireOwnerOrAdmin();
    final next = blankToNull(phone);
    await _access.updateCompanyPhone(current.company.id, next);
    _company = current.company.copyWith(phone: next);
    await _persistSessionCache();
    notifyListeners();
  }

  Future<void> setCompanyName(String name) async {
    final current = _requireCompanyOwner();
    final next = name.trim();
    if (next.isEmpty) {
      throw const SessionException('Ingresá el nombre de la empresa.');
    }
    if (next.length > maxCompanyNameLength) {
      throw const SessionException(
        'El nombre de la empresa es demasiado largo.',
      );
    }
    await _access.updateCompanyName(current.company.id, next);
    _company = current.company.copyWith(name: next);
    await _persistSessionCache();
    notifyListeners();
  }

  Future<void> setCompanyLogo(String? logoUrl) async {
    final current = _requireCompanyOwner();
    final next = blankToNull(logoUrl);
    await _access.updateCompanyLogo(current.company.id, next);
    _company = current.company.copyWith(logoUrl: next);
    await _persistSessionCache();
    notifyListeners();
  }

  Future<void> setCompanySocials({
    String? instagram,
    String? tiktok,
    String? facebook,
  }) async {
    final current = _requireCompanyOwner();
    final nextInstagram = _normalizedSocial(instagram);
    final nextTiktok = _normalizedSocial(tiktok);
    final nextFacebook = _normalizedSocial(facebook);
    await _access.updateCompanySocials(
      current.company.id,
      instagram: nextInstagram,
      tiktok: nextTiktok,
      facebook: nextFacebook,
    );
    _company = current.company.copyWith(
      instagram: nextInstagram,
      tiktok: nextTiktok,
      facebook: nextFacebook,
    );
    await _persistSessionCache();
    notifyListeners();
  }

  Future<void> loadTeam() async {
    final company = _company;
    if (company == null) return;
    if (!canViewTeam) {
      _members = const [];
      _invitations = const [];
      notifyListeners();
      return;
    }
    try {
      final membersFuture = _access.listMembers(company.id);
      final invitationsFuture = isOwner
          ? _access.listInvitations(company.id)
          : Future<List<Invitation>>.value(const []);
      _members = await membersFuture;
      _invitations = await invitationsFuture;
    } on SessionException {
      rethrow;
    } catch (_) {
      throw const SessionException('No se pudo cargar el equipo.');
    }
    notifyListeners();
  }

  String shareUrl(String path) {
    if (kIsWeb) {
      return '${Uri.base.origin}$path';
    }
    return path;
  }

  String inviteShareUrl(Invitation invitation) => shareUrl(invitation.path);

  String? catalogShareUrl() {
    final id = company?.id;
    if (id == null || id.isEmpty) return null;
    return shareUrl('/catalogo/$id');
  }

  @override
  void dispose() {
    _loadGen++;
    _readyTimeout?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(AuthIdentity? identity) async {
    _identity = identity;
    if (_busy) {
      if (identity == null) _clearSession();
      return;
    }
    if (_hasLoadedProfile(identity) && _networkProfileLoaded) {
      _markReady();
      notifyListeners();
      return;
    }
    final gen = ++_loadGen;
    if (identity == null) {
      _clearSession();
      _markReady();
      notifyListeners();
      return;
    }
    if (!_hasLoadedProfile(identity)) {
      _hydrateFromCache(identity);
      if (gen != _loadGen) return;
      if (_hasLoadedProfile(identity)) {
        _markReady();
        notifyListeners();
      }
    }
    try {
      await _auth.waitForToken();
      await _loadProfile(identity);
      _networkProfileLoaded = _hasLoadedProfile(identity);
    } catch (_) {
      if (!_hasLoadedProfile(identity)) {
        _user = null;
        _company = null;
        _membership = null;
      }
    }
    if (gen != _loadGen) return;
    _markReady();
    notifyListeners();
  }

  Future<void> _finishAuthenticated({
    required AuthIdentity identity,
    required String displayName,
    String? companyName,
    String? inviteCompanyId,
    String? inviteId,
    String? inviteCode,
  }) async {
    _identity = identity;
    final user = await _access.getUser(identity.uid);
    if (user != null && user.companyId.isNotEmpty) {
      await _loadProfile(identity);
      _markReady();
      notifyListeners();
      return;
    }

    final code = normalizeInviteCode(inviteCode ?? '');
    final targeted =
        inviteCompanyId != null &&
        inviteCompanyId.isNotEmpty &&
        inviteId != null &&
        inviteId.isNotEmpty;
    final name = companyName?.trim() ?? '';
    final wantsJoin = code.isNotEmpty || targeted || name.isNotEmpty;

    if (user != null && !wantsJoin) {
      await _loadProfile(identity);
      _markReady();
      notifyListeners();
      return;
    }

    if (code.isNotEmpty) {
      await _acceptInviteByCode(identity, code, displayName: displayName);
    } else if (targeted) {
      await _access.acceptInvitation(
        uid: identity.uid,
        email: identity.email,
        displayName: displayName,
        companyId: inviteCompanyId,
        invitationId: inviteId,
      );
    } else {
      final pending = await _access.findPendingInvitationByEmail(
        identity.email,
      );
      if (pending != null) {
        await _access.acceptInvitation(
          uid: identity.uid,
          email: identity.email,
          displayName: displayName,
          companyId: pending.companyId,
          invitationId: pending.id,
        );
      } else {
        if (name.isEmpty) {
          throw const SessionException('Ingresá el nombre de la empresa.');
        }
        await _access.createOwnerCompany(
          uid: identity.uid,
          email: identity.email,
          displayName: displayName,
          companyName: name,
        );
      }
    }
    await _loadProfile(identity);
    _markReady();
    notifyListeners();
  }

  Future<void> _acceptInviteByCode(
    AuthIdentity identity,
    String code, {
    String? displayName,
  }) async {
    final pending = await _access.findPendingInvitationByCode(
      identity.email,
      code,
    );
    if (pending == null) {
      throw const SessionException('El código no es válido.');
    }
    await _access.acceptInvitation(
      uid: identity.uid,
      email: identity.email,
      displayName: (displayName == null || displayName.trim().isEmpty)
          ? _displayNameFor(identity)
          : displayName.trim(),
      companyId: pending.companyId,
      invitationId: pending.id,
    );
  }

  Future<void> _loadProfile(AuthIdentity identity) async {
    _identity = identity;
    var user = await _access.getUser(identity.uid);
    if (user == null) {
      final owned = await _access.findCompanyByOwner(identity.uid);
      if (owned != null) {
        await _access.ensureOwnerProfile(
          uid: identity.uid,
          email: identity.email,
          displayName: _displayNameFor(identity),
          company: owned,
        );
        user = await _access.getUser(identity.uid);
      }
    }
    if (user == null) {
      _user = null;
      _company = null;
      _membership = null;
      _members = const [];
      _invitations = const [];
      await cache?.clear(identity.uid);
      return;
    }
    if (user.companyId.isEmpty) {
      _user = user;
      _company = null;
      _membership = null;
      _members = const [];
      _invitations = const [];
      await cache?.clear(identity.uid);
      return;
    }
    final membershipFuture = _access.getMembership(user.companyId, user.id);
    final companyFuture = _access.getCompany(user.companyId);
    final membership = await membershipFuture;
    final company = await companyFuture;
    if (membership == null) {
      try {
        await _access.clearOrphanCompany(user.id);
      } catch (_) {}
      final detached = await _access.getUser(user.id);
      _user = AppUser(
        id: user.id,
        email: detached?.email ?? user.email,
        displayName: detached?.displayName ?? user.displayName,
        companyId: '',
        createdAt: detached?.createdAt ?? user.createdAt,
      );
      _company = null;
      _membership = null;
      _members = const [];
      _invitations = const [];
      await cache?.clear(identity.uid);
      return;
    }
    if (company == null) {
      throw const SessionException(
        'No se pudo cargar el contexto de la empresa.',
      );
    }
    _user = user;
    _company = company;
    _membership = membership;
    await _persistSessionCache();
  }

  void _hydrateFromCache(AuthIdentity identity) {
    final snapshot = cache?.read(identity.uid);
    if (snapshot == null || snapshot.user.id != identity.uid) return;
    _user = snapshot.user;
    _company = snapshot.company;
    _membership = snapshot.membership;
  }

  Future<void> _persistSessionCache() async {
    final user = _user;
    final company = _company;
    final membership = _membership;
    if (user == null || company == null || membership == null) return;
    try {
      await cache?.write(
        SessionSnapshot(user: user, company: company, membership: membership),
      );
    } catch (error) {
      debugPrint('Session cache write failed: $error');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } on SessionException {
      rethrow;
    } catch (_) {
      throw const SessionException('No se pudo completar el acceso.');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  bool _hasLoadedProfile(AuthIdentity? identity) {
    return identity != null &&
        _user?.id == identity.uid &&
        _company != null &&
        _membership != null;
  }

  void _clearSession() {
    _identity = null;
    _user = null;
    _company = null;
    _membership = null;
    _members = const [];
    _invitations = const [];
    _networkProfileLoaded = false;
  }

  void _markReady() {
    _ready = true;
    _readyTimeout?.cancel();
    final pending = _readyCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  String _displayNameFor(AuthIdentity identity) {
    final name = _user?.displayName.trim();
    if (name != null && name.isNotEmpty) return name;
    return identity.email;
  }

  ({AppUser user, Company company, Membership membership}) _requireOwner() {
    return _requireCompanyOwner(
      'Solo el propietario puede gestionar el equipo.',
    );
  }

  ({AppUser user, Company company, Membership membership})
  _requireCompanyOwner([
    String message = 'Solo el propietario puede cambiar el perfil del negocio.',
  ]) {
    final user = _user;
    final company = _company;
    final membership = _membership;
    if (user == null || company == null || membership == null) {
      throw const SessionException('Ingresá para continuar.');
    }
    if (membership.role != CompanyRole.owner) {
      throw SessionException(message);
    }
    return (user: user, company: company, membership: membership);
  }

  String? _normalizedSocial(String? value) {
    final next = blankToNull(value);
    if (next == null) return null;
    if (next.length > maxCompanySocialLength) {
      throw const SessionException(
        'Ese enlace de red social es demasiado largo.',
      );
    }
    return next;
  }

  ({AppUser user, Company company, Membership membership})
  _requireOwnerOrAdmin() {
    final user = _user;
    final company = _company;
    final membership = _membership;
    if (user == null || company == null || membership == null) {
      throw const SessionException('Ingresá para continuar.');
    }
    if (!membership.role.canEditCompanySettings) {
      throw const SessionException(
        'Solo el propietario o un administrador puede cambiar la configuración.',
      );
    }
    return (user: user, company: company, membership: membership);
  }
}
