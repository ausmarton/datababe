import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

/// Current user as [AppUser]. Decouples screens from firebase_auth.User.
final currentUserProvider = Provider<AppUser?>((ref) {
  final firebaseUser = ref.watch(authStateProvider).valueOrNull;
  return firebaseUser != null ? AppUser.fromFirebaseUser(firebaseUser) : null;
});
