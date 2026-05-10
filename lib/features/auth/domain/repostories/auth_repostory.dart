abstract class AuthRepository {
  Future<void> login(String email, String password);

  Future<void> signUpWithUsername({
    required String name,
    required String email,
    required String password,
    required String username,
  });

  Future<void> signInWithGoogle();
  Future<void> signInWithFacebook();
  Future<void> logout();
}