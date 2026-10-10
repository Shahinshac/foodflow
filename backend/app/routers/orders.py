from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import (
    User, CartItem, Order, OrderItem, OrderStatus, OrderStatusHistory,
    FoodItem, Restaurant, Coupon, CouponUsage, DeliveryAssignment,
    DeliveryAssignmentStatus, UserRole
)
from ..schemas import (
    OrderCreate, OrderResponse, OrderStatusUpdate, OrderCancelRequest,
    ReorderResponse, CartSummaryResponse, CartItemResponse, RestaurantResponse, FoodItemResponse
)
from ..auth import get_current_user
from .coupons import validate_coupon_logic
from .notifications import create_system_notification

router = APIRouter(prefix="/orders", tags=["Orders"])

@router.post("", response_model=OrderResponse)
def create_order(
    order_in: OrderCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    cart_items = db.query(CartItem).filter(CartItem.user_id == current_user.id).all()
    if not cart_items:
        raise HTTPException(status_code=400, detail="Cart is empty")

    first_food = cart_items[0].food_item
    if not first_food or not first_food.restaurant:
        raise HTTPException(status_code=400, detail="Invalid items in cart")

    restaurant = first_food.restaurant
    if not restaurant.is_active or not restaurant.is_open:
        raise HTTPException(status_code=400, detail=f"{restaurant.name} is currently not accepting orders")

    subtotal = 0
    order_items_to_create = []

    for c_item in cart_items:
        if not c_item.food_item.is_available:
            raise HTTPException(
                status_code=400,
                detail=f"Item '{c_item.food_item.name}' is currently unavailable. Please remove it from cart."
            )
        portion = c_item.portion or "FULL"
        item_price = c_item.price_paise
        if item_price is None:
            if c_item.food_item.portions and isinstance(c_item.food_item.portions, dict) and portion in c_item.food_item.portions:
                item_price = int(c_item.food_item.portions[portion])
            else:
                item_price = c_item.food_item.price_paise

        subtotal += item_price * c_item.quantity
        order_items_to_create.append({
            "food_item_id": c_item.food_item_id,
            "quantity": c_item.quantity,
            "portion": portion,
            "price_paise": item_price
        })

    # Check first-order free delivery eligibility (no prior non-cancelled/non-rejected orders)
    has_previous_orders = db.query(Order).filter(
        Order.user_id == current_user.id,
        Order.status.notin_([OrderStatus.CANCELLED, OrderStatus.REJECTED])
    ).first() is not None
    is_first_order = not has_previous_orders

    original_delivery_fee = restaurant.delivery_fee_paise
    delivery_fee = 0 if is_first_order else original_delivery_fee
    tax = int(subtotal * 0.05)  # 5% GST
    discount = 0
    applied_coupon = None

    # Strict Backend Coupon Validation
    if order_in.coupon_code:
        valid, discount_calc, msg, coupon_obj = validate_coupon_logic(
            db=db,
            user=current_user,
            code=order_in.coupon_code,
            restaurant_id=restaurant.id,
            subtotal_paise=subtotal,
            delivery_fee_paise=delivery_fee
        )
        if not valid:
            raise HTTPException(status_code=400, detail=f"Coupon invalid: {msg}")
        discount = discount_calc
        applied_coupon = coupon_obj

    total = subtotal + delivery_fee + tax - discount
    total = max(0, total)  # Guarantee non-negative total

    # Create Order record with Automatic Acceptance
    new_order = Order(
        user_id=current_user.id,
        restaurant_id=restaurant.id,
        status=OrderStatus.RESTAURANT_CONFIRMED,
        subtotal_paise=subtotal,
        delivery_fee_paise=delivery_fee,
        tax_paise=tax,
        discount_paise=discount,
        total_paise=total,
        coupon_id=applied_coupon.id if applied_coupon else None,
        coupon_code=applied_coupon.code if applied_coupon else None,
        delivery_address=order_in.delivery_address,
        delivery_lat=order_in.delivery_lat or 12.9716,
        delivery_lng=order_in.delivery_lng or 77.5946,
        payment_method=order_in.payment_method,
        payment_status="COMPLETED" if order_in.payment_method != "COD" else "PENDING",
        prep_estimate_minutes=restaurant.prep_time_minutes,
        travel_estimate_minutes=15,
        calculated_eta_minutes=restaurant.prep_time_minutes + 15,
        created_at=datetime.utcnow()
    )

    db.add(new_order)
    db.commit()
    db.refresh(new_order)

    # Initial status history record
    history = OrderStatusHistory(
        order_id=new_order.id,
        status=OrderStatus.RESTAURANT_CONFIRMED,
        previous_status=OrderStatus.PLACED,
        changed_by_user_id=current_user.id,
        actor_role="SYSTEM",
        reason="Order placed and automatically accepted"
    )
    db.add(history)

    # Record coupon usage and increment usage count
    if applied_coupon:
        usage = CouponUsage(
            coupon_id=applied_coupon.id,
            user_id=current_user.id,
            order_id=new_order.id,
            discount_paise=discount,
            created_at=datetime.utcnow()
        )
        db.add(usage)
        applied_coupon.used_count += 1

    # Add items to Order
    for item_data in order_items_to_create:
        oi = OrderItem(
            order_id=new_order.id,
            food_item_id=item_data["food_item_id"],
            quantity=item_data["quantity"],
            portion=item_data.get("portion", "FULL"),
            price_paise=item_data["price_paise"]
        )
        db.add(oi)

    # Clear user cart
    db.query(CartItem).filter(CartItem.user_id == current_user.id).delete()
    db.commit()
    db.refresh(new_order)

    # Trigger Notifications
    create_system_notification(
        db=db,
        user_id=current_user.id,
        title="Order Placed Successfully! 🛒",
        message=f"Your order #{new_order.id} for ₹{new_order.total_paise // 100} has been sent to {restaurant.name}.",
        notif_type="ORDER_UPDATE",
        order_id=new_order.id
    )

    if restaurant.owner_id:
        create_system_notification(
            db=db,
            user_id=restaurant.owner_id,
            title="New Order Received! 🔔",
            message=f"New order #{new_order.id} with {len(order_items_to_create)} item(s) totaling ₹{new_order.total_paise // 100}.",
            notif_type="ORDER_UPDATE",
            order_id=new_order.id
        )

    return new_order

@router.get("", response_model=List[OrderResponse])
def get_user_orders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return db.query(Order).filter(
        Order.user_id == current_user.id
    ).order_by(Order.created_at.desc()).all()

@router.get("/{order_id}", response_model=OrderResponse)
def get_order_detail(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    is_owner = (order.restaurant and order.restaurant.owner_id == current_user.id)
    is_cust = (order.user_id == current_user.id)
    is_admin = (current_user.role == UserRole.ADMIN)
    is_rider = (current_user.role == UserRole.DELIVERY_PARTNER)

    if not (is_cust or is_owner or is_admin or is_rider):
        raise HTTPException(status_code=403, detail="Unauthorized to view this order")

    return order

@router.post("/{order_id}/reorder", response_model=ReorderResponse)
def reorder_previous_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    old_order = db.query(Order).filter(
        Order.id == order_id,
        Order.user_id == current_user.id
    ).first()

    if not old_order:
        raise HTTPException(status_code=404, detail="Order not found")

    restaurant = db.query(Restaurant).filter(Restaurant.id == old_order.restaurant_id).first()
    if not restaurant or not restaurant.is_active:
        raise HTTPException(status_code=400, detail="The restaurant for this order is currently closed or unavailable")

    # Clear current cart
    db.query(CartItem).filter(CartItem.user_id == current_user.id).delete()

    added_count = 0
    unavailable_items = []

    for old_item in old_order.items:
        current_food = db.query(FoodItem).filter(
            FoodItem.id == old_item.food_item_id,
            FoodItem.restaurant_id == restaurant.id
        ).first()

        if current_food and current_food.is_available:
            cart_item = CartItem(
                user_id=current_user.id,
                food_item_id=current_food.id,
                quantity=old_item.quantity
            )
            db.add(cart_item)
            added_count += 1
        else:
            item_name = current_food.name if current_food else f"Item #{old_item.food_item_id}"
            unavailable_items.append(item_name)

    db.commit()

    if added_count == 0:
        raise HTTPException(
            status_code=400,
            detail="None of the items from this past order are currently available"
        )

    # Recompute fresh cart summary
    cart_items = db.query(CartItem).filter(CartItem.user_id == current_user.id).all()
    subtotal = sum(c.food_item.price_paise * c.quantity for c in cart_items)
    delivery_fee = restaurant.delivery_fee_paise
    tax = int(subtotal * 0.05)
    total = subtotal + delivery_fee + tax

    cart_summary = CartSummaryResponse(
        items=cart_items,
        restaurant=restaurant,
        subtotal_paise=subtotal,
        delivery_fee_paise=delivery_fee,
        tax_paise=tax,
        discount_paise=0,
        total_paise=total
    )

    msg = f"Added {added_count} item(s) to your cart."
    if unavailable_items:
        msg += f" Note: {len(unavailable_items)} item(s) ({', '.join(unavailable_items)}) are no longer available."

    return ReorderResponse(
        success=True,
        message=msg,
        added_items_count=added_count,
        unavailable_items_count=len(unavailable_items),
        unavailable_items=unavailable_items,
        cart_summary=cart_summary
    )

@router.post("/{order_id}/cancel", response_model=OrderResponse)
def cancel_order(
    order_id: int,
    cancel_req: OrderCancelRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    is_customer = (order.user_id == current_user.id)
    is_owner = (order.restaurant and order.restaurant.owner_id == current_user.id)
    is_admin = (current_user.role == UserRole.ADMIN)

    if not (is_customer or is_owner or is_admin):
        raise HTTPException(status_code=403, detail="Unauthorized to cancel this order")

    # Business rule for cancellation
    if is_customer:
        if order.status not in [OrderStatus.PLACED, OrderStatus.RESTAURANT_CONFIRMED]:
            raise HTTPException(
                status_code=400,
                detail=f"Order cannot be cancelled in state '{order.status.value}'. The kitchen has already begun preparation or rider is dispatched."
            )
        canceller_role = "CUSTOMER"
    elif is_owner:
        if order.status in [OrderStatus.PICKED_UP, OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED, OrderStatus.CANCELLED]:
            raise HTTPException(status_code=400, detail="Order cannot be cancelled at this stage")
        canceller_role = "RESTAURANT"
    else:
        if order.status in [OrderStatus.DELIVERED, OrderStatus.CANCELLED]:
            raise HTTPException(status_code=400, detail="Completed orders cannot be cancelled")
        canceller_role = "ADMIN"

    old_status = order.status
    order.status = OrderStatus.CANCELLED
    order.cancelled_by = canceller_role
    order.cancellation_reason = cancel_req.reason
    order.cancelled_at = datetime.utcnow()

    # Refund state handling
    if order.payment_status == "COMPLETED" or order.payment_method != "COD":
        order.is_refunded = True
        order.payment_status = "REFUNDED"

    # Reverse coupon usage if applicable
    if order.coupon_id:
        coupon = db.query(Coupon).filter(Coupon.id == order.coupon_id).first()
        if coupon and coupon.used_count > 0:
            coupon.used_count -= 1
        db.query(CouponUsage).filter(CouponUsage.order_id == order.id).delete()

    # Cancel any active delivery assignments
    assignments = db.query(DeliveryAssignment).filter(DeliveryAssignment.order_id == order.id).all()
    for assign in assignments:
        assign.status = DeliveryAssignmentStatus.REJECTED

    # Audit history
    history = OrderStatusHistory(
        order_id=order.id,
        status=OrderStatus.CANCELLED,
        previous_status=old_status,
        changed_by_user_id=current_user.id,
        actor_role=current_user.role.value,
        reason=f"Order cancelled by {canceller_role}: {cancel_req.reason}"
    )
    db.add(history)
    db.commit()
    db.refresh(order)

    # Notify Customer
    create_system_notification(
        db=db,
        user_id=order.user_id,
        title="Order Cancelled ❌",
        message=f"Order #{order.id} was cancelled. Reason: {cancel_req.reason}" + (" A refund has been processed." if order.is_refunded else ""),
        notif_type="ORDER_UPDATE",
        order_id=order.id
    )

    # Notify Restaurant Owner
    if order.restaurant and order.restaurant.owner_id:
        create_system_notification(
            db=db,
            user_id=order.restaurant.owner_id,
            title=f"Order #{order.id} Cancelled ⚠️",
            message=f"Order #{order.id} was cancelled by {canceller_role}: {cancel_req.reason}",
            notif_type="ORDER_UPDATE",
            order_id=order.id
        )

    return order

@router.put("/{order_id}/status", response_model=OrderResponse)
def update_order_status(
    order_id: int,
    status_update: OrderStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    old_status = order.status
    order.status = status_update.status

    history = OrderStatusHistory(
        order_id=order.id,
        status=status_update.status,
        previous_status=old_status,
        changed_by_user_id=current_user.id,
        actor_role=current_user.role.value,
        reason=status_update.reason or f"Status updated to {status_update.status.value}"
    )
    db.add(history)
    db.commit()
    db.refresh(order)

    # Dispatch notification for key milestones
    status_msg_map = {
        OrderStatus.RESTAURANT_CONFIRMED: "Restaurant confirmed your order! 👨‍🍳",
        OrderStatus.PREPARING: "Your food is being freshly prepared! 🍲",
        OrderStatus.READY_FOR_PICKUP: "Your food is packed & ready for pickup! 📦",
        OrderStatus.PICKED_UP: "Delivery partner picked up your order! 🛵",
        OrderStatus.OUT_FOR_DELIVERY: "Your order is out for delivery! 🚀",
        OrderStatus.DELIVERED: "Order delivered! Enjoy your delicious meal! 🎉",
    }
    if status_update.status in status_msg_map:
        create_system_notification(
            db=db,
            user_id=order.user_id,
            title=status_msg_map[status_update.status],
            message=f"Order #{order.id} status is now {status_update.status.value.replace('_', ' ')}.",
            notif_type="ORDER_UPDATE",
            order_id=order.id
        )

    return order
