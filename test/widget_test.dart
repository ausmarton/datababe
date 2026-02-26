import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:datababe/providers/auth_provider.dart';
import 'package:datababe/screens/auth/login_screen.dart';

void main() {
  testWidgets('Login screen shows app name and sign-in button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DataBabe'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
