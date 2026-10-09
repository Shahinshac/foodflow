import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodflow/core/theme/app_theme.dart';
import 'package:foodflow/main.dart';

void main() {
  testWidgets('App initializes successfully with Theme', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: FoodFlowApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FoodFlowApp), findsOneWidget);
      expect(AppTheme.lightTheme.colorScheme.primary, isNotNull);
    });
  });
}
