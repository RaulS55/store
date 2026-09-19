import 'package:firebase_auth/firebase_auth.dart';

import '../models/email.dart';
import 'auth_client.dart';
import 'session_exception.dart';

class FirebaseAuthClient implements AuthClient {
  FirebaseAuthClient({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AuthIdentity?> get authStateChanges {
    return _auth.authStateChanges().map(_mapUser);
  }

  @override
  AuthIdentity? get currentUser => _mapUser(_auth.currentUser);

  @override
  Future<AuthIdentity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizeEmail(email),
        password: password,
      );
      return _complete(credential.user);
    } on FirebaseAuthException catch (error) {
      throw mapAuthException(error);
    }
  }

  @override
  Future<AuthIdentity> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizeEmail(email),
        password: password,
      );
      return _complete(credential.user);
    } on FirebaseAuthException catch (error) {
      throw mapAuthException(error);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> waitForToken() async {
    try {
      await _auth.currentUser?.getIdToken();
    } catch (_) {}
  }

  AuthIdentity? _mapUser(User? user) {
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) return null;
    return AuthIdentity(uid: user.uid, email: email);
  }

  AuthIdentity _require(User? user) {
    final identity = _mapUser(user);
    if (identity == null) {
      throw const SessionException('No se pudo completar el acceso.');
    }
    return identity;
  }

  Future<AuthIdentity> _complete(User? user) async {
    final identity = _require(user);
    try {
      await user?.getIdToken();
    } catch (_) {}
    return identity;
  }
}

SessionException mapAuthException(FirebaseAuthException error) {
  switch (error.code) {
    case 'email-already-in-use':
      return const SessionException('Ese email ya tiene una cuenta.');
    case 'invalid-email':
      return const SessionException('El email no es válido.');
    case 'weak-password':
      return const SessionException(
        'La contraseña debe tener al menos 6 caracteres.',
      );
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return const SessionException('Email o contraseña incorrectos.');
    case 'too-many-requests':
      return const SessionException('Demasiados intentos. Probá más tarde.');
    default:
      return const SessionException('No se pudo completar el acceso.');
  }
}
