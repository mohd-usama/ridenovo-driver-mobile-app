import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ridenovo_rider_mobile_app/main.dart';

void main() {
  testWidgets('App loads splash / phone login screen test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RidonovaDriverApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
