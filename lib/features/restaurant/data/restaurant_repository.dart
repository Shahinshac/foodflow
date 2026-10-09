import '../../../core/network/api_client.dart';
import '../domain/models.dart';

class RestaurantRepository {
  final ApiClient apiClient;

  RestaurantRepository(this.apiClient);

  Future<List<RestaurantModel>> getRestaurants({
    String? query,
    String? cuisine,
    bool? isVeg,
    double? minRating,
    int? maxDeliveryTime,
    bool? openNow,
    bool? hasOffers,
    String? sortBy,
  }) async {
    final response = await apiClient.dio.get(
      '/restaurants',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine,
        if (isVeg != null && isVeg) 'is_veg': isVeg,
        'min_rating': ?minRating,
        'max_delivery_time': ?maxDeliveryTime,
        if (openNow != null && openNow) 'open_now': openNow,
        if (hasOffers != null && hasOffers) 'has_offers': hasOffers,
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
      },
    );

    return (response.data as List)
        .map((e) => RestaurantModel.fromJson(e))
        .toList();
  }

  Future<RestaurantModel> getRestaurantDetail(int id) async {
    final response = await apiClient.dio.get('/restaurants/$id');
    return RestaurantModel.fromJson(response.data);
  }

  Future<List<FoodItemModel>> getRestaurantFoods(int restaurantId) async {
    final response = await apiClient.dio.get('/restaurants/$restaurantId/foods');
    return (response.data as List)
        .map((e) => FoodItemModel.fromJson(e))
        .toList();
  }

  // Favorites API
  Future<List<int>> getFavoriteIds() async {
    final response = await apiClient.dio.get('/users/favorites/ids');
    return List<int>.from(response.data);
  }

  Future<List<RestaurantModel>> getFavoriteRestaurants() async {
    final response = await apiClient.dio.get('/users/favorites');
    return (response.data as List)
        .map((e) => RestaurantModel.fromJson(e))
        .toList();
  }

  Future<bool> toggleFavorite(int restaurantId) async {
    final response = await apiClient.dio.post('/users/favorites/$restaurantId');
    return response.data['is_favorite'] ?? false;
  }
}
