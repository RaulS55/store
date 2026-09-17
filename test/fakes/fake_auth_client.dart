import 'dart:async';

import 'package:store_app/data/auth_client.dart';
import 'package:store_app/data/session_exception.dart';
import 'package:store_app/models/email.dart';

class FakeAuthClient implements AuthClient {
  final _accounts = <String, ({String uid, String password})>{};
  final _controller = StreamController<AuthIdentity?>.broadcast();
  AuthIdentity? _current;
  var _seq = 0;
  var signInCalls = 0;

  @override
  Stream<AuthIdentity?> get authStateChanges async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthIdentity? get currentUser => _current;

  @override
  Future<AuthIdentity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final normalized = normalizeEmail(email);
    final account = _accounts[normalized];
    if (account == null || account.password != password) {
      throw const SessionException('Email o contraseña incorrectos.');
    }
    return _emit(AuthIdentity(uid: account.uid, email: normalized));
  }

  @override
  Future<AuthIdentity> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = normalizeEmail(email);
    if (_accounts.containsKey(normalized)) {
      throw const SessionException('Ese email ya tiene una cuenta.');
    }
    final uid = 'uid-${++_seq}';
    _accounts[normalized] = (uid: uid, password: password);
    return _emit(AuthIdentity(uid: uid, email: normalized));
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  AuthIdentity _emit(AuthIdentity identity) {
    _current = identity;
    _controller.add(identity);
    return identity;
  }

  void replayAuthState() {
    _controller.add(_current);
  }
}
