from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from ..database import get_db
from ..models import (
    User, Restaurant, FoodCategory, FoodItem, Order, OrderStatus,
    Coupon, CouponUsage, OrderItem, UserRole
)
from ..schemas import (
    RestaurantResponse, RestaurantCreate, RestaurantSettingsUpdate,
    FoodCategoryCreate, FoodCategoryResponse, FoodItemCreate, FoodItemResponse,
    OrderResponse, OrderStatusUpdate, CouponResponse, CouponCreate,
    OwnerAnalyticsResponse
)
from ..auth import get_current_user, require_restaurant_owner
from .notifications import create_system_notification

router = APIRouter(prefix="/owner", tags=["Restaurant Owner Portal"])

@router.get("/restaurant", response_model=RestaurantResponse)
def get_my_restaurant(
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="No restaurant associated with this owner account")
    return restaurant

@router.post("/restaurant", response_model=RestaurantResponse)
def onboard_restaurant(
    rest_in: RestaurantCreate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    existing = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Owner already has a registered restaurant")

    if rest_in.latitude is None or rest_in.longitude is None:
        raise HTTPException(
            status_code=400,
            detail="Restaurant location coordinates (latitude and longitude) are required. Please select the location on the map."
        )
    if not (-90.0 <= rest_in.latitude <= 90.0) or not (-180.0 <= rest_in.longitude <= 180.0):
        raise HTTPException(
            status_code=400,
            detail="Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180."
        )
    if not rest_in.address_text or not rest_in.address_text.strip():
        raise HTTPException(
            status_code=400,
            detail="Restaurant address is required. Please provide a street address or location description."
        )

    restaurant = Restaurant(
        owner_id=current_user.id,
        name=rest_in.name,
        description=rest_in.description,
        cuisine=rest_in.cuisine,
        image_url=rest_in.image_url,
        delivery_fee_paise=rest_in.delivery_fee_paise,
        min_order_paise=rest_in.min_order_paise,
        estimated_delivery_time=rest_in.estimated_delivery_time,
        latitude=rest_in.latitude,
        longitude=rest_in.longitude,
        address_text=rest_in.address_text.strip(),
        is_open=rest_in.is_open,
        opening_time=rest_in.opening_time,
        closing_time=rest_in.closing_time,
        prep_time_minutes=rest_in.prep_time_minutes,
        upi_id=rest_in.upi_id,
        is_active=False,
        is_approved=False
    )
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)

    # Notify super admin accounts of new restaurant application
    admin_users = db.query(User).filter(User.role == UserRole.ADMIN).all()
    for admin in admin_users:
        create_system_notification(
            db=db,
            user_id=admin.id,
            title="New Restaurant Application 🛎️",
            message=f"'{restaurant.name}' has been registered by {current_user.email} and is awaiting review.",
            notif_type="SYSTEM"
        )

    # Send confirmation notification to the owner
    create_system_notification(
        db=db,
        user_id=current_user.id,
        title="Application Received ⏳",
        message=f"Thank you for registering '{restaurant.name}'. Your application is currently under review by Super Admin.",
        notif_type="SYSTEM"
    )

    return restaurant

