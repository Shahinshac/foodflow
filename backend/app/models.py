import enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Enum, Float, Text, UniqueConstraint, JSON
from sqlalchemy.orm import relationship
from .database import Base

class UserRole(str, enum.Enum):
    CUSTOMER = "CUSTOMER"
    RESTAURANT_OWNER = "RESTAURANT_OWNER"
    DELIVERY_PARTNER = "DELIVERY_PARTNER"
    ADMIN = "ADMIN"

class OrderStatus(str, enum.Enum):
    PENDING = "PENDING"
    PLACED = "PLACED"
    PAYMENT_PENDING = "PAYMENT_PENDING"
    PAYMENT_SUCCESS = "PAYMENT_SUCCESS"
    RESTAURANT_CONFIRMED = "RESTAURANT_CONFIRMED"
    PREPARING = "PREPARING"
    READY_FOR_PICKUP = "READY_FOR_PICKUP"
    DELIVERY_PARTNER_ASSIGNED = "DELIVERY_PARTNER_ASSIGNED"
    DELIVERY_PARTNER_AT_RESTAURANT = "DELIVERY_PARTNER_AT_RESTAURANT"
    PICKED_UP = "PICKED_UP"
    OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY"
    NEAR_CUSTOMER = "NEAR_CUSTOMER"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"
    REJECTED = "REJECTED"
    PAYMENT_FAILED = "PAYMENT_FAILED"
    REFUNDED = "REFUNDED"

class DeliveryAssignmentStatus(str, enum.Enum):
    ASSIGNED = "ASSIGNED"
    ACCEPTED = "ACCEPTED"
    ARRIVED_AT_RESTAURANT = "ARRIVED_AT_RESTAURANT"
    PICKED_UP = "PICKED_UP"
    OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY"
    ARRIVED_AT_CUSTOMER = "ARRIVED_AT_CUSTOMER"
    DELIVERED = "DELIVERED"
    REJECTED = "REJECTED"

class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    role = Column(Enum(UserRole), default=UserRole.CUSTOMER, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_approved = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    restaurants = relationship("Restaurant", back_populates="owner")
    orders = relationship("Order", back_populates="user")
    cart_items = relationship("CartItem", back_populates="user", cascade="all, delete-orphan")
    addresses = relationship("UserAddress", back_populates="user", cascade="all, delete-orphan")
    delivery_profile = relationship("DeliveryPartner", back_populates="user", uselist=False)
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    favorites = relationship("Favorite", back_populates="user", cascade="all, delete-orphan")

class UserAddress(Base):
    __tablename__ = "user_addresses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    label = Column(String, default="HOME") # HOME, WORK, OTHER
    street_address = Column(String, nullable=False)
    building_floor = Column(String, nullable=True)
    landmark = Column(String, nullable=True)
    city = Column(String, default="Innovation City")
    state = Column(String, default="State")
    pincode = Column(String, default="100001")
    latitude = Column(Float, default=12.9716)
    longitude = Column(Float, default=77.5946)
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="addresses")

class Restaurant(Base):
    __tablename__ = "restaurants"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    name = Column(String, index=True, nullable=False)
    description = Column(Text, nullable=True)
    cuisine = Column(String, index=True, nullable=False)
    image_url = Column(String, nullable=True)
    rating = Column(Float, default=4.8)
    delivery_fee_paise = Column(Integer, default=3000)
    min_order_paise = Column(Integer, default=10000)
    estimated_delivery_time = Column(String, default="25-35 min")
    latitude = Column(Float, default=12.9352)
    longitude = Column(Float, default=77.6245)
    address_text = Column(String, default="Block 4, Koramangala Food Street")
    is_active = Column(Boolean, default=True)
    is_approved = Column(Boolean, default=True)
    is_open = Column(Boolean, default=True)
    opening_time = Column(String, default="09:00 AM")
    closing_time = Column(String, default="11:00 PM")
    prep_time_minutes = Column(Integer, default=25)
    upi_id = Column(String, nullable=True)
    rejection_reason = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner = relationship("User", back_populates="restaurants")
    categories = relationship("FoodCategory", back_populates="restaurant", cascade="all, delete-orphan")
    foods = relationship("FoodItem", back_populates="restaurant", cascade="all, delete-orphan")
    orders = relationship("Order", back_populates="restaurant")
    coupons = relationship("Coupon", back_populates="restaurant")
    favorites = relationship("Favorite", back_populates="restaurant", cascade="all, delete-orphan")

