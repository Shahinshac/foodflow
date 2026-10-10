class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final bool isActive;
  final bool isApproved;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.isActive = true,
    this.isApproved = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      phone: json['phone'],
      role: json['role'] ?? 'CUSTOMER',
      isActive: json['is_active'] ?? true,
      isApproved: json['is_approved'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'role': role,
        'is_active': isActive,
        'is_approved': isApproved,
      };
}

class RestaurantModel {
  final int id;
  final int? ownerId;
  final String name;
  final String? description;
  final String cuisine;
  final String? imageUrl;
  final double rating;
  final int deliveryFeePaise;
  final int minOrderPaise;
  final String estimatedDeliveryTime;
  final bool isActive;
  final bool isApproved;
  final bool isOpen;
  final int prepTimeMinutes;
  final String? addressText;
  final bool isFavorite;
  final int activeOffersCount;

  RestaurantModel({
    required this.id,
    this.ownerId,
    required this.name,
    this.description,
    required this.cuisine,
    this.imageUrl,
    required this.rating,
    required this.deliveryFeePaise,
    required this.minOrderPaise,
    required this.estimatedDeliveryTime,
    required this.isActive,
    this.isApproved = true,
    this.isOpen = true,
    this.prepTimeMinutes = 25,
    this.addressText,
    this.isFavorite = false,
    this.activeOffersCount = 0,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    return RestaurantModel(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'],
      cuisine: json['cuisine'],
      imageUrl: json['image_url'],
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      deliveryFeePaise: json['delivery_fee_paise'] ?? 3000,
      minOrderPaise: json['min_order_paise'] ?? 10000,
      estimatedDeliveryTime: json['estimated_delivery_time'] ?? '25-35 min',
      isActive: json['is_active'] ?? true,
      isApproved: json['is_approved'] ?? true,
      isOpen: json['is_open'] ?? true,
      prepTimeMinutes: json['prep_time_minutes'] ?? 25,
      addressText: json['address_text'],
      isFavorite: json['is_favorite'] ?? false,
      activeOffersCount: json['active_offers_count'] ?? 0,
    );
  }

  RestaurantModel copyWith({
    bool? isFavorite,
    bool? isOpen,
    bool? isActive,
    bool? isApproved,
    int? activeOffersCount,
  }) {
    return RestaurantModel(
      id: id,
      ownerId: ownerId,
      name: name,
      description: description,
      cuisine: cuisine,
      imageUrl: imageUrl,
      rating: rating,
      deliveryFeePaise: deliveryFeePaise,
      minOrderPaise: minOrderPaise,
      estimatedDeliveryTime: estimatedDeliveryTime,
      isActive: isActive ?? this.isActive,
      isApproved: isApproved ?? this.isApproved,
      isOpen: isOpen ?? this.isOpen,
      prepTimeMinutes: prepTimeMinutes,
      addressText: addressText,
      isFavorite: isFavorite ?? this.isFavorite,
      activeOffersCount: activeOffersCount ?? this.activeOffersCount,
    );
  }
}

class FoodItemModel {
  final int id;
  final int restaurantId;
  final int? categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final int pricePaise;
  final bool isVeg;
  final String? imageUrl;
  final bool isAvailable;

  FoodItemModel({
    required this.id,
    required this.restaurantId,
    this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.pricePaise,
    required this.isVeg,
    this.imageUrl,
    required this.isAvailable,
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    return FoodItemModel(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      categoryId: json['category_id'],
      categoryName: json['category_name'] ?? json['category']?['name'],
      name: json['name'],
      description: json['description'],
      pricePaise: json['price_paise'],
      isVeg: json['is_veg'] ?? true,
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
    );
  }
}

class CartItemModel {
  final int id;
  final FoodItemModel foodItem;
  final int quantity;
  final String? specialInstructions;

  CartItemModel({
    required this.id,
    required this.foodItem,
    required this.quantity,
    this.specialInstructions,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'],
      foodItem: FoodItemModel.fromJson(json['food_item']),
      quantity: json['quantity'],
      specialInstructions: json['special_instructions'],
    );
  }
}

class CouponModel {
  final int id;
  final String code;
  final String title;
  final String description;
  final String discountType; // PERCENTAGE, FLAT, FREE_DELIVERY
  final int discountValue;
  final int minOrderPaise;
  final int maxDiscountPaise;
  final int usageLimit;
  final int usedCount;
  final int perUserLimit;
  final bool firstOrderOnly;
  final bool isActive;
  final int? restaurantId;
  final String? restaurantName;
  final bool isExpired;

  CouponModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderPaise,
    required this.maxDiscountPaise,
    required this.usageLimit,
    required this.usedCount,
    required this.perUserLimit,
    required this.firstOrderOnly,
    required this.isActive,
    this.restaurantId,
    this.restaurantName,
    this.isExpired = false,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'],
      code: json['code'],
      title: json['title'] ?? json['code'],
      description: json['description'] ?? '',
      discountType: json['discount_type'] ?? 'PERCENTAGE',
      discountValue: json['discount_value'] ?? 0,
      minOrderPaise: json['min_order_paise'] ?? 0,
      maxDiscountPaise: json['max_discount_paise'] ?? 10000,
      usageLimit: json['usage_limit'] ?? 100,
      usedCount: json['used_count'] ?? 0,
      perUserLimit: json['per_user_limit'] ?? 1,
      firstOrderOnly: json['first_order_only'] ?? false,
      isActive: json['is_active'] ?? true,
      restaurantId: json['restaurant_id'],
      restaurantName: json['restaurant_name'],
      isExpired: json['is_expired'] ?? false,
    );
  }
}

