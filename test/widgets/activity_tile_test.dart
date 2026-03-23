import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/widgets/activity_tile.dart';

ActivityModel _activity({
  required String type,
  double? volumeMl,
  String? feedType,
  int? rightBreastMinutes,
  int? leftBreastMinutes,
  int? durationMinutes,
  String? contents,
  String? contentSize,
  String? pooColour,
  String? medicationName,
  String? dose,
  String? foodDescription,
  List<String>? ingredientNames,
  List<String>? allergenNames,
  String? reaction,
  double? weightKg,
  double? lengthCm,
  double? headCircumferenceCm,
  double? tempCelsius,
}) {
  final now = DateTime(2026, 3, 6, 14, 30);
  return ActivityModel(
    id: 'a1',
    childId: 'c1',
    type: type,
    startTime: now,
    createdAt: now,
    modifiedAt: now,
    volumeMl: volumeMl,
    feedType: feedType,
    rightBreastMinutes: rightBreastMinutes,
    leftBreastMinutes: leftBreastMinutes,
    durationMinutes: durationMinutes,
    contents: contents,
    contentSize: contentSize,
    pooColour: pooColour,
    medicationName: medicationName,
    dose: dose,
    foodDescription: foodDescription,
    ingredientNames: ingredientNames,
    allergenNames: allergenNames,
    reaction: reaction,
    weightKg: weightKg,
    lengthCm: lengthCm,
    headCircumferenceCm: headCircumferenceCm,
    tempCelsius: tempCelsius,
  );
}

Widget _buildTile(ActivityModel activity, {VoidCallback? onDelete, VoidCallback? onCopy}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ListView(
            children: [
              ActivityTile(
                activity: activity,
                onDelete: onDelete,
                onCopy: onCopy,
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/log/:type',
        builder: (_, _) => const Scaffold(body: Text('Log')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('ActivityTile', () {
    testWidgets('renders bottle feed with volume', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'feedBottle', volumeMl: 120, feedType: 'formula'),
      ));
      expect(find.text('Bottle Feed'), findsOneWidget);
      expect(find.textContaining('120ml'), findsOneWidget);
      expect(find.textContaining('formula'), findsOneWidget);
    });

    testWidgets('renders breast feed with durations', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'feedBreast', rightBreastMinutes: 10, leftBreastMinutes: 8),
      ));
      expect(find.text('Breast Feed'), findsOneWidget);
      expect(find.textContaining('R: 10min'), findsOneWidget);
      expect(find.textContaining('L: 8min'), findsOneWidget);
    });

    testWidgets('renders diaper with contents and color', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'diaper', contents: 'poo', contentSize: 'large', pooColour: 'brown'),
      ));
      expect(find.text('Diaper'), findsOneWidget);
      expect(find.textContaining('poo'), findsOneWidget);
      expect(find.textContaining('brown'), findsOneWidget);
    });

    testWidgets('renders medication with name and dose', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'meds', medicationName: 'Vitamin D', dose: '5ml'),
      ));
      expect(find.text('Medication'), findsOneWidget);
      expect(find.textContaining('Vitamin D'), findsOneWidget);
      expect(find.textContaining('5ml'), findsOneWidget);
    });

    testWidgets('renders solids with food description', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'solids', foodDescription: 'scrambled eggs', ingredientNames: ['egg', 'milk']),
      ));
      expect(find.text('Solids'), findsOneWidget);
      expect(find.textContaining('scrambled eggs'), findsOneWidget);
      expect(find.textContaining('2 ingredients'), findsOneWidget);
    });

    testWidgets('renders growth with measurements', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'growth', weightKg: 8.5, lengthCm: 72.0),
      ));
      expect(find.text('Growth'), findsOneWidget);
      expect(find.textContaining('8.5kg'), findsOneWidget);
      expect(find.textContaining('72.0cm'), findsOneWidget);
    });

    testWidgets('renders temperature', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'temperature', tempCelsius: 37.2),
      ));
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.textContaining('37.2°C'), findsOneWidget);
    });

    testWidgets('renders tummy time with duration', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'tummyTime', durationMinutes: 15),
      ));
      expect(find.text('Tummy Time'), findsOneWidget);
      expect(find.textContaining('15'), findsOneWidget);
    });

    testWidgets('renders potty with contents', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'potty', contents: 'pee', contentSize: 'small'),
      ));
      expect(find.text('Potty'), findsOneWidget);
      expect(find.textContaining('pee'), findsOneWidget);
    });

    testWidgets('renders pump with volume', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'pump', volumeMl: 80, durationMinutes: 20),
      ));
      expect(find.text('Pump'), findsOneWidget);
      expect(find.textContaining('80ml'), findsOneWidget);
    });

    testWidgets('renders sleep with duration', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'sleep', durationMinutes: 120),
      ));
      expect(find.text('Sleep'), findsOneWidget);
    });

    testWidgets('shows time in trailing', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'feedBottle', volumeMl: 100),
      ));
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('renders icon via CircleAvatar', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'feedBottle'),
      ));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('handles null optional fields gracefully', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'feedBottle'),
      ));
      expect(find.text('Bottle Feed'), findsOneWidget);
    });

    testWidgets('wraps in Dismissible when onDelete provided', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'diaper'),
        onDelete: () {},
      ));
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('no Dismissible when onDelete is null', (tester) async {
      await tester.pumpWidget(_buildTile(
        _activity(type: 'diaper'),
      ));
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('long press shows context menu when onCopy provided', (tester) async {
      bool copied = false;
      await tester.pumpWidget(_buildTile(
        _activity(type: 'feedBottle'),
        onCopy: () => copied = true,
      ));
      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Copy as new'), findsOneWidget);

      await tester.tap(find.text('Copy as new'));
      await tester.pumpAndSettle();
      expect(copied, isTrue);
    });
  });
}
