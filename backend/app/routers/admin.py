from typing import List, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from ..database import get_db
from ..models import (
    User, Restaurant, DeliveryPartner, Order, OrderStatus, Coupon, CouponUsage,
    AuditLog, UserRole
)
from ..schemas import (
    UserCreate, UserResponse, RestaurantResponse, DeliveryPartnerResponse,
    OrderResponse, CouponCreate, CouponResponse, CouponAnalyticsResponse,
    AdminMetricsResponse, AdminAnalyticsResponse
)
from ..auth import require_admin, get_password_hash

router = APIRouter(prefix="/admin", tags=["Admin Panel & Promotion Engine"])

@router.get("/metrics", response_model=AdminMetricsResponse)
def get_admin_metrics(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    total_users = db.query(User).count()
    total_restaurants = db.query(Restaurant).count()
    pending_restaurants = db.query(Restaurant).filter(Restaurant.is_approved == False).count()
    total_partners = db.query(DeliveryPartner).count()
    pending_partners = db.query(DeliveryPartner).filter(DeliveryPartner.is_verified == False).count()
    total_orders = db.query(Order).count()
    active_orders = db.query(Order).filter(
        Order.status.notin_([OrderStatus.DELIVERED, OrderStatus.CANCELLED, OrderStatus.REJECTED])
    ).count()

    delivered_orders = db.query(Order).filter(Order.status == OrderStatus.DELIVERED).all()
    total_revenue = sum(o.total_paise for o in delivered_orders)

    return AdminMetricsResponse(
        total_users=total_users,
        total_restaurants=total_restaurants,
        pending_restaurant_approvals=pending_restaurants,
        total_delivery_partners=total_partners,
        pending_partner_approvals=pending_partners,
        total_orders=total_orders,
        active_orders=active_orders,
        total_revenue_paise=total_revenue
    )

@router.get("/analytics", response_model=AdminAnalyticsResponse)
def get_admin_analytics(
    timeframe: str = Query("30d", description="today, 7d, 30d, all"),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    now = datetime.utcnow()
    query = db.query(Order)

    if timeframe == "today":
        start_date = datetime(now.year, now.month, now.day)
        query = query.filter(Order.created_at >= start_date)
    elif timeframe == "7d":
        start_date = now - timedelta(days=7)
        query = query.filter(Order.created_at >= start_date)
    elif timeframe == "30d":
        start_date = now - timedelta(days=30)
        query = query.filter(Order.created_at >= start_date)

    orders = query.all()
    total_orders = len(orders)
    active_orders = len([o for o in orders if o.status not in [OrderStatus.DELIVERED, OrderStatus.CANCELLED, OrderStatus.REJECTED]])
    completed_orders = len([o for o in orders if o.status == OrderStatus.DELIVERED])
    cancelled_orders = len([o for o in orders if o.status == OrderStatus.CANCELLED])

    delivered = [o for o in orders if o.status == OrderStatus.DELIVERED]
    gross_val = sum(o.subtotal_paise + o.delivery_fee_paise + o.tax_paise for o in delivered)
    promo_discount = sum(o.discount_paise for o in delivered)
    net_rev = sum(o.total_paise for o in delivered)

    total_rests = db.query(Restaurant).filter(Restaurant.is_active == True).count()
    active_riders = db.query(DeliveryPartner).filter(DeliveryPartner.is_online == True).count()
    total_custs = db.query(User).filter(User.role == UserRole.CUSTOMER).count()

    return AdminAnalyticsResponse(
        timeframe=timeframe,
        total_orders=total_orders,
        active_orders=active_orders,
        completed_orders=completed_orders,
        cancelled_orders=cancelled_orders,
        gross_order_value_paise=gross_val,
        promotion_discounts_paise=promo_discount,
        net_revenue_paise=net_rev,
        total_restaurants=total_rests,
        active_delivery_partners=active_riders,
        total_customers=total_custs
    )

@router.get("/users", response_model=List[UserResponse])
def get_all_users(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    return db.query(User).order_by(User.created_at.desc()).all()

@router.post("/users", response_model=UserResponse)
def create_user_by_admin(
    user_in: UserCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    existing = db.query(User).filter(User.email == user_in.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        email=user_in.email,
        full_name=user_in.full_name,
        phone=user_in.phone,
        role=user_in.role or UserRole.CUSTOMER,
        hashed_password=get_password_hash(user_in.password),
        is_active=True,
        is_approved=True,
        created_at=datetime.utcnow()
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    log = AuditLog(
        admin_id=current_user.id,
        action="CREATE_USER",
        details=f"Created user {user.email} with role {user.role.value}"
    )
    db.add(log)
    db.commit()
    return user

@router.put("/users/{user_id}/toggle-active", response_model=UserResponse)
def toggle_user_active(
    user_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")

    target_user.is_active = not target_user.is_active

    log = AuditLog(
        admin_id=current_user.id,
        action="TOGGLE_USER_ACTIVE",
        details=f"Set user {target_user.email} is_active to {target_user.is_active}"
    )
    db.add(log)
    db.commit()
    db.refresh(target_user)
    return target_user

@router.get("/restaurants", response_model=List[RestaurantResponse])
def get_all_restaurants(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    return db.query(Restaurant).order_by(Restaurant.id.desc()).all()

@router.put("/restaurants/{restaurant_id}/approve", response_model=RestaurantResponse)
def approve_restaurant(
    restaurant_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    rest = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not rest:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    rest.is_approved = True
    rest.is_active = True

    log = AuditLog(
        admin_id=current_user.id,
        action="APPROVE_RESTAURANT",
        details=f"Approved restaurant {rest.name} (id={rest.id})"
    )
    db.add(log)
    db.commit()
    db.refresh(rest)
    return rest

@router.put("/restaurants/{restaurant_id}/reject", response_model=RestaurantResponse)
def reject_restaurant(
    restaurant_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    rest = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not rest:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    rest.is_approved = False
    rest.is_active = False

    log = AuditLog(
        admin_id=current_user.id,
        action="REJECT_RESTAURANT",
        details=f"Rejected restaurant {rest.name} (id={rest.id})"
    )
    db.add(log)
    db.commit()
    db.refresh(rest)
    return rest

@router.put("/restaurants/{restaurant_id}/toggle-active", response_model=RestaurantResponse)
def toggle_restaurant_active(
    restaurant_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    rest = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not rest:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    rest.is_active = not rest.is_active

    log = AuditLog(
        admin_id=current_user.id,
        action="TOGGLE_RESTAURANT_ACTIVE",
        details=f"Toggled restaurant {rest.name} (id={rest.id}) is_active to {rest.is_active}"
    )
    db.add(log)
    db.commit()
    db.refresh(rest)
    return rest

# Admin Promotions Management
@router.get("/promotions", response_model=List[CouponResponse])
def get_admin_promotions(
    status_filter: Optional[str] = Query("all", description="all, active, scheduled, expired"),
    scope_filter: Optional[str] = Query("all", description="all, platform, restaurant"),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    q = db.query(Coupon)
    now = datetime.utcnow()

    if status_filter == "active":
        q = q.filter(
            Coupon.is_active == True,
            (Coupon.start_date == None) | (Coupon.start_date <= now),
            (Coupon.end_date == None) | (Coupon.end_date >= now)
        )
    elif status_filter == "scheduled":
        q = q.filter(Coupon.start_date > now)
    elif status_filter == "expired":
        q = q.filter(Coupon.end_date != None, Coupon.end_date < now)

    if scope_filter == "platform":
        q = q.filter(Coupon.restaurant_id == None)
    elif scope_filter == "restaurant":
        q = q.filter(Coupon.restaurant_id != None)

    coupons = q.order_by(Coupon.created_at.desc()).all()
    results = []
    for c in coupons:
        is_exp = bool(c.end_date and now > c.end_date)
        rest_name = c.restaurant.name if c.restaurant else "Platform Wide"
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
            restaurant_name=rest_name,
            start_date=c.start_date,
            end_date=c.end_date,
            created_at=c.created_at,
            is_expired=is_exp
        ))
    return results

@router.post("/promotions", response_model=CouponResponse)
def create_admin_promotion(
    promo_in: CouponCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    clean_code = promo_in.code.strip().upper()
    existing = db.query(Coupon).filter(Coupon.code == clean_code).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Coupon code '{clean_code}' already exists")

    coupon = Coupon(
        code=clean_code,
        title=promo_in.title or clean_code,
        description=promo_in.description,
        discount_type=promo_in.discount_type,
        discount_value=promo_in.discount_value,
        min_order_paise=promo_in.min_order_paise,
        max_discount_paise=promo_in.max_discount_paise,
        usage_limit=promo_in.usage_limit,
        used_count=0,
        per_user_limit=promo_in.per_user_limit,
        first_order_only=promo_in.first_order_only,
        is_active=promo_in.is_active,
        restaurant_id=promo_in.restaurant_id,
        created_by_user_id=current_user.id,
        start_date=promo_in.start_date or datetime.utcnow(),
        end_date=promo_in.end_date,
        created_at=datetime.utcnow()
    )
    db.add(coupon)
    db.commit()
    db.refresh(coupon)

    rest_name = coupon.restaurant.name if coupon.restaurant else "Platform Wide"
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
        restaurant_name=rest_name,
        start_date=coupon.start_date,
        end_date=coupon.end_date,
        created_at=coupon.created_at,
        is_expired=False
    )

@router.put("/promotions/{promo_id}/toggle", response_model=CouponResponse)
def toggle_admin_promotion(
    promo_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    coupon = db.query(Coupon).filter(Coupon.id == promo_id).first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Promotion not found")

    coupon.is_active = not coupon.is_active
    db.commit()
    db.refresh(coupon)

    now = datetime.utcnow()
    is_exp = bool(coupon.end_date and now > coupon.end_date)
    rest_name = coupon.restaurant.name if coupon.restaurant else "Platform Wide"

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
        restaurant_name=rest_name,
        start_date=coupon.start_date,
        end_date=coupon.end_date,
        created_at=coupon.created_at,
        is_expired=is_exp
    )

@router.get("/promotions/{promo_id}/analytics", response_model=CouponAnalyticsResponse)
def get_promotion_analytics(
    promo_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    coupon = db.query(Coupon).filter(Coupon.id == promo_id).first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Promotion not found")

    usages = db.query(CouponUsage).filter(CouponUsage.coupon_id == coupon.id).all()
    total_redemptions = len(usages)
    total_discount = sum(u.discount_paise for u in usages)

    orders = db.query(Order).filter(Order.coupon_id == coupon.id, Order.status == OrderStatus.DELIVERED).all()
    total_orders_gen = len(orders)
    total_gross = sum(o.total_paise for o in orders)

    now = datetime.utcnow()
    is_exp = bool(coupon.end_date and now > coupon.end_date)
    rest_name = coupon.restaurant.name if coupon.restaurant else "Platform Wide"

    coupon_resp = CouponResponse(
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
        restaurant_name=rest_name,
        start_date=coupon.start_date,
        end_date=coupon.end_date,
        created_at=coupon.created_at,
        is_expired=is_exp
    )

    return CouponAnalyticsResponse(
        coupon=coupon_resp,
        total_redemptions=total_redemptions,
        total_discount_given_paise=total_discount,
        total_orders_generated=total_orders_gen,
        total_gross_revenue_paise=total_gross
    )
