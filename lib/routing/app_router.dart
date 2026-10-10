import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

/// Pure, deterministic redirect function shared between RouterNotifier and unit tests
String? computeAppRedirect({
  required bool isLoading,
  required bool isAuthenticated,
  required String? role,
  required String location,
  required bool isWeb,
}) {
  // 1. Initial / Loading State: Hold at splash screen until auth resolves
  if (isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  final isLoginRoute = location == '/login' ||
      location == '/register' ||
      location == '/restaurant-login' ||
      location == '/delivery-login';

  final isPublicBrowseRoute = location == '/' || location.startsWith('/restaurant/');
  final isAdminRoute = location == '/admin' || location == '/admin-dashboard';
  final isOwnerRoute = location == '/owner' || location == '/owner-dashboard' || location == '/restaurant-owner' || location == '/restaurant-login';
  final isDeliveryRoute = location == '/rider' || location == '/delivery' || location == '/delivery-dashboard' || location == '/delivery-login';

  // 2. Unauthenticated User Flow (Guest browsing, Customer Login, Dedicated Staff Logins)
  if (!isAuthenticated) {
    if (location == '/splash') {
      return '/'; // Guests land on customer home
    }
    // Dedicated staff URLs show their respective logins directly without redirect loops
    if (isPublicBrowseRoute || isLoginRoute || isAdminRoute || isOwnerRoute || isDeliveryRoute) {
      return null; // Allowed directly
    }
    return '/login'; // Protected customer routes require login
  }

  // 3. Authenticated User Flow
  final userRole = role ?? 'CUSTOMER';

  // 3A. Mobile App (!isWeb) Restrictions:
  // Mobile app only supports CUSTOMER and DELIVERY_PARTNER.
  if (!isWeb) {
    if (userRole == 'ADMIN' || userRole == 'RESTAURANT_OWNER') {
      // Mobile does not support Admin or Owner. Keep them on /login (or redirect to /login)
      if (isLoginRoute) {
        return null; // Terminal on /login, prevents loop
      }
      return '/login';
    }

    if (userRole == 'DELIVERY_PARTNER') {
      if (isDeliveryRoute) {
        return null;
      }
      return '/rider';
    }

    // CUSTOMER role on mobile:
    if (isAdminRoute || isOwnerRoute || isDeliveryRoute) {
      return '/';
    }
    if (location == '/splash' || isLoginRoute) {
      return '/';
    }
    return null; // Customer browsing allowed
  }

  // 3B. Web Platform (isWeb) Routing: Supports all 4 roles
  if (userRole == 'ADMIN') {
    if (isAdminRoute) {
      return null;
    }
    return '/admin';
  }

  if (userRole == 'RESTAURANT_OWNER') {
    if (isOwnerRoute) {
      return null;
    }
    return '/owner';
  }

  if (userRole == 'DELIVERY_PARTNER') {
    if (isDeliveryRoute) {
      return null;
    }
    return '/rider';
  }

  // CUSTOMER role on Web:
  if (isAdminRoute || isOwnerRoute || isDeliveryRoute) {
    return '/'; // Deny wrong role
  }
  if (location == '/splash' || isLoginRoute) {
    return '/';
  }
  return null;
}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    return computeAppRedirect(
      isLoading: authState.isLoading,
      isAuthenticated: authState.isAuthenticated,
      role: authState.user?.role,
      location: state.matchedLocation,
      isWeb: kIsWeb,
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
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
          child: const LoginScreen(forcedRole: 'CUSTOMER'),
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
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'ADMIN';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const AdminDashboardScreen() : const LoginScreen(forcedRole: 'ADMIN'),
          );
        },
      ),
      GoRoute(
        path: '/admin-dashboard',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'ADMIN';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const AdminDashboardScreen() : const LoginScreen(forcedRole: 'ADMIN'),
          );
        },
      ),
      GoRoute(
        path: '/owner',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'RESTAURANT_OWNER';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const OwnerDashboardScreen() : const LoginScreen(forcedRole: 'RESTAURANT_OWNER'),
          );
        },
      ),
      GoRoute(
        path: '/owner-dashboard',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'RESTAURANT_OWNER';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const OwnerDashboardScreen() : const LoginScreen(forcedRole: 'RESTAURANT_OWNER'),
          );
        },
      ),
      GoRoute(
        path: '/restaurant-owner',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'RESTAURANT_OWNER';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const OwnerDashboardScreen() : const LoginScreen(forcedRole: 'RESTAURANT_OWNER'),
          );
        },
      ),
      GoRoute(
        path: '/rider',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'DELIVERY_PARTNER';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const DeliveryDashboardScreen() : const LoginScreen(forcedRole: 'DELIVERY_PARTNER'),
          );
        },
      ),
      GoRoute(
        path: '/delivery',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'DELIVERY_PARTNER';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const DeliveryDashboardScreen() : const LoginScreen(forcedRole: 'DELIVERY_PARTNER'),
          );
        },
      ),
      GoRoute(
        path: '/delivery-dashboard',
        pageBuilder: (context, state) {
          final authState = ref.watch(authProvider);
          final isAuthenticated = authState.isAuthenticated && authState.user?.role == 'DELIVERY_PARTNER';
          return _buildPageWithTransition(
            context: context,
            state: state,
            child: isAuthenticated ? const DeliveryDashboardScreen() : const LoginScreen(forcedRole: 'DELIVERY_PARTNER'),
          );
        },
      ),
      GoRoute(
        path: '/restaurant-login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(forcedRole: 'RESTAURANT_OWNER'),
        ),
      ),
      GoRoute(
        path: '/delivery-login',
        pageBuilder: (context, state) => _buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(forcedRole: 'DELIVERY_PARTNER'),
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

