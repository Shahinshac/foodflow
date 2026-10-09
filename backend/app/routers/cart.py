from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models import User, CartItem, FoodItem, Restaurant
from ..schemas import CartItemAdd, CartItemUpdate, CartItemResponse, CartSummaryResponse, RestaurantResponse
from ..auth import get_current_user

router = APIRouter(prefix="/cart", tags=["Cart"])

@router.get("", response_model=CartSummaryResponse)
def get_cart(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cart_items = db.query(CartItem).filter(CartItem.user_id == current_user.id).all()

    if not cart_items:
        return CartSummaryResponse(
            items=[],
            restaurant=None,
            subtotal_paise=0,
            delivery_fee_paise=0,
            tax_paise=0,
            discount_paise=0,
            total_paise=0
        )

    # Financial calculation in integer paise
    subtotal = 0
    restaurant = None
    first_item = cart_items[0]
    if first_item.food_item:
        restaurant = first_item.food_item.restaurant

    for item in cart_items:
        subtotal += item.food_item.price_paise * item.quantity

    delivery_fee = restaurant.delivery_fee_paise if restaurant else 3000
    tax = int(subtotal * 0.05) # 5% GST on food
    discount = 0
    total = subtotal + delivery_fee + tax - discount

    return CartSummaryResponse(
        items=cart_items,
        restaurant=restaurant,
        subtotal_paise=subtotal,
        delivery_fee_paise=delivery_fee,
        tax_paise=tax,
        discount_paise=discount,
        total_paise=total
    )

@router.post("/items", response_model=CartItemResponse)
def add_to_cart(
    item_in: CartItemAdd,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    food_item = db.query(FoodItem).filter(FoodItem.id == item_in.food_item_id).first()
    if not food_item:
        raise HTTPException(status_code=404, detail="Food item not found")

    # Check if cart contains items from a different restaurant
    existing_items = db.query(CartItem).filter(CartItem.user_id == current_user.id).all()
    if existing_items:
        existing_restaurant_id = existing_items[0].food_item.restaurant_id
        if existing_restaurant_id != food_item.restaurant_id:
            # Clear existing cart if adding from different restaurant
            db.query(CartItem).filter(CartItem.user_id == current_user.id).delete()
            db.commit()

    existing_cart_item = db.query(CartItem).filter(
        CartItem.user_id == current_user.id,
        CartItem.food_item_id == item_in.food_item_id
    ).first()

    if existing_cart_item:
        existing_cart_item.quantity += item_in.quantity
        if item_in.special_instructions:
            existing_cart_item.special_instructions = item_in.special_instructions
        db.commit()
        db.refresh(existing_cart_item)
        return existing_cart_item
    else:
        new_cart_item = CartItem(
            user_id=current_user.id,
            food_item_id=item_in.food_item_id,
            quantity=item_in.quantity,
            special_instructions=item_in.special_instructions
        )
        db.add(new_cart_item)
        db.commit()
        db.refresh(new_cart_item)
        return new_cart_item

@router.put("/items/{item_id}", response_model=CartItemResponse)
def update_cart_item(
    item_id: int,
    item_in: CartItemUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    cart_item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.user_id == current_user.id
    ).first()
    if not cart_item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    if item_in.quantity <= 0:
        db.delete(cart_item)
        db.commit()
        return {"id": item_id, "quantity": 0, "food_item": cart_item.food_item}

    cart_item.quantity = item_in.quantity
    db.commit()
    db.refresh(cart_item)
    return cart_item

@router.delete("/items/{item_id}")
def remove_cart_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    cart_item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.user_id == current_user.id
    ).first()
    if not cart_item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    db.delete(cart_item)
    db.commit()
    return {"message": "Item removed from cart"}

@router.delete("/clear")
def clear_cart(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(CartItem).filter(CartItem.user_id == current_user.id).delete()
    db.commit()
    return {"message": "Cart cleared"}
