import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filho/app.dart';

void main() {
  testWidgets('App renders setup prompt when no child exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FilhoApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Filho'), findsOneWidget);
    expect(find.text('Add your child to get started'), findsOneWidget);
  });
}
