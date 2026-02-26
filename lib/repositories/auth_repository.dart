import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> watchAuthState();

  User? get currentUser;

  Future<User?> signInWithGoogle();

  Future<void> signOut();
}
