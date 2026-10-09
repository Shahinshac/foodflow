from datetime import datetime
from typing import List, Optional, Tuple
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, Coupon, CouponUsage, Order, OrderStatus, Restaurant
from ..schemas import (
    CouponResponse, CouponValidateRequest, CouponValidateResponse, CouponCreate
)
from ..auth import get_current_user

router = APIRouter(prefix="/coupons", tags=["Coupons & Offers Engine"])

def validate_coupon_logic(
    db: Session,
    user: User,
    code: str,
    restaurant_id: Optional[int],
    subtotal_paise: int,
    delivery_fee_paise: int = 3000
) -> Tuple[bool, int, str, Optional[Coupon]]:
    clean_code = code.strip().upper()
    coupon = db.query(Coupon).filter(Coupon.code == clean_code).first()

    if not coupon:
        return False, 0, f"Coupon code '{clean_code}' does not exist", None

    if not coupon.is_active:
        return False, 0, "This coupon is currently inactive", coupon

    now = datetime.utcnow()
    if coupon.start_date and now < coupon.start_date:
        return False, 0, f"Coupon starts on {coupon.start_date.strftime('%d %b %Y')}", coupon

    if coupon.end_date and now > coupon.end_date:
        return False, 0, f"Coupon expired on {coupon.end_date.strftime('%d %b %Y')}", coupon

    if coupon.restaurant_id and restaurant_id and coupon.restaurant_id != restaurant_id:
        rest = db.query(Restaurant).filter(Restaurant.id == coupon.restaurant_id).first()
        rest_name = rest.name if rest else "specific restaurant"
        return False, 0, f"This offer is only valid at {rest_name}", coupon

    if coupon.first_order_only:
        past_orders = db.query(Order).filter(
            Order.user_id == user.id,
            Order.status != OrderStatus.CANCELLED
        ).count()
        if past_orders > 0:
            return False, 0, "This coupon is exclusively for first-time customers", coupon

    if subtotal_paise < coupon.min_order_paise:
        req_rs = coupon.min_order_paise // 100
        curr_rs = subtotal_paise // 100
        return False, 0, f"Add items worth ₹{req_rs - curr_rs} more to use this coupon (Min order ₹{req_rs})", coupon

    if coupon.used_count >= coupon.usage_limit:
        return False, 0, "Coupon redemption limit has been reached", coupon

    user_usages = db.query(CouponUsage).filter(
        CouponUsage.coupon_id == coupon.id,
        CouponUsage.user_id == user.id
    ).count()

    if user_usages >= coupon.per_user_limit:
        return False, 0, f"You have already redeemed this coupon the maximum allowed {coupon.per_user_limit} time(s)", coupon

    # Calculate exact discount in integer paise
    discount = 0
    if coupon.discount_type.upper() == "PERCENTAGE":
        calc_discount = int((subtotal_paise * coupon.discount_value) / 100)
        discount = min(calc_discount, coupon.max_discount_paise)
    elif coupon.discount_type.upper() in ["FLAT", "FIXED"]:
        discount = min(coupon.discount_value, subtotal_paise)
    elif coupon.discount_type.upper() == "FREE_DELIVERY":
        discount = delivery_fee_paise
    else:
        calc_discount = int((subtotal_paise * coupon.discount_value) / 100)
        discount = min(calc_discount, coupon.max_discount_paise)

    # Safe clamp
    discount = max(0, min(discount, subtotal_paise + delivery_fee_paise))

    savings_str = f"₹{discount // 100}" if discount % 100 == 0 else f"₹{discount / 100:.2f}"
    return True, discount, f"Coupon {coupon.code} applied! Saved {savings_str}", coupon


@router.post("/validate", response_model=CouponValidateResponse)
def validate_coupon_endpoint(
    req: CouponValidateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    valid, discount, message, coupon = validate_coupon_logic(
        db=db,
        user=current_user,
        code=req.code,
        restaurant_id=req.restaurant_id,
        subtotal_paise=req.subtotal_paise,
        delivery_fee_paise=req.delivery_fee_paise
    )
    coupon_resp = None
    if coupon:
        now = datetime.utcnow()
        is_expired = bool(coupon.end_date and now > coupon.end_date)
        rest_name = coupon.restaurant.name if coupon.restaurant else "Platform Wide"
        coupon_resp = CouponResponse(
            id=coupon.id,
            code=coupon.code,
            title=coupon.title or coupon.code,
            description=coupon.description or "",
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
            is_expired=is_expired
        )
    return CouponValidateResponse(
        valid=valid,
        discount_paise=discount,
        message=message,
        coupon=coupon_resp
    )


@router.get("/available", response_model=List[CouponResponse])
def get_available_coupons(
    restaurant_id: Optional[int] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    now = datetime.utcnow()
    query = db.query(Coupon).filter(
        Coupon.is_active == True,
        (Coupon.end_date == None) | (Coupon.end_date >= now)
    )

    if restaurant_id:
        query = query.filter(
            (Coupon.restaurant_id == None) | (Coupon.restaurant_id == restaurant_id)
        )
    else:
        query = query.filter(Coupon.restaurant_id == None)

    coupons = query.all()
    results = []
    for c in coupons:
        # Check if user has not exhausted their limit
        user_usages = db.query(CouponUsage).filter(
            CouponUsage.coupon_id == c.id,
            CouponUsage.user_id == current_user.id
        ).count()

        if user_usages < c.per_user_limit and c.used_count < c.usage_limit:
            rest_name = c.restaurant.name if c.restaurant else "All Restaurants"
            results.append(CouponResponse(
                id=c.id,
                code=c.code,
                title=c.title or f"{c.code} Offer",
                description=c.description or f"Get {c.discount_value}% OFF on orders above ₹{c.min_order_paise // 100}",
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
                is_expired=False
            ))
    return results