@router.put("/restaurant", response_model=RestaurantResponse)
def update_restaurant_profile(
    rest_in: RestaurantCreate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    restaurant.name = rest_in.name
    restaurant.description = rest_in.description
    restaurant.cuisine = rest_in.cuisine
    if rest_in.image_url:
        restaurant.image_url = rest_in.image_url
    restaurant.delivery_fee_paise = rest_in.delivery_fee_paise
    restaurant.min_order_paise = rest_in.min_order_paise
    restaurant.estimated_delivery_time = rest_in.estimated_delivery_time
    if rest_in.latitude is not None:
        restaurant.latitude = rest_in.latitude
    if rest_in.longitude is not None:
        restaurant.longitude = rest_in.longitude
    if rest_in.address_text:
        restaurant.address_text = rest_in.address_text
    restaurant.is_open = rest_in.is_open
    restaurant.opening_time = rest_in.opening_time
    restaurant.closing_time = rest_in.closing_time
    restaurant.prep_time_minutes = rest_in.prep_time_minutes
    if rest_in.upi_id is not None:
        restaurant.upi_id = rest_in.upi_id

    db.commit()
    db.refresh(restaurant)
    return restaurant

@router.put("/restaurant/settings", response_model=RestaurantResponse)
def update_restaurant_settings(
    settings: RestaurantSettingsUpdate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    if settings.is_open is not None:
        restaurant.is_open = settings.is_open
    if settings.prep_time_minutes is not None:
        restaurant.prep_time_minutes = settings.prep_time_minutes
    if settings.opening_time is not None:
        restaurant.opening_time = settings.opening_time
    if settings.closing_time is not None:
        restaurant.closing_time = settings.closing_time
    if settings.estimated_delivery_time is not None:
        restaurant.estimated_delivery_time = settings.estimated_delivery_time
    if settings.delivery_fee_paise is not None:
        restaurant.delivery_fee_paise = settings.delivery_fee_paise
    if settings.min_order_paise is not None:
        restaurant.min_order_paise = settings.min_order_paise
    if settings.image_url is not None:
        restaurant.image_url = settings.image_url
    if settings.upi_id is not None:
        restaurant.upi_id = settings.upi_id
    if settings.latitude is not None:
        if not (-90.0 <= settings.latitude <= 90.0):
            raise HTTPException(status_code=400, detail="Invalid latitude (-90 to 90)")
        restaurant.latitude = settings.latitude
    if settings.longitude is not None:
        if not (-180.0 <= settings.longitude <= 180.0):
            raise HTTPException(status_code=400, detail="Invalid longitude (-180 to 180)")
        restaurant.longitude = settings.longitude
    if settings.address_text is not None:
        restaurant.address_text = settings.address_text.strip()

    db.commit()
    db.refresh(restaurant)
    return restaurant

@router.post("/categories", response_model=FoodCategoryResponse)
def create_category(
    cat_in: FoodCategoryCreate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    category = FoodCategory(name=cat_in.name, restaurant_id=restaurant.id)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category

@router.post("/foods", response_model=FoodItemResponse)
def create_food_item(
    food_in: FoodItemCreate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    food = FoodItem(
        restaurant_id=restaurant.id,
        category_id=food_in.category_id,
        name=food_in.name,
        description=food_in.description,
        price_paise=food_in.price_paise,
        is_veg=food_in.is_veg,
        image_url=food_in.image_url,
        is_available=food_in.is_available,
        portions=food_in.portions
    )
    db.add(food)
    db.commit()
    db.refresh(food)
    return food

@router.put("/foods/{food_id}", response_model=FoodItemResponse)
def update_food_item(
    food_id: int,
    food_in: FoodItemCreate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    food = db.query(FoodItem).filter(
        FoodItem.id == food_id,
        FoodItem.restaurant_id == restaurant.id
    ).first()
    if not food:
        raise HTTPException(status_code=404, detail="Food item not found or unauthorized")

    food.name = food_in.name
    food.description = food_in.description
    food.price_paise = food_in.price_paise
    food.is_veg = food_in.is_veg
    if food_in.image_url:
        food.image_url = food_in.image_url
    food.is_available = food_in.is_available
    if food_in.portions is not None:
        food.portions = food_in.portions
    if food_in.category_id:
        food.category_id = food_in.category_id

    db.commit()
    db.refresh(food)
    return food

@router.put("/foods/{food_id}/toggle-availability", response_model=FoodItemResponse)
def toggle_food_availability(
    food_id: int,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    food = db.query(FoodItem).filter(
        FoodItem.id == food_id,
        FoodItem.restaurant_id == restaurant.id
    ).first()
    if not food:
        raise HTTPException(status_code=404, detail="Food item not found or unauthorized")

    food.is_available = not food.is_available
    db.commit()
    db.refresh(food)
    return food

@router.get("/foods", response_model=List[FoodItemResponse])
def get_owner_foods(
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        return []
    return db.query(FoodItem).filter(FoodItem.restaurant_id == restaurant.id).all()

@router.get("/orders", response_model=List[OrderResponse])
def get_restaurant_orders(
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        return []

    return db.query(Order).filter(
        Order.restaurant_id == restaurant.id
    ).order_by(Order.created_at.desc()).all()

@router.put("/orders/{order_id}/status", response_model=OrderResponse)
def update_owner_order_status(
    order_id: int,
    status_in: OrderStatusUpdate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    order = db.query(Order).filter(
        Order.id == order_id,
        Order.restaurant_id == restaurant.id
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found or unauthorized")

    if status_in.status == order.status:
        return order

    valid_transitions = {
        OrderStatus.PLACED: [OrderStatus.RESTAURANT_CONFIRMED, OrderStatus.REJECTED, OrderStatus.CANCELLED],
        OrderStatus.RESTAURANT_CONFIRMED: [OrderStatus.PREPARING, OrderStatus.REJECTED, OrderStatus.CANCELLED],
        OrderStatus.PREPARING: [OrderStatus.READY_FOR_PICKUP, OrderStatus.CANCELLED],
        OrderStatus.READY_FOR_PICKUP: [OrderStatus.DELIVERY_PARTNER_ASSIGNED, OrderStatus.PICKED_UP, OrderStatus.OUT_FOR_DELIVERY],
    }

    allowed = valid_transitions.get(order.status, [])
    if current_user.role != UserRole.ADMIN and status_in.status not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid transition from {order.status.value} to {status_in.status.value}"
        )

    order.status = status_in.status
    db.commit()
    db.refresh(order)

    # Trigger customer notification
    status_notifs = {
        OrderStatus.RESTAURANT_CONFIRMED: ("Order Confirmed! 👨‍🍳", f"{restaurant.name} has accepted your order #{order.id}."),
        OrderStatus.PREPARING: ("Cooking in Progress! 🍲", f"Chef is now preparing your delicious meal for order #{order.id}."),
        OrderStatus.READY_FOR_PICKUP: ("Order Ready! 📦", f"Order #{order.id} is packaged and waiting for delivery partner pickup."),
        OrderStatus.REJECTED: ("Order Declined ⚠️", f"{restaurant.name} was unable to accept order #{order.id}.")
    }
    if status_in.status in status_notifs:
        title, msg = status_notifs[status_in.status]
        create_system_notification(
            db=db,
            user_id=order.user_id,
            title=title,
            message=msg,
            notif_type="ORDER_UPDATE",
            order_id=order.id
        )

    return order

# Restaurant Owner Promotions
@router.get("/promotions", response_model=List[CouponResponse])
def get_owner_promotions(
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        return []

    coupons = db.query(Coupon).filter(
        Coupon.restaurant_id == restaurant.id
    ).order_by(Coupon.created_at.desc()).all()

    now = datetime.utcnow()
    results = []
    for c in coupons:
        is_exp = bool(c.end_date and now > c.end_date)
        results.append(CouponResponse(
            id=c.id,
            code=c.code,
            title=c.title or c.code,
            description=c.description or "",
            discount_type=c.discount_type,
            discount_value=c.discount_value,
            min_order_paise=c.min_order_paise,
            max_discount_paise=c.max_discount_paise,
            usage_limit=c.usage_limit,
            used_count=c.used_count,
            per_user_limit=c.per_user_limit,
            first_order_only=c.first_order_only,
            is_active=c.is_active,
            restaurant_id=c.restaurant_id,
            restaurant_name=restaurant.name,
            start_date=c.start_date,
            end_date=c.end_date,
            created_at=c.created_at,
            is_expired=is_exp
        ))
    return results

@router.post("/promotions", response_model=CouponResponse)
def create_owner_promotion(
    promo_in: CouponCreate,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    clean_code = promo_in.code.strip().upper()
    existing = db.query(Coupon).filter(Coupon.code == clean_code).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Coupon code '{clean_code}' already exists")

    # Business rule bounds for restaurant owners
    if promo_in.discount_type.upper() == "PERCENTAGE" and promo_in.discount_value > 70:
        raise HTTPException(status_code=400, detail="Discount percentage cannot exceed 70%")

    new_coupon = Coupon(
        code=clean_code,
        title=promo_in.title or f"{promo_in.discount_value}% OFF at {restaurant.name}",
        description=promo_in.description or f"Special discount on orders above ₹{promo_in.min_order_paise // 100}",
        discount_type=promo_in.discount_type,
        discount_value=promo_in.discount_value,
        min_order_paise=promo_in.min_order_paise,
        max_discount_paise=promo_in.max_discount_paise,
        usage_limit=promo_in.usage_limit,
        used_count=0,
        per_user_limit=promo_in.per_user_limit,
        first_order_only=promo_in.first_order_only,
        is_active=promo_in.is_active,
        restaurant_id=restaurant.id,  # Owner cannot create platform-wide promotions
        created_by_user_id=current_user.id,
        start_date=promo_in.start_date or datetime.utcnow(),
        end_date=promo_in.end_date or (datetime.utcnow() + timedelta(days=30)),
        created_at=datetime.utcnow()
    )
    db.add(new_coupon)
    db.commit()
    db.refresh(new_coupon)

    return CouponResponse(
        id=new_coupon.id,
        code=new_coupon.code,
        title=new_coupon.title,
        description=new_coupon.description,
        discount_type=new_coupon.discount_type,
        discount_value=new_coupon.discount_value,
        min_order_paise=new_coupon.min_order_paise,
        max_discount_paise=new_coupon.max_discount_paise,
        usage_limit=new_coupon.usage_limit,
        used_count=new_coupon.used_count,
        per_user_limit=new_coupon.per_user_limit,
        first_order_only=new_coupon.first_order_only,
        is_active=new_coupon.is_active,
        restaurant_id=new_coupon.restaurant_id,
        restaurant_name=restaurant.name,
        start_date=new_coupon.start_date,
        end_date=new_coupon.end_date,
        created_at=new_coupon.created_at,
        is_expired=False
    )

@router.put("/promotions/{promo_id}/toggle", response_model=CouponResponse)
def toggle_owner_promotion(
    promo_id: int,
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    coupon = db.query(Coupon).filter(
        Coupon.id == promo_id,
        Coupon.restaurant_id == restaurant.id
    ).first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Promotion not found or unauthorized")

    coupon.is_active = not coupon.is_active
    db.commit()
    db.refresh(coupon)

    now = datetime.utcnow()
    is_exp = bool(coupon.end_date and now > coupon.end_date)
    return CouponResponse(
        id=coupon.id,
        code=coupon.code,
        title=coupon.title,
        description=coupon.description,
        discount_type=coupon.discount_type,
        discount_value=coupon.discount_value,
        min_order_paise=coupon.min_order_paise,
        max_discount_paise=coupon.max_discount_paise,
        usage_limit=coupon.usage_limit,
        used_count=coupon.used_count,
        per_user_limit=coupon.per_user_limit,
        first_order_only=coupon.first_order_only,
        is_active=coupon.is_active,
        restaurant_id=coupon.restaurant_id,
        restaurant_name=restaurant.name,
        start_date=coupon.start_date,
        end_date=coupon.end_date,
        created_at=coupon.created_at,
        is_expired=is_exp
    )

# Owner Analytics
@router.get("/analytics", response_model=OwnerAnalyticsResponse)
def get_owner_analytics(
    current_user: User = Depends(require_restaurant_owner),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.owner_id == current_user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    now = datetime.utcnow()
    today_start = datetime(now.year, now.month, now.day)
    week_start = now - timedelta(days=7)
    month_start = now - timedelta(days=30)

    # Orders query
    all_orders = db.query(Order).filter(Order.restaurant_id == restaurant.id).all()
    total_orders_count = len(all_orders)

    today_orders = [o for o in all_orders if o.created_at >= today_start]
    today_rev = sum(o.total_paise for o in today_orders if o.status == OrderStatus.DELIVERED)

    weekly_orders = [o for o in all_orders if o.created_at >= week_start]
    weekly_rev = sum(o.total_paise for o in weekly_orders if o.status == OrderStatus.DELIVERED)

    monthly_orders = [o for o in all_orders if o.created_at >= month_start]
    monthly_rev = sum(o.total_paise for o in monthly_orders if o.status == OrderStatus.DELIVERED)

    delivered_orders = [o for o in all_orders if o.status == OrderStatus.DELIVERED]
    avg_order_value = (sum(o.total_paise for o in delivered_orders) // len(delivered_orders)) if delivered_orders else 0

    cancelled_count = len([o for o in all_orders if o.status == OrderStatus.CANCELLED])
    cancel_rate = round((cancelled_count / total_orders_count * 100), 1) if total_orders_count > 0 else 0.0

    status_dist = {}
    for o in all_orders:
        st = o.status.value
        status_dist[st] = status_dist.get(st, 0) + 1

    # Best selling items
    best_sellers_query = db.query(
        FoodItem.name,
        func.sum(OrderItem.quantity).label("total_qty"),
        func.sum(OrderItem.quantity * OrderItem.price_paise).label("total_sales_paise")
    ).join(OrderItem, FoodItem.id == OrderItem.food_item_id)\
     .join(Order, Order.id == OrderItem.order_id)\
     .filter(Order.restaurant_id == restaurant.id, Order.status == OrderStatus.DELIVERED)\
     .group_by(FoodItem.id)\
     .order_by(desc("total_qty"))\
     .limit(5).all()

    best_selling_items = [
        {"name": row[0], "quantity_sold": int(row[1] or 0), "sales_paise": int(row[2] or 0)}
        for row in best_sellers_query
    ]

    return OwnerAnalyticsResponse(
        today_orders=len(today_orders),
        today_revenue_paise=today_rev,
        weekly_revenue_paise=weekly_rev,
        monthly_revenue_paise=monthly_rev,
        total_orders=total_orders_count,
        average_order_value_paise=avg_order_value,
        cancellation_rate_percent=cancel_rate,
        order_status_distribution=status_dist,
        best_selling_items=best_selling_items
    )
