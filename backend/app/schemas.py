from pydantic import BaseModel, EmailStr, ConfigDict
from typing import List, Optional, Dict, Any
from datetime import datetime
from .models import UserRole, OrderStatus, DeliveryAssignmentStatus, PaymentStatus

# User Schemas
class UserBase(BaseModel):
    email: EmailStr
    full_name: str
    phone: Optional[str] = None
    role: Optional[UserRole] = UserRole.CUSTOMER

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int
    is_active: bool
    is_approved: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

class TokenData(BaseModel):
    email: Optional[str] = None

# Address Schemas
class AddressCreate(BaseModel):
    label: str = "HOME"
    street_address: str
    building_floor: Optional[str] = None
    landmark: Optional[str] = None
    city: str = "Innovation City"
    state: str = "State"
    pincode: str = "100001"
    latitude: Optional[float] = 12.9716
    longitude: Optional[float] = 77.5946
    is_default: bool = False

class AddressResponse(AddressCreate):
    id: int
    user_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Food & Restaurant Schemas
class FoodItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price_paise: int
    is_veg: bool = True
    image_url: Optional[str] = None
    is_available: bool = True

class FoodItemCreate(FoodItemBase):
    category_id: Optional[int] = None

class FoodItemResponse(FoodItemBase):
    id: int
    restaurant_id: int
    category_id: Optional[int] = None
    model_config = ConfigDict(from_attributes=True)

class FoodCategoryBase(BaseModel):
    name: str

class FoodCategoryCreate(FoodCategoryBase):
    pass

class FoodCategoryResponse(FoodCategoryBase):
    id: int
    restaurant_id: int
    foods: List[FoodItemResponse] = []
    model_config = ConfigDict(from_attributes=True)

class RestaurantBase(BaseModel):
    name: str
    description: Optional[str] = None
    cuisine: str
    image_url: Optional[str] = None
    delivery_fee_paise: int = 3000
    min_order_paise: int = 10000
    estimated_delivery_time: str = "25-35 min"
    latitude: Optional[float] = 12.9352
    longitude: Optional[float] = 77.6245
    address_text: Optional[str] = "Block 4, Koramangala Food Street"
    is_open: bool = True
    opening_time: str = "09:00 AM"
    closing_time: str = "11:00 PM"
    prep_time_minutes: int = 25

class RestaurantCreate(RestaurantBase):
    pass

class AdminRestaurantCreate(RestaurantBase):
    owner_id: Optional[int] = None
    owner_email: Optional[EmailStr] = None
    owner_full_name: Optional[str] = None
    owner_password: Optional[str] = None
    owner_phone: Optional[str] = None

class OwnerRegistrationRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    phone: Optional[str] = None
    restaurant_name: str
    cuisine: str
    description: Optional[str] = None
    address_text: Optional[str] = None
    image_url: Optional[str] = None
    delivery_fee_paise: int = 3000
    min_order_paise: int = 10000
    estimated_delivery_time: str = "25-35 min"

class RestaurantResponse(RestaurantBase):
    id: int
    owner_id: Optional[int] = None
    rating: float
    is_active: bool
    is_approved: bool
    is_favorite: Optional[bool] = False
    active_offers_count: Optional[int] = 0
    model_config = ConfigDict(from_attributes=True)

class RestaurantDetailResponse(RestaurantResponse):
    categories: List[FoodCategoryResponse] = []
    foods: List[FoodItemResponse] = []
    model_config = ConfigDict(from_attributes=True)

class RestaurantSettingsUpdate(BaseModel):
    is_open: Optional[bool] = None
    prep_time_minutes: Optional[int] = None
    opening_time: Optional[str] = None
    closing_time: Optional[str] = None
    estimated_delivery_time: Optional[str] = None
    delivery_fee_paise: Optional[int] = None
    min_order_paise: Optional[int] = None

# Coupon & Promotion Schemas
class CouponBase(BaseModel):
    code: str
    title: Optional[str] = None
    description: Optional[str] = None
    discount_type: str = "PERCENTAGE"  # PERCENTAGE, FLAT, FREE_DELIVERY
    discount_value: int  # e.g., 20 for 20% or 5000 for ₹50 FLAT
    min_order_paise: int = 0
    max_discount_paise: int = 10000
    usage_limit: int = 100
    per_user_limit: int = 1
    first_order_only: bool = False
    is_active: bool = True
    restaurant_id: Optional[int] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None

class CouponCreate(CouponBase):
    pass

class CouponResponse(CouponBase):
    id: int
    used_count: int
    created_at: datetime
    restaurant_name: Optional[str] = None
    is_expired: bool = False
    model_config = ConfigDict(from_attributes=True)

class CouponValidateRequest(BaseModel):
    code: str
    restaurant_id: Optional[int] = None
    subtotal_paise: int
    delivery_fee_paise: int = 3000

class CouponValidateResponse(BaseModel):
    valid: bool
    discount_paise: int
    message: str
    coupon: Optional[CouponResponse] = None

class CouponAnalyticsResponse(BaseModel):
    coupon: CouponResponse
    total_redemptions: int
    total_discount_given_paise: int
    total_orders_generated: int
    total_gross_revenue_paise: int

# Cart Schemas
class CartItemAdd(BaseModel):
    food_item_id: int
    quantity: int = 1
    special_instructions: Optional[str] = None

class CartItemUpdate(BaseModel):
    quantity: int

