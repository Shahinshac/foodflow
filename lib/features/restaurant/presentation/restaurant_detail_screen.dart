import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/desktop_navigation_bar.dart';
import '../../cart/presentation/cart_providers.dart';
import 'restaurant_providers.dart';
import '../domain/models.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final int restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(restaurantDetailProvider(widget.restaurantId));
    final foodsAsync = ref.watch(restaurantFoodsProvider(widget.restaurantId));
    final cartAsync = ref.watch(cartSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return restaurantAsync.when(
          data: (restaurant) {
            final resolvedCover = AppConstants.resolveImageUrl(restaurant.imageUrl);

            return foodsAsync.when(
              data: (foods) {
                // Extract categories from dishes or default list
                final Set<String> categories = {'All Items'};
                for (final f in foods) {
                  if (f.categoryName != null && f.categoryName!.isNotEmpty) {
                    categories.add(f.categoryName!);
                  }
                }

                final filteredFoods = (_selectedCategory == null || _selectedCategory == 'All Items')
                    ? foods
                    : foods.where((f) => f.categoryName == _selectedCategory).toList();

                if (isDesktop) {
                  // DESKTOP LAYOUT (Reference Image 1)
                  return Scaffold(
                    backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFBF9F5),
                    body: Column(
                      children: [
                        const DesktopNavigationBar(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1320),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Breadcrumb Navigation
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => context.go('/'),
                                            child: Text('Home', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                          ),
                                          const Text('  >  ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          InkWell(
                                            onTap: () => context.go('/'),
                                            child: Text('Restaurants', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                          ),
                                          const Text('  >  ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          Text(
                                            restaurant.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      // Restaurant Hero Banner Card
                                      Container(
                                        height: 220,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                            // Left Restaurant Info
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(28.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      restaurant.name,
                                                      style: const TextStyle(
                                                        fontSize: 28,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: -0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      restaurant.cuisine,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey.shade600,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.veg,
                                                            borderRadius: BorderRadius.circular(6),
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
                                                        const SizedBox(width: 14),
                                                        Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade600),
                                                        const SizedBox(width: 4),
                                                        Text(restaurant.estimatedDeliveryTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                        const SizedBox(width: 14),
                                                        Icon(Icons.delivery_dining_rounded, size: 16, color: Colors.grey.shade600),
                                                        const SizedBox(width: 4),
                                                        Text(CurrencyFormatter.formatPaise(restaurant.deliveryFeePaise), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Right Cover Image
                                            ClipRRect(
                                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                                              child: CachedNetworkImage(
                                                imageUrl: resolvedCover,
                                                width: 380,
                                                height: 220,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                                errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 32),

                                      // Menu Body (Category Sidebar + Dishes Grid)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Category Sidebar
                                          Container(
                                            width: 220,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFE5E7EB)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: categories.map((cat) {
                                                final isSel = (_selectedCategory == null && cat == 'All Items') ||
                                                    (_selectedCategory == cat);

                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4.0),
                                                  child: Material(
                                                    color: isSel ? AppColors.darkAction : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(12),
                                                      onTap: () {
                                                        setState(() {
                                                          _selectedCategory = cat == 'All Items' ? null : cat;
                                                        });
                                                      },
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                cat,
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                                                  color: isSel ? Colors.white : const Color(0xFF374151),
                                                                ),
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
                                          ),

                                          const SizedBox(width: 24),

                                          // Food Items Grid
                                          Expanded(
                                            child: filteredFoods.isEmpty
                                                ? const Padding(
                                                    padding: EdgeInsets.all(40.0),
                                                    child: Center(child: Text('No dishes in this category')),
                                                  )
                                                : GridView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: 2,
                                                      crossAxisSpacing: 16,
                                                      mainAxisSpacing: 16,
                                                      childAspectRatio: 2.3,
                                                    ),
                                                    itemCount: filteredFoods.length,
                                                    itemBuilder: (context, index) {
                                                      final food = filteredFoods[index];
                                                      return _DesktopDishCard(food: food, restaurantId: widget.restaurantId);
                                                    },
                                                  ),
                                          ),
                                        ],
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

                // MOBILE LAYOUT (Reference Image 2)
                return Scaffold(
                  backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey.shade50,
                  body: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 240,
                        pinned: true,
                        backgroundColor: AppColors.darkAction,
                        iconTheme: const IconThemeData(color: Colors.white),
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => context.pop(),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          titlePadding: const EdgeInsets.only(left: 48, bottom: 16, right: 16),
                          title: Text(
                            restaurant.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2))],
                            ),
                          ),
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: resolvedCover,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey.shade300),
                                errorWidget: (_, __, ___) => const Icon(Icons.restaurant, color: Colors.grey, size: 48),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.85),
                                    ],
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Info Header
                      SliverToBoxAdapter(
                        child: Container(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.veg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text('${restaurant.rating}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(restaurant.estimatedDeliveryTime, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(width: 12),
                                  Text(CurrencyFormatter.formatPaise(restaurant.deliveryFeePaise), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(restaurant.cuisine, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),

                      // Categories Horizontal Pills
                      SliverToBoxAdapter(
                        child: Container(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: categories.map((cat) {
                                final isSel = (_selectedCategory == null && cat == 'All Items') ||
                                    (_selectedCategory == cat);

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(cat),
                                    selected: isSel,
                                    selectedColor: AppColors.darkAction,
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : Colors.black87,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedCategory = cat == 'All Items' ? null : cat;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                      // Food Items List
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final food = filteredFoods[index];
                              return _MobileDishCard(food: food, restaurantId: widget.restaurantId);
                            },
                            childCount: filteredFoods.length,
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
                                      Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => CustomErrorView(
                message: 'Failed to load menu: ${ApiClient.formatError(err)}',
                onRetry: () => ref.refresh(restaurantFoodsProvider(widget.restaurantId)),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => CustomErrorView(
            message: 'Failed to load restaurant: ${ApiClient.formatError(err)}',
            onRetry: () => ref.refresh(restaurantDetailProvider(widget.restaurantId)),
          ),
        );
      },
    );
  }
}

class _DesktopDishCard extends ConsumerWidget {
  final FoodItemModel food;
  final int restaurantId;

  const _DesktopDishCard({required this.food, required this.restaurantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedFoodImg = AppConstants.resolveImageUrl(food.imageUrl);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: resolvedFoodImg,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade100),
              errorWidget: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Icon(Icons.fastfood_rounded, color: Colors.grey)),
            ),
          ),

          const SizedBox(width: 14),

          // Dish Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: food.isVeg ? AppColors.veg : AppColors.nonVeg, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.circle, size: 6, color: food.isVeg ? AppColors.veg : AppColors.nonVeg),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatPaise(food.pricePaise),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),

          // Add Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkAction,
              foregroundColor: Colors.white,
              minimumSize: const Size(40, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _handleAddToCart(context, ref, food),
            child: Text(
              food.portions != null && food.portions!.isNotEmpty ? 'Options +' : 'Add +',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDishCard extends ConsumerWidget {
  final FoodItemModel food;
  final int restaurantId;

  const _MobileDishCard({required this.food, required this.restaurantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedFoodImg = AppConstants.resolveImageUrl(food.imageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: resolvedFoodImg,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade100),
              errorWidget: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Icon(Icons.fastfood, color: Colors.grey)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: food.isVeg ? AppColors.veg : AppColors.nonVeg, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.circle, size: 6, color: food.isVeg ? AppColors.veg : AppColors.nonVeg),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatPaise(food.pricePaise),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                if (food.portions != null && food.portions!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Portion sizes available',
                    style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkAction,
              foregroundColor: Colors.white,
              minimumSize: const Size(40, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _handleAddToCart(context, ref, food),
            child: Text(
              food.portions != null && food.portions!.isNotEmpty ? 'Options +' : 'Add +',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

void _handleAddToCart(BuildContext context, WidgetRef ref, FoodItemModel food) {
  final portions = food.portions;
  if (portions != null && portions.isNotEmpty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: food.isVeg ? AppColors.veg : AppColors.nonVeg,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: food.isVeg ? AppColors.veg : AppColors.nonVeg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      food.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select portion size:',
                style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ...['QUARTER', 'HALF', 'THREE_QUARTER', 'FULL'].where((p) => portions.containsKey(p)).map((portionKey) {
                final price = portions[portionKey]!;
                String displayTitle;
                switch (portionKey) {
                  case 'QUARTER':
                    displayTitle = 'Quarter Portion';
                    break;
                  case 'HALF':
                    displayTitle = 'Half Portion';
                    break;
                  case 'THREE_QUARTER':
                    displayTitle = '3/4 Portion';
                    break;
                  case 'FULL':
                  default:
                    displayTitle = 'Full Portion';
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: ListTile(
                    title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyFormatter.formatPaise(price),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(cartNotifierProvider.notifier).addToCart(food.id, portion: portionKey);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $displayTitle of "${food.name}" to cart'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppColors.darkAction,
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  } else {
    ref.read(cartNotifierProvider.notifier).addToCart(food.id, portion: 'FULL');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${food.name}" to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.darkAction,
      ),
    );
  }
}
