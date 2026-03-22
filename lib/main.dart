import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'local/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize();
  final localDb = await openLocalDatabase();
  runApp(ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(localDb),
    ],
    child: const DataBabeApp(),
  ));
}