class CartItemResponse(BaseModel):
    id: int
    food_item: FoodItemResponse
    quantity: int
    special_instructions: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class CartSummaryResponse(BaseModel):
    items: List[CartItemResponse]
    restaurant: Optional[RestaurantResponse]
    subtotal_paise: int
    delivery_fee_paise: int
    tax_paise: int
    discount_paise: int
    total_paise: int
    applied_coupon: Optional[CouponResponse] = None

# Order Schemas
class OrderCreate(BaseModel):
    delivery_address: str
    delivery_lat: Optional[float] = 12.9716
    delivery_lng: Optional[float] = 77.5946
    payment_method: str = "COD"
    coupon_code: Optional[str] = None

class OrderItemResponse(BaseModel):
    id: int
    food_item: FoodItemResponse
    quantity: int
    price_paise: int
    model_config = ConfigDict(from_attributes=True)

class OrderStatusHistoryResponse(BaseModel):
    id: int
    status: OrderStatus
    previous_status: Optional[OrderStatus] = None
    changed_at: datetime
    actor_role: str
    reason: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class OrderResponse(BaseModel):
    id: int
    user_id: int
    restaurant: RestaurantResponse
    status: OrderStatus
    subtotal_paise: int
    delivery_fee_paise: int
    tax_paise: int
    discount_paise: int
    total_paise: int
    coupon_code: Optional[str] = None
    delivery_address: str
    delivery_lat: float
    delivery_lng: float
    payment_method: str
    payment_status: str
    cancelled_by: Optional[str] = None
    cancellation_reason: Optional[str] = None
    cancelled_at: Optional[datetime] = None
    is_refunded: bool = False
    calculated_eta_minutes: int
    is_delayed: bool
    created_at: datetime
    items: List[OrderItemResponse]
    status_history: List[OrderStatusHistoryResponse] = []
    model_config = ConfigDict(from_attributes=True)

class OrderStatusUpdate(BaseModel):
    status: OrderStatus
    reason: Optional[str] = None

class OrderCancelRequest(BaseModel):
    reason: str

class ReorderResponse(BaseModel):
    success: bool
    message: str
    added_items_count: int
    unavailable_items_count: int
    unavailable_items: List[str] = []
    cart_summary: CartSummaryResponse

# Live GPS Location Update Schema
class LocationUpdateSchema(BaseModel):
    order_id: int
    latitude: float
    longitude: float
    accuracy: Optional[float] = 5.0
    heading: Optional[float] = 0.0
    speed: Optional[float] = 0.0

class LiveTrackingResponse(BaseModel):
    order_id: int
    status: OrderStatus
    calculated_eta_minutes: int
    is_delayed: bool

    # Destination & Origin
    restaurant_name: str
    restaurant_lat: float
    restaurant_lng: float
    restaurant_address: str

    delivery_lat: float
    delivery_lng: float
    delivery_address: str

    # Rider Live Location
    rider_assigned: bool
    rider_name: Optional[str] = None
    rider_phone: Optional[str] = None
    rider_lat: Optional[float] = None
    rider_lng: Optional[float] = None
    rider_heading: Optional[float] = 0.0
    rider_speed: Optional[float] = 0.0
    last_updated_at: Optional[datetime] = None

# Delivery Partner Schemas
class DeliveryPartnerProfileCreate(BaseModel):
    vehicle_type: str = "SCOOTER"
    vehicle_number: str

class DeliveryPartnerResponse(BaseModel):
    id: int
    user_id: int
    vehicle_type: str
    vehicle_number: str
    is_online: bool
    is_verified: bool
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None
    total_earnings_paise: int
    user: UserResponse
    model_config = ConfigDict(from_attributes=True)

class DeliveryAssignmentResponse(BaseModel):
    id: int
    order: OrderResponse
    status: DeliveryAssignmentStatus
    assigned_at: datetime
    picked_up_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)

class DeliveryStatusUpdate(BaseModel):
    status: DeliveryAssignmentStatus

# Reviews
class ReviewCreate(BaseModel):
    restaurant_id: int
    order_id: int
    rating: float
    comment: Optional[str] = None

class ReviewResponse(ReviewCreate):
    id: int
    user_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Notifications
class NotificationResponse(BaseModel):
    id: int
    user_id: int
    title: str
    message: str
    type: str
    order_id: Optional[int] = None
    is_read: bool
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Favorites
class FavoriteResponse(BaseModel):
    id: int
    restaurant_id: int
    restaurant: RestaurantResponse
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Admin & Owner Analytics
class AdminMetricsResponse(BaseModel):
    total_users: int
    total_restaurants: int
    pending_restaurant_approvals: int
    total_delivery_partners: int
    pending_partner_approvals: int
    total_orders: int
    active_orders: int
    total_revenue_paise: int

class AdminAnalyticsResponse(BaseModel):
    timeframe: str
    total_orders: int
    active_orders: int
    completed_orders: int
    cancelled_orders: int
    gross_order_value_paise: int
    promotion_discounts_paise: int
    net_revenue_paise: int
    total_restaurants: int
    active_delivery_partners: int
    total_customers: int

class OwnerAnalyticsResponse(BaseModel):
    today_orders: int
    today_revenue_paise: int
    weekly_revenue_paise: int
    monthly_revenue_paise: int
    total_orders: int
    average_order_value_paise: int
    cancellation_rate_percent: float
    order_status_distribution: Dict[str, int]
    best_selling_items: List[Dict[str, Any]]
