import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/desktop_navigation_bar.dart';
import '../../../core/widgets/food_category_card.dart';
import '../../../core/widgets/budget_food_finder.dart';
import '../../../core/widgets/special_offers_banner.dart';
import '../../auth/presentation/profile_screen.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../order/presentation/orders_list_screen.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../../notifications/presentation/notification_sheet.dart';
import 'restaurant_providers.dart';
import 'favorites_screen.dart';
import '../domain/models.dart';

final homeNavIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(homeNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          // On desktop, render dedicated full-width desktop view with top navbar
          return const _DesktopHomeView();
        }

        // On mobile/tablet, render bottom-nav experience
        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          body: IndexedStack(
            index: navIndex,
            children: const [
              _MobileHomeExploreView(),
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
      },
    );
  }
}

// ==========================================
// 1. DESKTOP HOME VIEW (Reference Image 1)
// ==========================================
class _DesktopHomeView extends ConsumerStatefulWidget {
  const _DesktopHomeView();

  @override
  ConsumerState<_DesktopHomeView> createState() => _DesktopHomeViewState();
}

class _DesktopHomeViewState extends ConsumerState<_DesktopHomeView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<FoodCategoryItem> _categories = const [
    FoodCategoryItem(id: 'all', label: 'All', icon: Icons.restaurant_rounded, emoji: '🍽️'),
    FoodCategoryItem(id: 'Biryani', label: 'Biryani', icon: Icons.rice_bowl_rounded, emoji: '🍚'),
    FoodCategoryItem(id: 'Pizza', label: 'Pizza', icon: Icons.local_pizza_rounded, emoji: '🍕'),
    FoodCategoryItem(id: 'Burger', label: 'Burger', icon: Icons.lunch_dining_rounded, emoji: '🍔'),
    FoodCategoryItem(id: 'Chicken', label: 'Chicken', icon: Icons.kebab_dining_rounded, emoji: '🍗'),
    FoodCategoryItem(id: 'South Indian', label: 'South Indian', icon: Icons.breakfast_dining_rounded, emoji: '🥞'),
    FoodCategoryItem(id: 'Chinese', label: 'Chinese', icon: Icons.ramen_dining_rounded, emoji: '🍜'),
    FoodCategoryItem(id: 'Desserts', label: 'Desserts', icon: Icons.cake_rounded, emoji: '🍰'),
    FoodCategoryItem(id: 'Beverages', label: 'Beverages', icon: Icons.local_bar_rounded, emoji: '🥤'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToRestaurants() {
    _scrollController.animateTo(
      450,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantsListProvider);
    final selectedCuisine = ref.watch(selectedCuisineProvider);
    final isVegOnly = ref.watch(filterVegOnlyProvider);
    final minRating = ref.watch(filterMinRatingProvider);
    final maxDeliveryTime = ref.watch(filterMaxDeliveryTimeProvider);
    final hasOffers = ref.watch(filterHasOffersProvider);
    final selectedBudget = ref.watch(filterMaxPricePaiseProvider);
    final publicCouponsAsync = ref.watch(publicCouponsProvider);
    final topCoupon = publicCouponsAsync.asData?.value.firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFBF9F5),
      body: Column(
        children: [
          // Top Navigation Bar
          DesktopNavigationBar(
            onOffersTap: () {
              ref.read(filterHasOffersProvider.notifier).state = true;
              _scrollToRestaurants();
            },
            onCategoriesTap: _scrollToRestaurants,
          ),

          // Main Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HERO SECTION (Side-by-side Hero Banner + Special Offers & Budget Finder)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Hero Banner
                            Expanded(
                              flex: 62,
                              child: Container(
                                height: 330,
                                padding: const EdgeInsets.fromLTRB(36, 24, 28, 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left Text Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: const [
                                              Text(
                                                'GOOD FOOD',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Text('•', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                              SizedBox(width: 6),
                                              Text(
                                                'BETTER DAYS',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF6B7280),
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          RichText(
                                            text: const TextSpan(
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -1.0,
                                                height: 1.15,
                                                color: Color(0xFF111827),
                                              ),
                                              children: [
                                                TextSpan(text: 'Delicious Food\n'),
                                                TextSpan(
                                                  text: 'Delivered to You',
                                                  style: TextStyle(color: AppColors.primary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Discover amazing restaurants, great offers and your favourite food, all in one place.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6B7280),
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.darkAction,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(170, 44),
                                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                              elevation: 0,
                                            ),
                                            onPressed: _scrollToRestaurants,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Text(
                                                  'Explore Restaurants',
                                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_forward_rounded, size: 15),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // Dish Image on the Right
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: CachedNetworkImage(
                                            imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&q=80',
                                            fit: BoxFit.cover,
                                            width: 230,
                                            height: 250,
                                            placeholder: (_, __) => Container(width: 230, height: 250, color: Colors.grey.shade100),
                                            errorWidget: (_, __, ___) => Container(
                                              width: 230,
                                              height: 250,
                                              color: Colors.grey.shade100,
                                              child: const Icon(Icons.restaurant, size: 60, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        if (topCoupon != null)
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary.withValues(alpha: 0.4),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    'OFFER',
                                                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                                  ),
                                                  Text(
                                                    topCoupon.discountType == 'PERCENTAGE'
                                                        ? '${topCoupon.discountValue}% OFF'
                                                        : topCoupon.code,
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 24),

                            // Right Side Columns (Special Offers + Budget Finder)
                            Expanded(
                              flex: 38,
                              child: Column(
                                children: [
                                  SpecialOffersCard(
                                    coupon: topCoupon,
                                    onOrderNowTap: () {
                                      ref.read(filterHasOffersProvider.notifier).state = true;
                                      _scrollToRestaurants();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const BudgetFoodFinderCard(),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // SEARCH & CATEGORY BAR
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Search input row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) {
                                        ref.read(searchQueryProvider.notifier).state = val;
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Search for restaurants, food or cuisine...',
                                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                                        suffixIcon: ref.watch(searchQueryProvider).isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear_rounded, size: 18),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  ref.read(searchQueryProvider.notifier).state = '';
                                                },
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF9FAFB),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.darkAction,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(120, 48),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      ref.read(searchQueryProvider.notifier).state = _searchController.text.trim();
                                    },
                                    child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Food Categories Row
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: _categories.map((cat) {
                                    final isSelected = (cat.id == 'all' && selectedCuisine == null) ||
                                        (selectedCuisine == cat.id);

                                    return FoodCategoryCard(
                                      category: cat,
                                      isSelected: isSelected,
                                      onTap: () {
                                        if (cat.id == 'all') {
                                          ref.read(selectedCuisineProvider.notifier).state = null;
                                        } else {
                                          ref.read(selectedCuisineProvider.notifier).state =
                                              isSelected ? null : cat.id;
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        // POPULAR RESTAURANTS SECTION
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Popular Restaurants',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            // Quick Filter Chips Row
                            Row(
                              children: [
                                _DesktopFilterChip(
                                  label: 'Pure Veg',
                                  isSelected: isVegOnly,
                                  onTap: () => ref.read(filterVegOnlyProvider.notifier).state = !isVegOnly,
                                ),
                                _DesktopFilterChip(
                                  label: '4.5+ Rated',
                                  isSelected: minRating == 4.5,
                                  onTap: () => ref.read(filterMinRatingProvider.notifier).state =
                                      (minRating == 4.5 ? null : 4.5),
                                ),
                                _DesktopFilterChip(
                                  label: 'Offers',
                                  isSelected: hasOffers,
                                  onTap: () => ref.read(filterHasOffersProvider.notifier).state = !hasOffers,
                                ),
                                _DesktopFilterChip(
                                  label: 'Fast Delivery',
                                  isSelected: maxDeliveryTime == 30,
                                  onTap: () => ref.read(filterMaxDeliveryTimeProvider.notifier).state =
                                      (maxDeliveryTime == 30 ? null : 30),
                                ),
                                if (selectedBudget != null)
                                  _DesktopFilterChip(
                                    label: 'Under ₹${selectedBudget ~/ 100}',
                                    isSelected: true,
                                    onTap: () => ref.read(filterMaxPricePaiseProvider.notifier).state = null,
                                  ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Restaurants Grid
                        restaurantsAsync.when(
                          data: (restaurants) {
                            if (restaurants.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 60),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search_off_rounded, size: 60, color: Color(0xFF9CA3AF)),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No restaurants found',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Try modifying or resetting your search filters.',
                                      style: TextStyle(color: Color(0xFF6B7280)),
                                    ),
                                    const SizedBox(height: 20),
                                    OutlinedButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(searchQueryProvider.notifier).state = '';
                                        ref.read(selectedCuisineProvider.notifier).state = null;
                                        ref.read(filterVegOnlyProvider.notifier).state = false;
                                        ref.read(filterMinRatingProvider.notifier).state = null;
                                        ref.read(filterMaxDeliveryTimeProvider.notifier).state = null;
                                        ref.read(filterHasOffersProvider.notifier).state = false;
                                        ref.read(filterMaxPricePaiseProvider.notifier).state = null;
                                      },
                                      child: const Text('Reset All Filters'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, gridConstraints) {
                                // 4 columns on desktop, 3 columns on medium
                                final crossAxisCount = gridConstraints.maxWidth >= 1100 ? 4 : 3;

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: 0.88,
                                  ),
                                  itemCount: restaurants.length,
                                  itemBuilder: (context, index) {
                                    final restaurant = restaurants[index];
                                    return _DesktopRestaurantCard(restaurant: restaurant);
                                  },
                                );
                              },
                            );
                          },
                          loading: () => GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.88,
                            ),
                            itemCount: 4,
                            itemBuilder: (_, __) => Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.white,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          error: (err, _) => CustomErrorView(
                            message: 'Failed to load restaurants: ${ApiClient.formatError(err)}',
                            onRetry: () => ref.invalidate(restaurantsListProvider),
                          ),
                        ),

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkAction : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.darkAction : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopRestaurantCard extends ConsumerWidget {
  final RestaurantModel restaurant;

  const _DesktopRestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedImage = AppConstants.resolveImageUrl(restaurant.imageUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
              // Photo with Discount Ribbon & Favorite Heart
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    child: CachedNetworkImage(
                      imageUrl: resolvedImage,
                      height: 155,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade100),
                      errorWidget: (_, __, ___) => Container(
                        height: 155,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.restaurant, color: Colors.grey, size: 36),
                      ),
                    ),
                  ),

                  // Discount / Offer Ribbon
                  if (restaurant.deliveryFeePaise == 0 || restaurant.activeOffersCount > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          restaurant.deliveryFeePaise == 0 ? 'Free Delivery' : 'Offers Available',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                  // Heart Favorite Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(restaurant.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          restaurant.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: restaurant.isFavorite ? AppColors.error : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      restaurant.cuisine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Rating
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.veg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                '${restaurant.rating}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delivery Time
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 3),
                            Text(
                              restaurant.estimatedDeliveryTime,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Distance / Prep
                        Text(
                          '1.4 km',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. MOBILE HOME VIEW (Reference Image 2)
// ==========================================
class _MobileHomeExploreView extends ConsumerStatefulWidget {
  const _MobileHomeExploreView();

  @override
  ConsumerState<_MobileHomeExploreView> createState() => _MobileHomeExploreViewState();
}

class _MobileHomeExploreViewState extends ConsumerState<_MobileHomeExploreView> {
  final List<FoodCategoryItem> _categories = const [
    FoodCategoryItem(id: 'all', label: 'All', icon: Icons.restaurant_rounded, emoji: '🍽️'),
    FoodCategoryItem(id: 'Biryani', label: 'Biryani', icon: Icons.rice_bowl_rounded, emoji: '🍚'),
    FoodCategoryItem(id: 'Pizza', label: 'Pizza', icon: Icons.local_pizza_rounded, emoji: '🍕'),
    FoodCategoryItem(id: 'Burger', label: 'Burger', icon: Icons.lunch_dining_rounded, emoji: '🍔'),
    FoodCategoryItem(id: 'Chicken', label: 'Chicken', icon: Icons.kebab_dining_rounded, emoji: '🍗'),
    FoodCategoryItem(id: 'South Indian', label: 'South Indian', icon: Icons.breakfast_dining_rounded, emoji: '🥞'),
    FoodCategoryItem(id: 'Chinese', label: 'Chinese', icon: Icons.ramen_dining_rounded, emoji: '🍜'),
  ];

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantsListProvider);
    final cartAsync = ref.watch(cartSummaryProvider);
    final selectedCuisine = ref.watch(selectedCuisineProvider);
    final unreadNotifsAsync = ref.watch(unreadNotificationsCountProvider);
    final addressesAsync = ref.watch(userAddressesProvider);
    final publicCouponsAsync = ref.watch(publicCouponsProvider);
    final topCoupon = publicCouponsAsync.asData?.value.firstOrNull;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String addressLabel = 'Kochi, Kerala';
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
        ),
        actions: [
          // Notification Bell
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
          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                decoration: InputDecoration(
                  hintText: 'Search for restaurants, food or cuisine...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
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
          ),

          // Categories Horizontal Strip
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = (cat.id == 'all' && selectedCuisine == null) ||
                        (selectedCuisine == cat.id);

                    return FoodCategoryCard(
                      category: cat,
                      isSelected: isSelected,
                      onTap: () {
                        if (cat.id == 'all') {
                          ref.read(selectedCuisineProvider.notifier).state = null;
                        } else {
                          ref.read(selectedCuisineProvider.notifier).state = isSelected ? null : cat.id;
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Special Offers Banner (Mobile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SpecialOffersCard(
                coupon: topCoupon,
                onOrderNowTap: () {
                  ref.read(filterHasOffersProvider.notifier).state = true;
                },
              ),
            ),
          ),

          // Budget Food Finder (Mobile)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: BudgetFoodFinderCard(),
            ),
          ),

          // Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'Popular Near You',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
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
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () {
                              ref.read(searchQueryProvider.notifier).state = '';
                              ref.read(selectedCuisineProvider.notifier).state = null;
                              ref.read(filterVegOnlyProvider.notifier).state = false;
                              ref.read(filterMinRatingProvider.notifier).state = null;
                              ref.read(filterMaxDeliveryTimeProvider.notifier).state = null;
                              ref.read(filterHasOffersProvider.notifier).state = false;
                              ref.read(filterMaxPricePaiseProvider.notifier).state = null;
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
                        margin: const EdgeInsets.only(bottom: 16),
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
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: resolvedImage,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(height: 160, color: Colors.grey.shade200),
                                        errorWidget: (_, __, ___) => Container(
                                          height: 160,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.restaurant, color: Colors.grey, size: 40),
                                        ),
                                      ),
                                      if (restaurant.activeOffersCount > 0)
                                        Positioned(
                                          top: 12,
                                          left: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              restaurant.deliveryFeePaise == 0 ? 'Free Delivery' : 'Offers Available',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: InkWell(
                                          onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(restaurant.id),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.4),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              restaurant.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              color: restaurant.isFavorite ? AppColors.error : Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              restaurant.name,
                                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              restaurant.cuisine,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.veg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${restaurant.rating}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
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
                  (context, index) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.white,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  childCount: 3,
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: CustomErrorView(
                message: 'Failed to load restaurants: ${ApiClient.formatError(err)}',
                onRetry: () => ref.invalidate(restaurantsListProvider),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkAction,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
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
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
          ).animate().slideY(begin: 1.0, duration: 300.ms);
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}
