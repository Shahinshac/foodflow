import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../features/restaurant/presentation/restaurant_providers.dart';

class BudgetFoodFinderCard extends ConsumerWidget {
  final bool isHorizontal;

  const BudgetFoodFinderCard({
    super.key,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBudget = ref.watch(filterMaxPricePaiseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final budgetTiers = [
      {'label': '₹50', 'value': 5000},
      {'label': '₹100', 'value': 10000},
      {'label': '₹150', 'value': 15000},
      {'label': '₹200', 'value': 20000},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.veg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.veg,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Food Finder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Find tasty food within your budget',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedBudget != null)
                InkWell(
                  onTap: () => ref.read(filterMaxPricePaiseProvider.notifier).state = null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: budgetTiers.map((tier) {
              final val = tier['value'] as int;
              final isSel = selectedBudget == val;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () {
                      ref.read(filterMaxPricePaiseProvider.notifier).state = isSel ? null : val;
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.darkAction
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppColors.darkAction
                              : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            tier['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? Colors.white : const Color(0xFF1F2937)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'and below',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? Colors.white70
                                  : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
