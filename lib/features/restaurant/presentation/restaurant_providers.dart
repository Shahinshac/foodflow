import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/restaurant_repository.dart';
import '../domain/models.dart';
import '../../auth/presentation/auth_providers.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => RestaurantRepository(ref.watch(apiClientProvider)),
);

// Filter & Search Providers
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCuisineProvider = StateProvider<String?>((ref) => null);
final filterVegOnlyProvider = StateProvider<bool>((ref) => false);
final filterMinRatingProvider = StateProvider<double?>((ref) => null);
final filterMaxDeliveryTimeProvider = StateProvider<int?>((ref) => null);
final filterOpenNowProvider = StateProvider<bool>((ref) => false);
final filterHasOffersProvider = StateProvider<bool>((ref) => false);
final sortByProvider = StateProvider<String>((ref) => 'recommended');

// Favorites State Notifier
class FavoritesNotifier extends StateNotifier<Set<int>> {
  final RestaurantRepository _repo;

  FavoritesNotifier(this._repo) : super({}) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    try {
      final ids = await _repo.getFavoriteIds();
      state = ids.toSet();
    } catch (_) {}
  }

  Future<void> toggleFavorite(int restaurantId) async {
    final current = state;
    final isFav = current.contains(restaurantId);

    // Optimistic UI update
    if (isFav) {
      state = {...current}..remove(restaurantId);
    } else {
      state = {...current, restaurantId};
    }

    try {
      final result = await _repo.toggleFavorite(restaurantId);
      if (result) {
        state = {...state, restaurantId};
      } else {
        state = {...state}..remove(restaurantId);
      }
    } catch (e) {
      // Rollback on network failure
      state = current;
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>((ref) {
  final repo = ref.watch(restaurantRepositoryProvider);
  return FavoritesNotifier(repo);
});

final favoriteRestaurantsProvider = FutureProvider<List<RestaurantModel>>((ref) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  ref.watch(favoritesProvider); // Re-fetch when favorites change
  return repo.getFavoriteRestaurants();
});

final restaurantsListProvider = FutureProvider<List<RestaurantModel>>((ref) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final cuisine = ref.watch(selectedCuisineProvider);
  final isVeg = ref.watch(filterVegOnlyProvider);
  final minRating = ref.watch(filterMinRatingProvider);
  final maxDeliveryTime = ref.watch(filterMaxDeliveryTimeProvider);
  final openNow = ref.watch(filterOpenNowProvider);
  final hasOffers = ref.watch(filterHasOffersProvider);
  final sortBy = ref.watch(sortByProvider);
  final favIds = ref.watch(favoritesProvider);

  final list = await repo.getRestaurants(
    query: query,
    cuisine: cuisine,
    isVeg: isVeg,
    minRating: minRating,
    maxDeliveryTime: maxDeliveryTime,
    openNow: openNow,
    hasOffers: hasOffers,
    sortBy: sortBy,
  );

  return list.map((r) => r.copyWith(isFavorite: favIds.contains(r.id))).toList();
});

final restaurantDetailProvider = FutureProvider.family<RestaurantModel, int>((ref, id) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  final favIds = ref.watch(favoritesProvider);
  final rest = await repo.getRestaurantDetail(id);
  return rest.copyWith(isFavorite: favIds.contains(id));
});

final restaurantFoodsProvider = FutureProvider.family<List<FoodItemModel>, int>((ref, id) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurantFoods(id);
});