class CouponValidationResult {
  final bool valid;
  final int discountPaise;
  final String message;
  final CouponModel? coupon;

  CouponValidationResult({
    required this.valid,
    required this.discountPaise,
    required this.message,
    this.coupon,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      valid: json['valid'] ?? false,
      discountPaise: json['discount_paise'] ?? 0,
      message: json['message'] ?? '',
      coupon: json['coupon'] != null ? CouponModel.fromJson(json['coupon']) : null,
    );
  }
}

class CartSummaryModel {
  final List<CartItemModel> items;
  final RestaurantModel? restaurant;
  final int subtotalPaise;
  final int deliveryFeePaise;
  final int taxPaise;
  final int discountPaise;
  final int totalPaise;
  final CouponModel? appliedCoupon;

  CartSummaryModel({
    required this.items,
    this.restaurant,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.taxPaise,
    required this.discountPaise,
    required this.totalPaise,
    this.appliedCoupon,
  });

  factory CartSummaryModel.fromJson(Map<String, dynamic> json) {
    return CartSummaryModel(
      items: (json['items'] as List)
          .map((item) => CartItemModel.fromJson(item))
          .toList(),
      restaurant: json['restaurant'] != null
          ? RestaurantModel.fromJson(json['restaurant'])
          : null,
      subtotalPaise: json['subtotal_paise'] ?? 0,
      deliveryFeePaise: json['delivery_fee_paise'] ?? 0,
      taxPaise: json['tax_paise'] ?? 0,
      discountPaise: json['discount_paise'] ?? 0,
      totalPaise: json['total_paise'] ?? 0,
      appliedCoupon: json['applied_coupon'] != null ? CouponModel.fromJson(json['applied_coupon']) : null,
    );
  }
}

class OrderItemModel {
  final int id;
  final FoodItemModel foodItem;
  final int quantity;
  final int pricePaise;

  OrderItemModel({
    required this.id,
    required this.foodItem,
    required this.quantity,
    required this.pricePaise,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      foodItem: FoodItemModel.fromJson(json['food_item']),
      quantity: json['quantity'],
      pricePaise: json['price_paise'],
    );
  }
}

class OrderModel {
  final int id;
  final RestaurantModel restaurant;
  final String status;
  final int subtotalPaise;
  final int deliveryFeePaise;
  final int taxPaise;
  final int discountPaise;
  final int totalPaise;
  final String? couponCode;
  final String deliveryAddress;
  final String paymentMethod;
  final String paymentStatus;
  final String? cancelledBy;
  final String? cancellationReason;
  final bool isRefunded;
  final int calculatedEtaMinutes;
  final String createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.restaurant,
    required this.status,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.taxPaise,
    required this.discountPaise,
    required this.totalPaise,
    this.couponCode,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.cancelledBy,
    this.cancellationReason,
    this.isRefunded = false,
    this.calculatedEtaMinutes = 35,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      restaurant: RestaurantModel.fromJson(json['restaurant']),
      status: json['status'],
      subtotalPaise: json['subtotal_paise'],
      deliveryFeePaise: json['delivery_fee_paise'],
      taxPaise: json['tax_paise'],
      discountPaise: json['discount_paise'],
      totalPaise: json['total_paise'],
      couponCode: json['coupon_code'],
      deliveryAddress: json['delivery_address'],
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
      cancelledBy: json['cancelled_by'],
      cancellationReason: json['cancellation_reason'],
      isRefunded: json['is_refunded'] ?? false,
      calculatedEtaMinutes: json['calculated_eta_minutes'] ?? 35,
      createdAt: json['created_at'],
      items: (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item))
          .toList(),
    );
  }
}

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final int? orderId;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'] ?? 'ORDER_UPDATE',
      orderId: json['order_id'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ReorderResultModel {
  final bool success;
  final String message;
  final int addedItemsCount;
  final int unavailableItemsCount;
  final List<String> unavailableItems;
  final CartSummaryModel cartSummary;

  ReorderResultModel({
    required this.success,
    required this.message,
    required this.addedItemsCount,
    required this.unavailableItemsCount,
    required this.unavailableItems,
    required this.cartSummary,
  });

  factory ReorderResultModel.fromJson(Map<String, dynamic> json) {
    return ReorderResultModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      addedItemsCount: json['added_items_count'] ?? 0,
      unavailableItemsCount: json['unavailable_items_count'] ?? 0,
      unavailableItems: List<String>.from(json['unavailable_items'] ?? []),
      cartSummary: CartSummaryModel.fromJson(json['cart_summary']),
    );
  }
}
