import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/restaurant/presentation/home_screen.dart';
import '../features/restaurant/presentation/restaurant_detail_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/order/presentation/checkout_screen.dart';
import '../features/order/presentation/orders_list_screen.dart';
import '../features/owner/presentation/owner_dashboard_screen.dart';
import '../features/delivery/presentation/delivery_dashboard_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/tracking/presentation/live_map_tracking_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      // Allow splash screen to show on boot
      if (state.matchedLocation == '/splash') return null;

      final isLoginRoute = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/register' ||
                          state.matchedLocation == '/admin' ||
                          state.matchedLocation == '/restaurant-login' ||
                          state.matchedLocation == '/delivery-login';

      if (!authState.isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      if (authState.isAuthenticated) {
        final role = authState.user?.role ?? 'CUSTOMER';

        if (isLoginRoute) {
          if (role == 'RESTAURANT_OWNER') return '/owner-dashboard';
          if (role == 'DELIVERY_PARTNER') return '/delivery-dashboard';
          if (role == 'ADMIN') return '/admin-dashboard';
          return '/';
        }

        if (state.matchedLocation == '/') {
          if (role == 'RESTAURANT_OWNER') return '/owner-dashboard';
          if (role == 'DELIVERY_PARTNER') return '/delivery-dashboard';
          if (role == 'ADMIN') return '/admin-dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/restaurant-login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/delivery-login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/owner-dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/delivery-dashboard',
        builder: (context, state) => const DeliveryDashboardScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RestaurantDetailScreen(restaurantId: id);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersListScreen(),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return LiveMapTrackingScreen(orderId: id);
        },
      ),
    ],
  );
});
