import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:foodflow/core/theme/app_colors.dart';
import 'package:foodflow/core/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('AppTheme defines consistent primary branding and color scheme', (WidgetTester tester) async {
    expect(AppColors.primary, const Color(0xFFFF521B));
    expect(AppColors.primaryDark, const Color(0xFFE03E0B));
    expect(AppColors.primaryLight, const Color(0xFFFF7A4D));
    expect(AppTheme.lightTheme.colorScheme.primary, AppColors.primary);
    expect(AppTheme.darkTheme.colorScheme.primary, AppColors.primary);
    expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.backgroundLight);
    expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppColors.backgroundDark);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: Text('FoodFlow', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );

    expect(find.text('FoodFlow'), findsOneWidget);
  });
}
