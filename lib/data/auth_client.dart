class AuthIdentity {
  const AuthIdentity({required this.uid, required this.email});

  final String uid;
  final String email;
}

abstract class AuthClient {
  Stream<AuthIdentity?> get authStateChanges;

  AuthIdentity? get currentUser;

  Future<AuthIdentity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthIdentity> createUserWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> waitForToken();
}
