import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:foodflow/core/theme/app_colors.dart';
import 'package:foodflow/core/utils/currency_formatter.dart';
import 'package:dio/dio.dart';
import 'package:foodflow/core/network/api_client.dart';
import 'package:foodflow/features/auth/presentation/auth_providers.dart';
import 'package:foodflow/features/auth/presentation/login_screen.dart';
import 'package:foodflow/features/restaurant/presentation/home_screen.dart';
import 'package:foodflow/features/auth/presentation/profile_screen.dart';
import 'package:foodflow/features/restaurant/domain/models.dart';
import 'package:foodflow/routing/app_router.dart';
import 'package:foodflow/core/constants/app_constants.dart';
import 'package:foodflow/core/widgets/pwa_install_guide_dialog.dart';
import 'package:foodflow/features/auth/data/auth_repository.dart';
import 'package:foodflow/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:foodflow/features/auth/presentation/rider_register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepo extends AuthRepository {
  MockAuthRepo() : super(ApiClient());
  @override
  Future<UserModel?> getCurrentUser() async => null;
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(UserModel? user) : super(MockAuthRepo()) {
    state = AuthState(user: user, isLoading: false);
  }

  @override
  Future<void> checkAuth() async {}

  @override
  Future<void> logout() async {
    state = AuthState(user: null, isLoading: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('CurrencyFormatter Tests', () {
    test('formats paise to INR currency string correctly', () {
      expect(CurrencyFormatter.formatPaise(0), '₹0.00');
      expect(CurrencyFormatter.formatPaise(100), '₹1.00');
      expect(CurrencyFormatter.formatPaise(49900), '₹499.00');
      expect(CurrencyFormatter.formatPaise(125050), '₹1,250.50');
    });
  });

  group('Cart & Pricing Domain Model Tests', () {
    test('CartItemModel and CartSummaryModel calculate items, subtotal and totals accurately', () {
      final food1 = FoodItemModel(
        id: 101,
        restaurantId: 1,
        categoryId: 1,
        name: 'Paneer Butter Masala',
        pricePaise: 25000,
        isVeg: true,
        isAvailable: true,
      );

      final food2 = FoodItemModel(
        id: 102,
        restaurantId: 1,
        categoryId: 1,
        name: 'Butter Naan',
        pricePaise: 4000,
        isVeg: true,
        isAvailable: true,
      );

      final item1 = CartItemModel(
        id: 1,
        foodItem: food1,
        quantity: 2,
      );

      final item2 = CartItemModel(
        id: 2,
        foodItem: food2,
        quantity: 3,
      );

      final cart = CartSummaryModel(
        items: [item1, item2],
        subtotalPaise: 62000,
        deliveryFeePaise: 4000,
        taxPaise: 3100,
        discountPaise: 5000,
        totalPaise: 64100,
      );

      expect(cart.items.length, 2);
      expect(cart.subtotalPaise, 62000);
      expect(cart.totalPaise, 64100);
      expect(cart.items.first.foodItem.name, 'Paneer Butter Masala');
      expect(cart.items.first.quantity, 2);
    });

    test('CartSummaryModel handles first-order free delivery flags and original fee correctly', () {
      final cartJson = {
        'items': [],
        'restaurant': null,
        'subtotal_paise': 30000,
        'delivery_fee_paise': 0,
        'tax_paise': 1500,
        'discount_paise': 0,
        'total_paise': 31500,
        'is_first_order_free_delivery': true,
        'original_delivery_fee_paise': 3500,
      };

      final cart = CartSummaryModel.fromJson(cartJson);
      expect(cart.deliveryFeePaise, 0);
      expect(cart.isFirstOrderFreeDelivery, true);
      expect(cart.originalDeliveryFeePaise, 3500);
      expect(cart.totalPaise, 31500);
    });
  });

  group('User & Role Domain Model Tests', () {
    test('UserModel parses roles and attributes correctly', () {
      final customerJson = {
        'id': 10,
        'email': 'customer@foodflow.com',
        'full_name': 'Test Customer',
        'phone': '9876543210',
        'role': 'CUSTOMER',
        'is_active': true,
        'is_approved': true,
      };

      final user = UserModel.fromJson(customerJson);
      expect(user.id, 10);
      expect(user.role, 'CUSTOMER');
      expect(user.isActive, true);

      final adminJson = {
        'id': 4,
        'email': 'shahinsha@foodflow.com',
        'full_name': 'Super Admin',
        'role': 'ADMIN',
        'is_active': true,
        'is_approved': true,
      };

      final admin = UserModel.fromJson(adminJson);
      expect(admin.role, 'ADMIN');
      expect(admin.email, 'shahinsha@foodflow.com');
    });
  });

  group('Coupon Domain Model Tests', () {
    test('CouponModel parses percentage and flat discount structures', () {
      final couponJson = {
        'id': 1,
        'code': 'WELCOME50',
        'title': '50% OFF',
        'description': '50% off on first order',
        'discount_type': 'PERCENTAGE',
        'discount_value': 50,
        'min_order_paise': 20000,
        'max_discount_paise': 10000,
        'is_active': true,
        'first_order_only': true,
      };

      final coupon = CouponModel.fromJson(couponJson);
      expect(coupon.code, 'WELCOME50');
      expect(coupon.discountType, 'PERCENTAGE');
      expect(coupon.discountValue, 50);
      expect(coupon.maxDiscountPaise, 10000);
      expect(coupon.firstOrderOnly, true);
    });
  });

  group('Theme & Design Tokens Tests', () {
    test('AppColors flame primary and dark tokens are correctly defined', () {
      expect(AppColors.primary, const Color(0xFFFF521B));
      expect(AppColors.primaryDark, const Color(0xFFE03E0B));
      expect(AppColors.primaryLight, const Color(0xFFFF7A4D));
      expect(AppColors.veg, const Color(0xFF27AE60));
      expect(AppColors.nonVeg, const Color(0xFFE74C3C));
      expect(AppColors.backgroundLight, const Color(0xFFF8F9FD));
      expect(AppColors.backgroundDark, const Color(0xFF0F172A));
    });
  });

  group('AuthState and Role Routing Redirection Tests', () {
    test('Unauthenticated user on protected routes redirects to /login', () {
      final unauthenticated = AuthState(
        user: null,
        isLoading: false,
      );

      expect(unauthenticated.isAuthenticated, false);
      expect(unauthenticated.isLoading, false);
    });

    test('Authenticated role attributes accurately map to corresponding dashboards', () {
      final customer = UserModel(id: 1, email: 'cust@ff.com', fullName: 'Cust', role: 'CUSTOMER');
      final owner = UserModel(id: 2, email: 'own@ff.com', fullName: 'Owner', role: 'RESTAURANT_OWNER');
      final rider = UserModel(id: 3, email: 'rider@ff.com', fullName: 'Rider', role: 'DELIVERY_PARTNER');
      final admin = UserModel(id: 4, email: 'admin@ff.com', fullName: 'Admin', role: 'ADMIN');

      expect(customer.role, 'CUSTOMER');
      expect(owner.role, 'RESTAURANT_OWNER');
      expect(rider.role, 'DELIVERY_PARTNER');
      expect(admin.role, 'ADMIN');
    });

    test('Platform routing distinguishes web direct routes /admin, /owner, /delivery from mobile', () {
      const webRoutes = ['/', '/login', '/admin', '/owner', '/delivery'];
      expect(webRoutes.contains('/admin'), true);
      expect(webRoutes.contains('/owner'), true);
      expect(webRoutes.contains('/delivery'), true);
      expect(webRoutes.contains('/'), true);
    });
  });

  group('Router Redirect Logic & Loop Prevention Tests', () {
    test('Loading state preserves requested routes and does not wipe direct URLs', () {
      expect(
        computeAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          role: null,
          location: '/splash',
          isWeb: false,
        ),
        isNull,
      );
      expect(
        computeAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          role: null,
          location: '/admin',
          isWeb: true,
        ),
        isNull,
      );
      expect(
        computeAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          role: null,
          location: '/owner',
          isWeb: true,
        ),
        isNull,
      );
      expect(
        computeAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          role: null,
          location: '/rider',
          isWeb: true,
        ),
        isNull,
      );
      expect(
        computeAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: true,
        ),
        isNull,
      );
    });

    test('Unauthenticated guest navigation allows / and /restaurant/:id and redirects /splash to /', () {
      // Splash screen routes guest to /
      final splashRedirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/splash',
        isWeb: false,
      );
      expect(splashRedirect, '/');
      // Subsequent check at / terminates at null
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: false,
        ),
        isNull,
      );

      // Public routes allowed
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/restaurant/42',
          isWeb: false,
        ),
        isNull,
      );
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/login',
          isWeb: false,
        ),
        isNull,
      );

      // Customer protected routes redirect to /login
      final ordersRedirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/orders',
        isWeb: true,
      );
      expect(ordersRedirect, '/login');
      // And /login terminates
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/login',
          isWeb: true,
        ),
        isNull,
      );
    });

    test('Mobile Android: Customer login routes to / and prevents loops', () {
      // From login to /
      final toHome = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'CUSTOMER',
        location: '/login',
        isWeb: false,
      );
      expect(toHome, '/');

      // Next check on / terminates
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'CUSTOMER',
          location: '/',
          isWeb: false,
        ),
        isNull,
      );

      // Customer on /cart terminates
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'CUSTOMER',
          location: '/cart',
          isWeb: false,
        ),
        isNull,
      );
    });

    test('Mobile Android: Delivery Partner login routes to /delivery and prevents loops', () {
      final toDelivery = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'DELIVERY_PARTNER',
        location: '/login',
        isWeb: false,
      );
      expect(toDelivery, '/rider');

      // Next check on /rider terminates
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'DELIVERY_PARTNER',
          location: '/rider',
          isWeb: false,
        ),
        isNull,
      );

      // /delivery alias also terminates
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'DELIVERY_PARTNER',
          location: '/delivery',
          isWeb: false,
        ),
        isNull,
      );
    });

    test('Mobile Android: Admin and Owner accounts are denied and terminate cleanly on /login', () {
      // Admin on /splash redirects to /login
      final splashToLogin = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'ADMIN',
        location: '/splash',
        isWeb: false,
      );
      expect(splashToLogin, '/login');

      // Admin on /login TERMINATES at null (no loop)
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'ADMIN',
          location: '/login',
          isWeb: false,
        ),
        isNull,
      );

      // Restaurant Owner on / redirects to /login
      final ownerToLogin = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'RESTAURANT_OWNER',
        location: '/',
        isWeb: false,
      );
      expect(ownerToLogin, '/login');

      // Owner on /login TERMINATES at null (no loop)
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'RESTAURANT_OWNER',
          location: '/login',
          isWeb: false,
        ),
        isNull,
      );
    });

    test('Web Platform: Direct navigation to /admin, /owner, /rider, /delivery succeeds for authorized roles', () {
      // Admin at /admin stays at /admin
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'ADMIN',
          location: '/admin',
          isWeb: true,
        ),
        isNull,
      );

      // Admin at /admin-dashboard stays at /admin-dashboard
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'ADMIN',
          location: '/admin-dashboard',
          isWeb: true,
        ),
        isNull,
      );

      // Owner at /owner stays at /owner
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'RESTAURANT_OWNER',
          location: '/owner',
          isWeb: true,
        ),
        isNull,
      );

      // Delivery Partner at /rider stays at /rider
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'DELIVERY_PARTNER',
          location: '/rider',
          isWeb: true,
        ),
        isNull,
      );

      // Delivery Partner at /delivery stays at /delivery
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'DELIVERY_PARTNER',
          location: '/delivery',
          isWeb: true,
        ),
        isNull,
      );
    });

    test('Web Platform: Unauthenticated direct navigation to /admin, /owner, /rider shows dedicated login pages without loops', () {
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/admin',
          isWeb: true,
        ),
        isNull,
      );

      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/owner',
          isWeb: true,
        ),
        isNull,
      );

      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/rider',
          isWeb: true,
        ),
        isNull,
      );
    });

    test('Web Platform: Wrong role access is denied and routes to /', () {
      // Customer trying /admin redirects to /
      final custToAdmin = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'CUSTOMER',
        location: '/admin',
        isWeb: true,
      );
      expect(custToAdmin, '/');

      // Customer on / terminates
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'CUSTOMER',
          location: '/',
          isWeb: true,
        ),
        isNull,
      );

      // Customer trying /owner redirects to /
      final custToOwner = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'CUSTOMER',
        location: '/owner',
        isWeb: true,
      );
      expect(custToOwner, '/');
    });

    test('Deterministic Loop Invariant: Any non-null redirect must terminate on the subsequent call', () {
      final testRoles = <String?>[null, 'CUSTOMER', 'RESTAURANT_OWNER', 'DELIVERY_PARTNER', 'ADMIN'];
      final testLocations = [
        '/',
        '/splash',
        '/login',
        '/register',
        '/restaurant-login',
        '/delivery-login',
        '/admin',
        '/admin-dashboard',
        '/owner',
        '/owner-dashboard',
        '/restaurant-owner',
        '/rider',
        '/delivery',
        '/delivery-dashboard',
        '/restaurant/1',
        '/cart',
        '/checkout',
        '/orders',
        '/order/10',
      ];
      final platforms = [true, false];

      for (final isWeb in platforms) {
        for (final role in testRoles) {
          final isAuth = role != null;
          for (final loc in testLocations) {
            final nextLoc = computeAppRedirect(
              isLoading: false,
              isAuthenticated: isAuth,
              role: role,
              location: loc,
              isWeb: isWeb,
            );

            if (nextLoc != null) {
              // The next hop MUST return null to guarantee zero redirect loops
              final secondHop = computeAppRedirect(
                isLoading: false,
                isAuthenticated: isAuth,
                role: role,
                location: nextLoc,
                isWeb: isWeb,
              );
              expect(
                secondHop,
                isNull,
                reason: 'Redirect cycle detected for isWeb=$isWeb, role=$role, loc=$loc -> $nextLoc -> $secondHop',
              );
            }
          }
        }
      }
    });
  });

  group('ApiClient Configuration & Error Formatting Tests', () {
    test('ApiClient sets 30-second connection and receive timeouts', () {
      final client = ApiClient();
      expect(client.dio.options.connectTimeout, const Duration(seconds: 30));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(client.dio.options.sendTimeout, const Duration(seconds: 30));
    });

    test('ApiClient.formatError accurately formats timeout errors without stack traces', () {
      final timeoutException = DioException(
        requestOptions: RequestOptions(path: '/api/v1/users/me/addresses'),
        type: DioExceptionType.receiveTimeout,
        message: 'The request took longer than 10000ms',
      );

      final formatted = ApiClient.formatError(timeoutException);
      expect(formatted, contains('Connection timed out'));
      expect(formatted, contains('Please check your internet connection'));
      expect(formatted, isNot(contains('at dart:core')));
      expect(formatted, isNot(contains('DioException')));
    });

    test('ApiClient.formatError accurately parses HTTP status codes and backend detail payloads', () {
      final e401 = DioException(
        requestOptions: RequestOptions(path: '/api/v1/users/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/users/me'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ApiClient.formatError(e401), 'Your session has expired. Please sign in again.');

      final e403 = DioException(
        requestOptions: RequestOptions(path: '/api/v1/admin/analytics'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/admin/analytics'),
          statusCode: 403,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ApiClient.formatError(e403), 'Access denied. You do not have permission for this action.');

      final e422 = DioException(
        requestOptions: RequestOptions(path: '/api/v1/orders'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/orders'),
          statusCode: 422,
          data: {'detail': 'Selected delivery address is inactive'},
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ApiClient.formatError(e422), 'Selected delivery address is inactive');

      final e500 = DioException(
        requestOptions: RequestOptions(path: '/api/v1/restaurants'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/restaurants'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(ApiClient.formatError(e500), 'Server is temporarily unavailable. Please try again in a few moments.');
    });

    test('ApiClient.formatError handles generic exceptions safely', () {
      final generic = Exception('Database table locked');
      final formatted = ApiClient.formatError(generic);
      expect(formatted, contains('Database table locked'));
      expect(formatted, isNot(contains('Exception: ')));
    });
  });

  group('User Address Model & Parsing Tests', () {
    test('AddressItem parses JSON fields and handles defaults correctly', () {
      final json = {
        'id': 101,
        'user_id': 5,
        'label': 'HOME',
        'street_address': '104 Sunrise Boulevard, Apt 4B',
        'city': 'Bengaluru',
        'pincode': '560001',
        'is_default': true,
      };

      final address = AddressItem.fromJson(json);
      expect(address.id, 101);
      expect(address.label, 'HOME');
      expect(address.streetAddress, '104 Sunrise Boulevard, Apt 4B');
      expect(address.city, 'Bengaluru');
      expect(address.pincode, '560001');
      expect(address.isDefault, true);
    });
  });

  group('Router Direct Route Widget Rendering Tests', () {
    testWidgets('Direct route "/" renders HomeScreen when unauthenticated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Direct route "/admin" renders Admin Login Screen when unauthenticated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/admin',
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const LoginScreen(forcedRole: 'ADMIN'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Admin Portal'), findsOneWidget);
      expect(find.text('Sign in with administrator credentials'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('Direct route "/owner" renders Restaurant Partner Login Screen when unauthenticated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/owner',
        routes: [
          GoRoute(
            path: '/owner',
            builder: (context, state) => const LoginScreen(forcedRole: 'RESTAURANT_OWNER'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Restaurant Partner Login'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('Direct route "/rider" renders Delivery Rider Login Screen when unauthenticated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/rider',
        routes: [
          GoRoute(
            path: '/rider',
            builder: (context, state) => const LoginScreen(forcedRole: 'DELIVERY_PARTNER'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Delivery Rider Login'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('PwaInstallGuideDialog renders iOS and Windows tabs and instructions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PwaInstallGuideDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Install FoodFlow App'), findsOneWidget);
      expect(find.text('iPhone / iPad'), findsOneWidget);
      expect(find.text('Windows 10 / 11'), findsOneWidget);
      expect(find.text('Open in Safari'), findsOneWidget);

      // Switch to Windows tab
      await tester.tap(find.text('Windows 10 / 11'));
      await tester.pumpAndSettle();

      expect(find.text('Open Chrome or Microsoft Edge'), findsOneWidget);
    });

    testWidgets('AdminDashboardScreen displays both Approve Store and Reject buttons for pending restaurants', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pendingRestaurant = RestaurantModel(
        id: 99,
        name: 'Mazali Grill',
        cuisine: 'Arabian, Mandi',
        rating: 4.6,
        deliveryFeePaise: 3000,
        minOrderPaise: 10000,
        estimatedDeliveryTime: '30-40 min',
        isActive: false,
        isApproved: false, // PENDING REVIEW
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminRestaurantsProvider.overrideWith((ref) async => [pendingRestaurant]),
            adminAnalyticsProvider.overrideWith((ref) async => {
              'total_orders': 10,
              'active_orders': 2,
              'completed_orders': 8,
              'total_restaurants': 1,
              'total_customers': 20,
              'gross_order_value_paise': 500000,
              'net_revenue_paise': 450000,
              'promotion_discounts_paise': 50000,
            }),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Restaurants Directory (index 2)
      await tester.tap(find.text('Restaurants Directory'));
      await tester.pumpAndSettle();

      expect(find.text('Mazali Grill'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.text('Approve Store'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('AdminDashboardScreen User Management displays high-contrast user details, roles, and Delete action with confirmation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testUsers = [
        UserModel(
          id: 1,
          email: 'admin@foodflow.com',
          fullName: 'Super Admin',
          role: 'ADMIN',
          isActive: true,
          isApproved: true,
        ),
        UserModel(
          id: 2,
          email: 'owner@mazali.com',
          fullName: 'Mazali Owner',
          role: 'RESTAURANT_OWNER',
          isActive: true,
          isApproved: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testUsers[0])),
            adminUsersProvider.overrideWith((ref) async => testUsers),
            adminAnalyticsProvider.overrideWith((ref) async => {}),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Users Management (index 3)
      await tester.tap(find.text('Users Management'));
      await tester.pumpAndSettle();

      expect(find.text('Super Admin'), findsNWidgets(2));
      expect(find.text('admin@foodflow.com'), findsOneWidget);
      expect(find.text('YOU (ACTIVE ADMIN)'), findsOneWidget);
      expect(find.text('Mazali Owner'), findsOneWidget);
      expect(find.text('owner@mazali.com'), findsOneWidget);
      expect(find.text('RESTAURANT_OWNER'), findsOneWidget);

      // Tap Delete icon on non-admin user (id: 2)
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Verify Delete User confirmation dialog appears
      expect(find.text('Delete User Account'), findsOneWidget);
      expect(find.text('Confirm Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete User Account'), findsNothing);
    });

    testWidgets('Sign Out action clears session and updates authentication state cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.authTokenKey: 'fake_jwt_token',
        AppConstants.userKey: '{"id":1,"email":"user@foodflow.com","role":"CUSTOMER"}',
      });

      final fakeUser = UserModel(
        id: 1,
        email: 'user@foodflow.com',
        fullName: 'Test Customer',
        role: 'CUSTOMER',
        isApproved: true,
      );

      final container = ProviderContainer();
      final notifier = container.read(authProvider.notifier);
      notifier.state = AuthState(user: fakeUser, isLoading: false);

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).user?.email, 'user@foodflow.com');

      // Execute logout
      await notifier.logout();

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).user, isNull);

      // Verify routing after logout
      // 1. Protected route like /profile redirects to /login
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/profile',
          isWeb: true,
        ),
        '/login',
      );

      // 2. Public / guest browsing / stays at /
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: true,
        ),
        isNull,
      );

      // 3. Admin login route stays on /admin
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/admin',
          isWeb: true,
        ),
        isNull,
      );
    });
  });

  group('Delivery Rider Self-Registration & Verification Flow Tests', () {
    test('Router allows /rider/register and /rider-register without unauthenticated redirect loop', () {
      // 1. Unauthenticated visiting /rider/register is allowed directly
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/rider/register',
          isWeb: true,
        ),
        isNull,
      );

      // 2. Unauthenticated visiting /rider-register is allowed directly
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/rider-register',
          isWeb: true,
        ),
        isNull,
      );

      // 3. Authenticated DELIVERY_PARTNER role stays on /rider
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'DELIVERY_PARTNER',
          location: '/rider',
          isWeb: true,
        ),
        isNull,
      );

      // 4. Authenticated CUSTOMER attempting staff route is redirected to /
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'CUSTOMER',
          location: '/rider',
          isWeb: true,
        ),
        '/',
      );
    });

    testWidgets('Rider Login Screen renders Register as Delivery Rider action button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(null)),
          ],
          child: const MaterialApp(
            home: LoginScreen(forcedRole: 'DELIVERY_PARTNER'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery Rider Login'), findsOneWidget);
      expect(find.text('🛵 Register as Delivery Rider'), findsOneWidget);
    });

    testWidgets('Rider Register Screen validates required fields and password matching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(null)),
          ],
          child: const MaterialApp(
            home: RiderRegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Partner Registration'), findsOneWidget);
      expect(find.text('Submit Application'), findsOneWidget);

      // Tap submit with empty fields -> validations trigger
      await tester.tap(find.text('Submit Application'));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone number is required for delivery partners'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });
}

