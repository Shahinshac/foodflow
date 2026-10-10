import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_and_empty_views.dart';
import '../../../core/widgets/motion_system.dart';
import 'restaurant_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteRestaurantsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Your Favorites', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(favoriteRestaurantsProvider),
        color: AppColors.primary,
        child: favoritesAsync.when(
          data: (restaurants) {
            if (restaurants.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  CustomEmptyView(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favorite restaurants yet',
                    description: 'Tap the heart icon on any restaurant to save your favorite dining spots here for fast access!',
                  ),
                ],
              );
            }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              final resolvedImage = AppConstants.resolveImageUrl(restaurant.imageUrl);

              return Container(
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
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22),
                          ),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: resolvedImage,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: Colors.grey.shade200,
                                  highlightColor: Colors.white,
                                  child: Container(height: 160, color: Colors.white),
                                ),
                              ),
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
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      restaurant.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              FoodShimmerLoading(width: double.infinity, height: 180, borderRadius: 22),
              SizedBox(height: 16),
              FoodShimmerLoading(width: double.infinity, height: 180, borderRadius: 22),
            ],
          ),
        ),
        error: (err, _) => CustomErrorView(
          message: 'Failed to load favorite restaurants: ${ApiClient.formatError(err)}',
          onRetry: () => ref.invalidate(favoriteRestaurantsProvider),
        ),
      ),
    ),
  );
}
}
