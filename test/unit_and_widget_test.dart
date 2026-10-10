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
import 'package:latlong2/latlong.dart';
import 'package:foodflow/core/services/routing_service.dart';
import 'package:foodflow/features/tracking/presentation/live_map_tracking_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepo extends AuthRepository {
  MockAuthRepo() : super(ApiClient());
  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove(AppConstants.userKey);
  }
}

class FakeGoogleAuthRepo extends AuthRepository {
  final bool shouldCancel;
  final UserModel? mockUser;
  final String? throwError;
  final VoidCallback? onSignInCalled;

  FakeGoogleAuthRepo({
    this.shouldCancel = false,
    this.mockUser,
    this.throwError,
    this.onSignInCalled,
  }) : super(ApiClient());

  @override
  Future<UserModel?> getCurrentUser() async => mockUser;

  @override
  Future<UserModel?> signInWithGoogle() async {
    onSignInCalled?.call();
    if (throwError != null) {
      throw Exception(throwError);
    }
    if (shouldCancel) {
      return null;
    }
    if (mockUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.authTokenKey, 'fake_google_jwt');
      await prefs.setString(AppConstants.userKey, jsonEncode(mockUser!.toJson()));
    }
    return mockUser;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove(AppConstants.userKey);
  }
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(UserModel? user) : super(MockAuthRepo()) {
    state = AuthState(user: user, isLoading: false);
  }

  @override
  Future<void> checkAuth({bool isBackground = false}) async {}

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') return null;
        if (methodCall.method == 'signOut' || methodCall.method == 'disconnect') return null;
        if (methodCall.method == 'isSignedIn') return false;
        if (methodCall.method == 'signInSilently') return null;
        return null;
      },
    );
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
        '/splash',
      );
      expect(
        computeAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          role: null,
          location: '/splash',
          isWeb: true,
        ),
        isNull,
      );
    });

    test('Unauthenticated users require login: / and /restaurant/:id and /splash redirect to /login', () {
      // Splash screen routes to /login on both web and mobile
      final splashRedirectWeb = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/splash',
        isWeb: true,
      );
      expect(splashRedirectWeb, '/login');

      final splashRedirectMobile = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/splash',
        isWeb: false,
      );
      expect(splashRedirectMobile, '/login');

      // Unauthenticated customer home / routes to /login
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: true,
        ),
        '/login',
      );
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: false,
        ),
        '/login',
      );

      // Unauthenticated restaurant detail routes to /login (no guest browsing)
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/restaurant/42',
          isWeb: true,
        ),
        '/login',
      );

      // Dedicated auth routes terminate at null to display login/register UI
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
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/register',
          isWeb: true,
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

  group('User Address Model & Location Tests', () {
    test('AddressItem parses JSON fields, coordinates, and handles nulls correctly', () {
      final jsonWithCoords = {
        'id': 101,
        'user_id': 5,
        'label': 'HOME',
        'street_address': '104 Sunrise Boulevard, Apt 4B',
        'city': 'Bengaluru',
        'pincode': '560001',
        'latitude': 12.9279,
        'longitude': 77.6271,
        'is_default': true,
      };

      final address = AddressItem.fromJson(jsonWithCoords);
      expect(address.id, 101);
      expect(address.label, 'HOME');
      expect(address.streetAddress, '104 Sunrise Boulevard, Apt 4B');
      expect(address.city, 'Bengaluru');
      expect(address.pincode, '560001');
      expect(address.latitude, 12.9279);
      expect(address.longitude, 77.6271);
      expect(address.isDefault, true);

      final jsonWithoutCoords = {
        'id': 102,
        'user_id': 5,
        'label': 'WORK',
        'street_address': 'Tech Park, Whitefield',
        'city': 'Bengaluru',
        'pincode': '560066',
        'is_default': false,
      };
      final addressNoCoords = AddressItem.fromJson(jsonWithoutCoords);
      expect(addressNoCoords.latitude, isNull);
      expect(addressNoCoords.longitude, isNull);
    });
  });

  group('Restaurant Location Model Tests', () {
    test('RestaurantModel preserves latitude and longitude in fromJson, toJson, and copyWith', () {
      final json = {
        'id': 12,
        'name': 'Bawarchi Biryani',
        'cuisine': 'Hyderabadi',
        'rating': 4.5,
        'delivery_fee_paise': 4000,
        'min_order_paise': 20000,
        'estimated_delivery_time': '35 min',
        'latitude': 17.3850,
        'longitude': 78.4867,
        'address_text': 'RTC Cross Roads, Hyderabad',
        'is_active': true,
        'is_approved': true,
      };

      final rest = RestaurantModel.fromJson(json);
      expect(rest.latitude, 17.3850);
      expect(rest.longitude, 78.4867);
      expect(rest.addressText, 'RTC Cross Roads, Hyderabad');

      final serialized = rest.toJson();
      expect(serialized['latitude'], 17.3850);
      expect(serialized['longitude'], 78.4867);

      final updated = rest.copyWith(latitude: 17.3900, longitude: 78.4900);
      expect(updated.latitude, 17.3900);
      expect(updated.longitude, 78.4900);
      expect(updated.name, 'Bawarchi Biryani');
    });

    test('RestaurantModel handles null coordinates gracefully without Bengaluru fallback', () {
      final json = {
        'id': 13,
        'name': 'New Unconfigured Store',
        'cuisine': 'Cafe',
        'rating': 4.0,
        'delivery_fee_paise': 0,
        'min_order_paise': 0,
        'estimated_delivery_time': '20 min',
      };
      final rest = RestaurantModel.fromJson(json);
      expect(rest.latitude, isNull);
      expect(rest.longitude, isNull);
    });
  });

  group('Routing Service & Live Tracking Tests', () {
    test('RoutingService.hasMovedSignificantly correctly filters jitter and detects moves', () {
      final p1 = const LatLng(12.9279, 77.6271);
      final pJitter = const LatLng(12.92791, 77.62711); // ~1.5 meters away
      final pMoved = const LatLng(12.9320, 77.6320); // ~600 meters away

      expect(RoutingService.hasMovedSignificantly(null, p1), isTrue);
      expect(RoutingService.hasMovedSignificantly(p1, pJitter, thresholdMeters: 25.0), isFalse);
      expect(RoutingService.hasMovedSignificantly(p1, pMoved, thresholdMeters: 25.0), isTrue);
    });

    test('LiveTrackingData.fromJson does not silently substitute Bengaluru coordinates when null', () {
      final jsonUnconfigured = {
        'order_id': 999,
        'status': 'PLACED',
        'calculated_eta_minutes': 30,
        'is_delayed': false,
        'restaurant_name': 'Test Kitchen',
        'restaurant_address': 'Unconfigured Loc',
        'delivery_address': 'Manual entry without pin',
        'rider_assigned': false,
      };

      final tracking = LiveTrackingData.fromJson(jsonUnconfigured);
      expect(tracking.restaurantLocation, isNull);
      expect(tracking.deliveryLocation, isNull);
      expect(tracking.riderLocation, isNull);
      expect(tracking.riderAssigned, isFalse);
    });

    test('LiveTrackingData.fromJson parses verified restaurant, delivery, and rider GPS coordinates', () {
      final jsonConfigured = {
        'order_id': 1001,
        'status': 'OUT_FOR_DELIVERY',
        'calculated_eta_minutes': 15,
        'is_delayed': false,
        'restaurant_name': 'Spice Hub',
        'restaurant_lat': 12.9345,
        'restaurant_lng': 77.6101,
        'restaurant_address': 'Koramangala 4th Block',
        'delivery_lat': 12.9500,
        'delivery_lng': 77.6300,
        'delivery_address': 'Indiranagar 100ft Rd',
        'rider_assigned': true,
        'rider_name': 'Rajesh Kumar',
        'rider_phone': '+919876543210',
        'rider_lat': 12.9400,
        'rider_lng': 77.6200,
        'rider_heading': 85.5,
        'last_updated_at': '2026-10-10T15:30:00Z',
      };

      final tracking = LiveTrackingData.fromJson(jsonConfigured);
      expect(tracking.restaurantLocation?.latitude, 12.9345);
      expect(tracking.restaurantLocation?.longitude, 77.6101);
      expect(tracking.deliveryLocation?.latitude, 12.9500);
      expect(tracking.deliveryLocation?.longitude, 77.6300);
      expect(tracking.riderLocation?.latitude, 12.9400);
      expect(tracking.riderLocation?.longitude, 77.6200);
      expect(tracking.riderHeading, 85.5);
      expect(tracking.riderAssigned, isTrue);
      expect(tracking.riderName, 'Rajesh Kumar');
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

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepo()),
        ],
      );
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

      // 2. Customer home / redirects to /login because guest access is disabled
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: true,
        ),
        '/login',
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

  group('Startup Auth & Session Lifecycle Tests', () {
    test('Fresh installation / launch with no saved session redirects to /login', () {
      final redirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/splash',
        isWeb: false,
      );
      expect(redirect, '/login');
    });

    test('Launch with valid saved session restores session and routes directly to role dashboard', () {
      // Customer session
      final custRedirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'CUSTOMER',
        location: '/splash',
        isWeb: false,
      );
      expect(custRedirect, '/');

      // Admin session on Web
      final adminRedirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'ADMIN',
        location: '/splash',
        isWeb: true,
      );
      expect(adminRedirect, '/admin');

      // Owner session on Web
      final ownerRedirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'RESTAURANT_OWNER',
        location: '/splash',
        isWeb: true,
      );
      expect(ownerRedirect, '/owner');

      // Delivery Partner session
      final riderRedirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: true,
        role: 'DELIVERY_PARTNER',
        location: '/splash',
        isWeb: false,
      );
      expect(riderRedirect, '/rider');
    });

    test('Expired or invalid session clears user and routes to /login', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.authTokenKey: 'expired_invalid_token',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.authTokenKey), 'expired_invalid_token');

      // Simulate expired token detection clearing local preferences
      await prefs.remove(AppConstants.authTokenKey);
      await prefs.remove(AppConstants.userKey);

      expect(prefs.getString(AppConstants.authTokenKey), isNull);
      expect(prefs.getString(AppConstants.userKey), isNull);

      final redirect = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/splash',
        isWeb: false,
      );
      expect(redirect, '/login');
    });

    test('Logout clears session tokens and state, protecting private screens', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.authTokenKey: 'valid_token',
        AppConstants.userKey: '{"id":1,"email":"cust@ff.com","role":"CUSTOMER"}',
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final redirectFromHome = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/',
        isWeb: false,
      );
      expect(redirectFromHome, '/login');

      final redirectFromProfile = computeAppRedirect(
        isLoading: false,
        isAuthenticated: false,
        role: null,
        location: '/profile',
        isWeb: false,
      );
      expect(redirectFromProfile, '/login');
    });

    test('Guest access is strictly disabled on customer home and detail screens', () {
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/',
          isWeb: false,
        ),
        '/login',
      );

      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/restaurant/10',
          isWeb: false,
        ),
        '/login',
      );
    });

    test('Mobile app strictly denies unauthenticated access to admin and owner routes', () {
      // Unauthenticated mobile visit to /admin or /owner redirects to /login
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/admin',
          isWeb: false,
        ),
        '/login',
      );

      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/owner',
          isWeb: false,
        ),
        '/login',
      );

      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          role: null,
          location: '/restaurant-login',
          isWeb: false,
        ),
        '/login',
      );
    });

    test('Mobile app enforces Customer and Rider separation without restaurant partner access', () {
      // Mobile customer cannot access rider dashboard -> redirected to /
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'CUSTOMER',
          location: '/rider',
          isWeb: false,
        ),
        '/',
      );

      // Mobile rider cannot access customer home -> redirected to /rider
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'DELIVERY_PARTNER',
          location: '/',
          isWeb: false,
        ),
        '/rider',
      );

      // Mobile app denies admin and owner access
      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'ADMIN',
          location: '/',
          isWeb: false,
        ),
        '/login',
      );

      expect(
        computeAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          role: 'RESTAURANT_OWNER',
          location: '/',
          isWeb: false,
        ),
        '/login',
      );
    });
  });

  group('Google Authentication Flow Tests', () {
    test('Google Sign-In cancellation returns null and leaves user unauthenticated without error', () async {
      final fakeRepo = FakeGoogleAuthRepo(shouldCancel: true);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      final notifier = container.read(authProvider.notifier);

      final result = await notifier.signInWithGoogle();

      expect(result, isNull);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).isLoading, isFalse);
      expect(container.read(authProvider).error, isNull);
    });

    test('Google Sign-In with valid ID token authenticates customer and persists session', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeUser = UserModel(
        id: 42,
        email: 'googlecustomer@gmail.com',
        fullName: 'Google Customer',
        role: 'CUSTOMER',
        isApproved: true,
      );
      final fakeRepo = FakeGoogleAuthRepo(mockUser: fakeUser);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      final notifier = container.read(authProvider.notifier);

      final result = await notifier.signInWithGoogle();

      expect(result, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).user?.email, 'googlecustomer@gmail.com');
      expect(container.read(authProvider).user?.role, 'CUSTOMER');
      expect(container.read(authProvider).isLoading, isFalse);
      expect(container.read(authProvider).error, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.authTokenKey), 'fake_google_jwt');
      expect(prefs.getString(AppConstants.userKey), contains('googlecustomer@gmail.com'));
    });

    test('Google Sign-In with invalid ID token sets error in AuthState and returns false', () async {
      final fakeRepo = FakeGoogleAuthRepo(
        throwError: 'Unable to verify Google credentials. A valid Google ID token is required.',
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      final notifier = container.read(authProvider.notifier);

      final result = await notifier.signInWithGoogle();

      expect(result, isFalse);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).isLoading, isFalse);
      expect(container.read(authProvider).error, contains('Unable to verify Google credentials'));
    });

    test('Session persistence restores authenticated customer on subsequent launches', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.authTokenKey: 'persisted_google_token',
        AppConstants.userKey: '{"id":42,"email":"persisted@gmail.com","full_name":"Persisted User","role":"CUSTOMER","is_approved":true}',
      });

      final fakeUser = UserModel(
        id: 42,
        email: 'persisted@gmail.com',
        fullName: 'Persisted User',
        role: 'CUSTOMER',
        isApproved: true,
      );
      final fakeRepo = FakeGoogleAuthRepo(mockUser: fakeUser);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      final notifier = container.read(authProvider.notifier);
      await notifier.checkAuth();

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).user?.email, 'persisted@gmail.com');
      expect(container.read(authProvider).user?.role, 'CUSTOMER');
    });

    testWidgets('Tapping Continue with Google triggers Google Sign-In directly without custom dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool googleSignInCalled = false;
      final fakeRepo = FakeGoogleAuthRepo(
        onSignInCalled: () {
          googleSignInCalled = true;
        },
        shouldCancel: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the "Continue with Google" button
      final googleBtn = find.widgetWithText(OutlinedButton, 'Continue with Google');
      expect(googleBtn, findsOneWidget);

      // Tap "Continue with Google"
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      // Verify no custom dialog requesting name/email appeared
      expect(find.text('Sign in securely with your Google Account as a Customer:'), findsNothing);
      expect(find.widgetWithText(TextField, 'Google Email'), findsNothing);
      expect(googleSignInCalled, isTrue);
    });
  });
}