class FoodCategory(Base):
    __tablename__ = "food_categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False)

    restaurant = relationship("Restaurant", back_populates="categories")
    foods = relationship("FoodItem", back_populates="category")

class FoodItem(Base):
    __tablename__ = "food_items"

    id = Column(Integer, primary_key=True, index=True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False)
    category_id = Column(Integer, ForeignKey("food_categories.id"), nullable=True)
    name = Column(String, index=True, nullable=False)
    description = Column(Text, nullable=True)
    price_paise = Column(Integer, nullable=False)
    is_veg = Column(Boolean, default=True)
    image_url = Column(String, nullable=True)
    is_available = Column(Boolean, default=True)
    portions = Column(JSON, nullable=True)

    restaurant = relationship("Restaurant", back_populates="foods")
    category = relationship("FoodCategory", back_populates="foods")

class CartItem(Base):
    __tablename__ = "cart_items"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    food_item_id = Column(Integer, ForeignKey("food_items.id"), nullable=False)
    quantity = Column(Integer, default=1, nullable=False)
    portion = Column(String, default="FULL")
    price_paise = Column(Integer, nullable=True)
    special_instructions = Column(String, nullable=True)

    user = relationship("User", back_populates="cart_items")
    food_item = relationship("FoodItem")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False)
    status = Column(Enum(OrderStatus), default=OrderStatus.PLACED, nullable=False)

    subtotal_paise = Column(Integer, nullable=False)
    delivery_fee_paise = Column(Integer, nullable=False)
    tax_paise = Column(Integer, nullable=False)
    discount_paise = Column(Integer, default=0)
    total_paise = Column(Integer, nullable=False)

    coupon_id = Column(Integer, ForeignKey("coupons.id"), nullable=True)
    coupon_code = Column(String, nullable=True)

    # Historical Address Snapshot
    delivery_address = Column(String, nullable=False)
    delivery_lat = Column(Float, default=12.9716)
    delivery_lng = Column(Float, default=77.5946)

    payment_method = Column(String, default="COD")
    payment_status = Column(String, default="PENDING")

    # Cancellation Snapshot
    cancelled_by = Column(String, nullable=True) # CUSTOMER, RESTAURANT, ADMIN
    cancellation_reason = Column(String, nullable=True)
    cancelled_at = Column(DateTime, nullable=True)
    is_refunded = Column(Boolean, default=False)

    # ETA & Metrics
    prep_estimate_minutes = Column(Integer, default=20)
    travel_estimate_minutes = Column(Integer, default=15)
    calculated_eta_minutes = Column(Integer, default=35)
    is_delayed = Column(Boolean, default=False)

    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="orders")
    restaurant = relationship("Restaurant", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="order", cascade="all, delete-orphan")
    delivery_assignments = relationship("DeliveryAssignment", back_populates="order", cascade="all, delete-orphan")
    status_history = relationship("OrderStatusHistory", back_populates="order", cascade="all, delete-orphan")
    location_logs = relationship("DeliveryLocationLog", back_populates="order", cascade="all, delete-orphan")
    coupon_usage = relationship("CouponUsage", back_populates="order", uselist=False)

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    food_item_id = Column(Integer, ForeignKey("food_items.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    portion = Column(String, default="FULL")
    price_paise = Column(Integer, nullable=False)

    order = relationship("Order", back_populates="items")
    food_item = relationship("FoodItem")

class OrderStatusHistory(Base):
    __tablename__ = "order_status_history"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    status = Column(Enum(OrderStatus), nullable=False)
    previous_status = Column(Enum(OrderStatus), nullable=True)
    changed_at = Column(DateTime, default=datetime.utcnow)
    changed_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    actor_role = Column(String, nullable=False)
    reason = Column(String, nullable=True)

    order = relationship("Order", back_populates="status_history")

class DeliveryPartner(Base):
    __tablename__ = "delivery_partners"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    vehicle_type = Column(String, default="SCOOTER")
    vehicle_number = Column(String, nullable=False)
    is_online = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=True)
    current_lat = Column(Float, default=12.9500)
    current_lng = Column(Float, default=77.6100)
    heading = Column(Float, default=0.0)
    speed = Column(Float, default=0.0)
    last_location_update = Column(DateTime, default=datetime.utcnow)
    total_earnings_paise = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="delivery_profile")
    assignments = relationship("DeliveryAssignment", back_populates="delivery_partner")

