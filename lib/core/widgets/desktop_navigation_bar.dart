import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/cart/presentation/cart_providers.dart';
import 'pwa_install_guide_dialog.dart';

class DesktopNavigationBar extends ConsumerWidget {
  final VoidCallback? onOffersTap;
  final VoidCallback? onCategoriesTap;

  const DesktopNavigationBar({
    super.key,
    this.onOffersTap,
    this.onCategoriesTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final cartAsync = ref.watch(cartSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cartCount = cartAsync.maybeWhen(
      data: (cart) => cart.items.fold<int>(0, (sum, item) => sum + item.quantity),
      orElse: () => 0,
    );

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Row(
            children: [
              // Brand Logo
              InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'FoodFlow',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Navigation Links (Flexible to never overflow)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavLink(
                        label: 'Home',
                        isActive: true,
                        onTap: () => context.go('/'),
                      ),
                      _NavLink(
                        label: 'Restaurants',
                        isActive: false,
                        onTap: () => context.go('/'),
                      ),
                      _NavLink(
                        label: 'Categories',
                        isActive: false,
                        onTap: onCategoriesTap ?? () => context.go('/'),
                      ),
                      _NavLink(
                        label: 'Offers',
                        isActive: false,
                        onTap: onOffersTap ?? () => context.go('/'),
                      ),
                      _NavLink(
                        label: 'Orders',
                        isActive: false,
                        onTap: () {
                          if (authState.isAuthenticated) {
                            context.push('/orders');
                          } else {
                            context.push('/login');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Right Actions Container
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location Selector Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Kochi, Kerala',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Install App Button
                  Tooltip(
                    message: 'Install FoodFlow App (iOS / Windows PWA)',
                    child: OutlinedButton.icon(
                      onPressed: () => PwaInstallGuideDialog.show(context),
                      icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.primary),
                      label: Text(
                        'Install App',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Cart Button with Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: () {
                          if (authState.isAuthenticated) {
                            context.push('/cart');
                          } else {
                            context.push('/login');
                          }
                        },
                      ),
                      if (cartCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '$cartCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Auth Actions
                  if (!authState.isAuthenticated) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkAction,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(96, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      onPressed: () => context.push('/login'),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                        minimumSize: const Size(96, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => context.push('/register'),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ] else ...[
                // User Avatar / Role Portal Button
                PopupMenuButton<String>(
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'portal') {
                      final role = user?.role;
                      if (role == 'ADMIN') context.go('/admin');
                      if (role == 'RESTAURANT_OWNER') context.go('/owner');
                      if (role == 'DELIVERY_PARTNER') context.go('/delivery');
                    } else if (val == 'orders') {
                      context.push('/orders');
                    } else if (val == 'logout') {
                      ref.read(authProvider.notifier).logout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'FoodFlow User',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                    if (user?.role != 'CUSTOMER')
                      PopupMenuItem(
                        value: 'portal',
                        child: Row(
                          children: [
                            const Icon(Icons.dashboard_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('${user?.role} Portal', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'orders',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('My Orders'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user?.fullName ?? 'Account',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  ),
);
}
}

class _NavLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 4),
                Container(
                  width: 16,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
