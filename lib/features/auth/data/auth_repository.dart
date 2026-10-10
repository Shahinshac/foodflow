import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../restaurant/domain/models.dart';

class AuthRepository {
  final ApiClient apiClient;
  final GoogleSignIn _googleSignIn;

  AuthRepository(
    this.apiClient, {
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId: kIsWeb ? AppConstants.googleWebClientId : null,
              serverClientId: AppConstants.googleWebClientId,
              scopes: const ['email', 'profile'],
            );

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username': email.trim().toLowerCase(),
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      final token = response.data['access_token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.authTokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server connection timed out. Please check network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Unable to reach server at ${AppConstants.baseUrl}. Check Wi-Fi.');
      }
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      String message = 'Incorrect email or password';
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail[0]['msg'] ?? 'Validation error';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/register',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone?.trim(),
          'role': 'CUSTOMER', // Customer registration strictly enforces CUSTOMER role
        },
      );

      final token = response.data['access_token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.authTokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server connection timed out. Please check network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Unable to reach server at ${AppConstants.baseUrl}. Check Wi-Fi.');
      }
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      String message = 'Registration failed';
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail[0]['msg'] ?? 'Registration failed';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel> registerOwner({
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
    try {
      final response = await apiClient.dio.post(
        '/auth/register-owner',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone?.trim(),
          'restaurant_name': restaurantName.trim(),
          'cuisine': cuisine.trim(),
          'description': description?.trim(),
          'address_text': addressText?.trim(),
          'image_url': imageUrl,
          'delivery_fee_paise': deliveryFeePaise,
          'min_order_paise': minOrderPaise,
          'estimated_delivery_time': estimatedDeliveryTime,
        },
      );

      final token = response.data['access_token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.authTokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server connection timed out. Please check network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Unable to reach server at ${AppConstants.baseUrl}. Check Wi-Fi.');
      }
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      String message = 'Owner registration failed';
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail[0]['msg'] ?? 'Owner registration failed';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel> registerRider({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String vehicleType = 'SCOOTER',
    String? vehicleNumber,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/register-rider',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone?.trim(),
          'vehicle_type': vehicleType,
          'vehicle_number': (vehicleNumber != null && vehicleNumber.trim().isNotEmpty)
              ? vehicleNumber.trim().toUpperCase()
              : (vehicleType == 'BICYCLE' ? 'BICYCLE' : 'NOT_SPECIFIED'),
        },
      );

      final token = response.data['access_token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.authTokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server connection timed out. Please check network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Unable to reach server at ${AppConstants.baseUrl}. Check Wi-Fi.');
      }
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      String message = 'Rider registration failed';
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail[0]['msg'] ?? 'Rider registration failed';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel?>? _inFlightCurrentUserFuture;

  Future<UserModel?> getCurrentUser() async {
    if (_inFlightCurrentUserFuture != null) {
      return _inFlightCurrentUserFuture;
    }
    _inFlightCurrentUserFuture = _performGetCurrentUser();
    try {
      return await _inFlightCurrentUserFuture;
    } finally {
      _inFlightCurrentUserFuture = null;
    }
  }

  Future<UserModel?> _performGetCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.authTokenKey);
    if (token == null || token.isEmpty) return null;

    UserModel? cachedUser;
    final cachedJson = prefs.getString(AppConstants.userKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        cachedUser = UserModel.fromJson(jsonDecode(cachedJson));
      } catch (_) {}
    }

    try {
      final response = await apiClient.dio.get('/auth/me');
      final user = UserModel.fromJson(response.data);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // True unrecoverable auth failure (token expired/revoked)
        await logout();
        return null;
      }
      // Transient error (network timeout, offline, 502/503 cold start):
      // Return cached user to preserve session and avoid spurious Login redirects
      if (cachedUser != null) {
        return cachedUser;
      }
      return null;
    } catch (_) {
      if (cachedUser != null) {
        return cachedUser;
      }
      return null;
    }
  }

  Future<UserModel> loginWithGoogle({
    String? idToken,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/google',
        data: {
          'id_token': idToken,
          'email': email?.trim().toLowerCase(),
          'full_name': fullName?.trim(),
          'avatar_url': avatarUrl,
        },
      );

      final token = response.data['access_token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.authTokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server connection timed out. Please check network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Unable to reach server at ${AppConstants.baseUrl}. Check Wi-Fi.');
      }
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      String message = 'Google sign in failed';
      if (detail is String) {
        message = detail;
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the native Google account chooser
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google Sign-In failed: Unable to obtain Google ID token.');
      }

      return await loginWithGoogle(
        idToken: idToken,
        email: account.email,
        fullName: account.displayName,
        avatarUrl: account.photoUrl,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server connection timed out. Please check network.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Unable to reach server at ${AppConstants.baseUrl}. Check Wi-Fi.');
      }
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      String message = 'Google sign in failed';
      if (detail is String) {
        message = detail;
      }
      throw Exception(message);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('sign_in_canceled') ||
          errStr.contains('canceled') ||
          errStr.contains('cancelled') ||
          errStr.contains('12501')) {
        return null;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove(AppConstants.userKey);
    try {
      await _googleSignIn.signOut().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }
}
