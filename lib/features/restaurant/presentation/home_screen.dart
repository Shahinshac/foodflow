import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/presentation/profile_screen.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../order/presentation/orders_list_screen.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../../notifications/presentation/notification_sheet.dart';
import 'restaurant_providers.dart';
import 'favorites_screen.dart';

final homeNavIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(homeNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: IndexedStack(
        index: navIndex,
        children: const [
          _HomeExploreView(),
          FavoritesScreen(),
          OrdersListScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (idx) {
          ref.read(homeNavIndexProvider.notifier).state = idx;
        },
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: AppColors.primary),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: AppColors.primary),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: 'My Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeExploreView extends ConsumerWidget {
  const _HomeExploreView();

  void _showFilterModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _FilterModalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(restaurantsListProvider);
    final cartAsync = ref.watch(cartSummaryProvider);
    final selectedCuisine = ref.watch(selectedCuisineProvider);
    final isVegOnly = ref.watch(filterVegOnlyProvider);
    final minRating = ref.watch(filterMinRatingProvider);
    final maxDeliveryTime = ref.watch(filterMaxDeliveryTimeProvider);
    final hasOffers = ref.watch(filterHasOffersProvider);
    final openNow = ref.watch(filterOpenNowProvider);
    final unreadNotifsAsync = ref.watch(unreadNotificationsCountProvider);
    final addressesAsync = ref.watch(userAddressesProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String addressLabel = 'Innovation City';
    addressesAsync.whenData((addresses) {
      if (addresses.isNotEmpty) {
        final def = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        addressLabel = '${def.label} • ${def.streetAddress}';
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DELIVERING TO',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    addressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
        actions: [
          // Notification Bell with real backend badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => NotificationSheet.show(context),
              ),
              unreadNotifsAsync.maybeWhen(
                data: (count) {
                  if (count <= 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Search & Filter Bar
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        ref.read(searchQueryProvider.notifier).state = val;
                      },
                      decoration: InputDecoration(
                        hintText: 'Search restaurants, cuisines or dishes...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                        suffixIcon: ref.watch(searchQueryProvider).isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showFilterModal(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (minRating != null || maxDeliveryTime != null || hasOffers || openNow)
                            ? AppColors.primary
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: (minRating != null || maxDeliveryTime != null || hasOffers || openNow)
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),
            ),
          ),

          // Horizontal Filter Chips Strip
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildToggleChip(
                      label: 'Pure Veg',
                      icon: Icons.eco_rounded,
                      isActive: isVegOnly,
                      onTap: () => ref.read(filterVegOnlyProvider.notifier).state = !isVegOnly,
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildToggleChip(
                      label: '4.5+ Rated',
                      icon: Icons.star_rounded,
                      isActive: minRating == 4.5,
                      onTap: () => ref.read(filterMinRatingProvider.notifier).state = (minRating == 4.5 ? null : 4.5),
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildToggleChip(
                      label: 'Offers',
                      icon: Icons.local_offer_rounded,
                      isActive: hasOffers,
                      onTap: () => ref.read(filterHasOffersProvider.notifier).state = !hasOffers,
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildToggleChip(
                      label: 'Fast Delivery',
                      icon: Icons.bolt_rounded,
                      isActive: maxDeliveryTime == 30,
                      onTap: () => ref.read(filterMaxDeliveryTimeProvider.notifier).state = (maxDeliveryTime == 30 ? null : 30),
                      theme: theme,
                      isDark: isDark,
                    ),
                    _buildFilterChip(ref, 'All Cuisines', selectedCuisine == null, theme, isDark),
                    _buildFilterChip(ref, 'North Indian', selectedCuisine == 'North Indian', theme, isDark),
                    _buildFilterChip(ref, 'Italian', selectedCuisine == 'Italian', theme, isDark),
                    _buildFilterChip(ref, 'Japanese', selectedCuisine == 'Japanese', theme, isDark),
                    _buildFilterChip(ref, 'Tandoor', selectedCuisine == 'Tandoor', theme, isDark),
                  ],
                ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.05),
              ),
            ),
          ),

          // Promotional Hero Banner Strip
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.warmHeroGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.primaryGlow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SPECIAL PROMOTION',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Get 50% OFF up to ₹100',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Use code WELCOME50 on your first order',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
          ),

          // Section Title & Active Sort
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Restaurants Near You',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  InkWell(
                    onTap: () => _showFilterModal(context, ref),
                    child: Row(
                      children: [
                        Text(
                          'Sort',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Restaurant List
          restaurantsAsync.when(
            data: (restaurants) {
              if (restaurants.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No restaurants match your filters', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            'Try resetting filters to discover more dining options',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () {
                              ref.read(searchQueryProvider.notifier).state = '';
                              ref.read(selectedCuisineProvider.notifier).state = null;
                              ref.read(filterVegOnlyProvider.notifier).state = false;
                              ref.read(filterMinRatingProvider.notifier).state = null;
                              ref.read(filterMaxDeliveryTimeProvider.notifier).state = null;
                              ref.read(filterHasOffersProvider.notifier).state = false;
                              ref.read(filterOpenNowProvider.notifier).state = false;
                            },
                            child: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final restaurant = restaurants[index];
                      final resolvedImage = AppConstants.resolveImageUrl(restaurant.imageUrl);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => context.push('/restaurant/${restaurant.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hero Image & Badges
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(22),
                                    topRight: Radius.circular(22),
                                  ),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: resolvedImage,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Shimmer.fromColors(
                                          baseColor: Colors.grey.shade200,
                                          highlightColor: Colors.white,
                                          child: Container(height: 180, color: Colors.white),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          height: 180,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.restaurant, color: Colors.grey, size: 40),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withValues(alpha: 0.3),
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.75),
                                              ],
                                              stops: const [0.0, 0.4, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Favorite Button
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: InkWell(
                                          onTap: () {
                                            ref.read(favoritesProvider.notifier).toggleFavorite(restaurant.id);
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.4),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              restaurant.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              color: restaurant.isFavorite ? AppColors.error : Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Offer Badge (if any)
                                      if (restaurant.activeOffersCount > 0)
                                        Positioned(
                                          bottom: 12,
                                          left: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.local_offer_rounded, size: 12, color: Colors.white),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${restaurant.activeOffersCount} OFFERS AVAILABLE',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Rating Badge
                                      Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.veg,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${restaurant.rating}',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        restaurant.name,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        restaurant.cuisine,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.timer_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                          const SizedBox(width: 4),
                                          Text(
                                            restaurant.estimatedDeliveryTime,
                                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.delivery_dining_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                          const SizedBox(width: 4),
                                          Text(
                                            CurrencyFormatter.formatPaise(restaurant.deliveryFeePaise),
                                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                          if (!restaurant.isOpen) ...[
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('CLOSED', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms, delay: (index * 80).ms).slideY(begin: 0.05);
                    },
                    childCount: restaurants.length,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Shimmer.fromColors(
                      baseColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      highlightColor: isDark ? Colors.white24 : Colors.white,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        height: 250,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    );
                  },
                  childCount: 3,
                ),
              ),
            ),
            error: (err, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load restaurants: $err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(restaurantsListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating Cart Summary Bar
      bottomNavigationBar: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppColors.primaryGlow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/cart'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cart.items.length} ${cart.items.length == 1 ? 'ITEM' : 'ITEMS'}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                          ),
                          Text(
                            CurrencyFormatter.formatPaise(cart.totalPaise),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          Text(
                            'View Cart',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutCubic);
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, bool isSelected, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        selectedColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        onSelected: (_) {
          if (label == 'All Cuisines') {
            ref.read(selectedCuisineProvider.notifier).state = null;
          } else {
            ref.read(selectedCuisineProvider.notifier).state = isSelected ? null : label;
          }
        },
      ),
    );
  }
}

class _FilterModalSheet extends ConsumerWidget {
  const _FilterModalSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortBy = ref.watch(sortByProvider);
    final minRating = ref.watch(filterMinRatingProvider);
    final isVeg = ref.watch(filterVegOnlyProvider);
    final openNow = ref.watch(filterOpenNowProvider);
    final hasOffers = ref.watch(filterHasOffersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sort & Filters', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  ref.read(sortByProvider.notifier).state = 'recommended';
                  ref.read(filterMinRatingProvider.notifier).state = null;
                  ref.read(filterMaxDeliveryTimeProvider.notifier).state = null;
                  ref.read(filterVegOnlyProvider.notifier).state = false;
                  ref.read(filterOpenNowProvider.notifier).state = false;
                  ref.read(filterHasOffersProvider.notifier).state = false;
                  Navigator.pop(context);
                },
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('SORT BY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _sortChip(ref, 'Recommended', 'recommended', sortBy),
              _sortChip(ref, 'Rating: High to Low', 'rating', sortBy),
              _sortChip(ref, 'Delivery Time: Fastest', 'delivery_time', sortBy),
              _sortChip(ref, 'Delivery Fee: Low to High', 'price', sortBy),
            ],
          ),
          const SizedBox(height: 20),
          const Text('FILTER BY RATING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All Ratings'),
                selected: minRating == null,
                onSelected: (_) => ref.read(filterMinRatingProvider.notifier).state = null,
              ),
              FilterChip(
                label: const Text('★ 4.0+'),
                selected: minRating == 4.0,
                onSelected: (_) => ref.read(filterMinRatingProvider.notifier).state = 4.0,
              ),
              FilterChip(
                label: const Text('★ 4.5+ Top Rated'),
                selected: minRating == 4.5,
                onSelected: (_) => ref.read(filterMinRatingProvider.notifier).state = 4.5,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('OTHER FILTERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Open Restaurants Only'),
            value: openNow,
            onChanged: (v) => ref.read(filterOpenNowProvider.notifier).state = v,
          ),
          SwitchListTile(
            title: const Text('Pure Vegetarian Food'),
            value: isVeg,
            onChanged: (v) => ref.read(filterVegOnlyProvider.notifier).state = v,
          ),
          SwitchListTile(
            title: const Text('Restaurants with Active Offers'),
            value: hasOffers,
            onChanged: (v) => ref.read(filterHasOffersProvider.notifier).state = v,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(WidgetRef ref, String label, String value, String current) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(sortByProvider.notifier).state = value;
      },
    );
  }
}
