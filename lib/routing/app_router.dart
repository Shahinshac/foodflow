import 'package:flutter/material.dart';
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

CustomTransitionPage<void> _buildPageWithTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}

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
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/restaurant-login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/delivery-login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/owner-dashboard',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const OwnerDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/delivery-dashboard',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const DeliveryDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/admin-dashboard',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/restaurant/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: RestaurantDetailScreen(restaurantId: id),
          );
        },
      ),
      GoRoute(
        path: '/cart',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const CartScreen(),
        ),
      ),
      GoRoute(
        path: '/checkout',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const CheckoutScreen(),
        ),
      ),
      GoRoute(
        path: '/orders',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const OrdersListScreen(),
        ),
      ),
      GoRoute(
        path: '/order/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: LiveMapTrackingScreen(orderId: id),
          );
        },
      ),
    ],
  );
});
