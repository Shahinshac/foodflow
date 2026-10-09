import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:foodflow/core/theme/app_colors.dart';
import 'package:foodflow/core/theme/app_theme.dart';
import 'package:foodflow/core/utils/currency_formatter.dart';
import 'package:foodflow/features/restaurant/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(AppColors.veg, const Color(0xFF27AE60));
      expect(AppColors.nonVeg, const Color(0xFFE74C3C));
      expect(AppTheme.lightTheme.colorScheme.primary, AppColors.primary);
      expect(AppTheme.darkTheme.colorScheme.primary, AppColors.primary);
    });
  });
}
