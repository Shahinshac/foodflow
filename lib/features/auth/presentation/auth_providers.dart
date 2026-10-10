import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../restaurant/domain/models.dart';
import '../data/auth_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState(isLoading: true)) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final user = await _repository.getCurrentUser();
      state = AuthState(user: user, isLoading: false);
    } catch (_) {
      state = AuthState(isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.login(email, password);
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> registerOwner({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required String restaurantName,
    required String cuisine,
    String? description,
    String? addressText,
    String? imageUrl,
    int deliveryFeePaise = 3000,
    int minOrderPaise = 10000,
    String estimatedDeliveryTime = '25-35 min',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.registerOwner(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        restaurantName: restaurantName,
        cuisine: cuisine,
        description: description,
        addressText: addressText,
        imageUrl: imageUrl,
        deliveryFeePaise: deliveryFeePaise,
        minOrderPaise: minOrderPaise,
        estimatedDeliveryTime: estimatedDeliveryTime,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> registerRider({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String vehicleType = 'SCOOTER',
    String? vehicleNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.registerRider(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> loginWithGoogle({
    String? idToken,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.loginWithGoogle(
        idToken: idToken,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState(user: null, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
