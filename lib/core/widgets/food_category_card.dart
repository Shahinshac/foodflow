import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FoodCategoryItem {
  final String id;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String? emoji;

  const FoodCategoryItem({
    required this.id,
    required this.label,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.emoji,
  });
}

class FoodCategoryCard extends StatelessWidget {
  final FoodCategoryItem category;
  final bool isSelected;
  final VoidCallback onTap;

  const FoodCategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.darkAction
                : (isDark ? AppColors.surfaceDark : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.darkAction
                  : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: category.emoji != null
                      ? Text(
                          category.emoji!,
                          style: const TextStyle(fontSize: 22),
                        )
                      : Icon(
                          category.icon,
                          size: 22,
                          color: isSelected ? Colors.white : category.iconColor,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF374151)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