class DeliveryLocationLog(Base):
    __tablename__ = "delivery_location_logs"

    id = Column(Integer, primary_key=True, index=True)
    delivery_partner_id = Column(Integer, ForeignKey("delivery_partners.id"), nullable=False)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, default=5.0)
    heading = Column(Float, default=0.0)
    speed = Column(Float, default=0.0)
    timestamp = Column(DateTime, default=datetime.utcnow)

    order = relationship("Order", back_populates="location_logs")

class DeliveryAssignment(Base):
    __tablename__ = "delivery_assignments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    delivery_partner_id = Column(Integer, ForeignKey("delivery_partners.id"), nullable=False)
    status = Column(Enum(DeliveryAssignmentStatus), default=DeliveryAssignmentStatus.ASSIGNED, nullable=False)
    assigned_at = Column(DateTime, default=datetime.utcnow)
    picked_up_at = Column(DateTime, nullable=True)
    delivered_at = Column(DateTime, nullable=True)

    order = relationship("Order", back_populates="delivery_assignments")
    delivery_partner = relationship("DeliveryPartner", back_populates="assignments")

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    transaction_id = Column(String, unique=True, index=True, nullable=False)
    payment_method = Column(String, default="COD")
    amount_paise = Column(Integer, nullable=False)
    status = Column(Enum(PaymentStatus), default=PaymentStatus.PENDING, nullable=False)
    gateway_response = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    order = relationship("Order", back_populates="payments")

class Coupon(Base):
    __tablename__ = "coupons"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    title = Column(String, nullable=True)
    description = Column(String, nullable=True)
    discount_type = Column(String, default="PERCENTAGE") # PERCENTAGE, FLAT, FREE_DELIVERY
    discount_value = Column(Integer, nullable=False) # e.g. 20 for 20% or 5000 for ₹50 flat
    min_order_paise = Column(Integer, default=0)
    max_discount_paise = Column(Integer, default=10000)
    usage_limit = Column(Integer, default=100)
    used_count = Column(Integer, default=0)
    per_user_limit = Column(Integer, default=1)
    first_order_only = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)

    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    start_date = Column(DateTime, default=datetime.utcnow)
    end_date = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    restaurant = relationship("Restaurant", back_populates="coupons")
    usages = relationship("CouponUsage", back_populates="coupon", cascade="all, delete-orphan")

class CouponUsage(Base):
    __tablename__ = "coupon_usages"

    id = Column(Integer, primary_key=True, index=True)
    coupon_id = Column(Integer, ForeignKey("coupons.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    discount_paise = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    coupon = relationship("Coupon", back_populates="usages")
    user = relationship("User")
    order = relationship("Order", back_populates="coupon_usage")

class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint('user_id', 'restaurant_id', name='_user_restaurant_fav_uc'),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="favorites")
    restaurant = relationship("Restaurant", back_populates="favorites")

class Review(Base):
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), nullable=False)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    rating = Column(Float, nullable=False)
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    type = Column(String, default="ORDER_UPDATE") # ORDER_UPDATE, PROMO, SYSTEM
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=True)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="notifications")
    order = relationship("Order")

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    action = Column(String, nullable=False)
    details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
