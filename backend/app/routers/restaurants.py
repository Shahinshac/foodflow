from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc, asc
from ..database import get_db
from ..models import Restaurant, FoodItem, FoodCategory, Favorite, Coupon, User
from ..schemas import RestaurantResponse, RestaurantDetailResponse, FoodItemResponse
from ..auth import get_current_user

router = APIRouter(prefix="/restaurants", tags=["Restaurants Discovery & Search"])

def get_optional_user(db: Session = Depends(get_db)):
    # Optional auth helper
    return None

@router.get("", response_model=List[RestaurantResponse])
def get_restaurants(
    query: Optional[str] = Query(None, description="Search by restaurant name, cuisine, or food item"),
    cuisine: Optional[str] = Query(None, description="Filter by cuisine"),
    is_veg: Optional[bool] = Query(None, description="Filter veg-friendly restaurants"),
    min_rating: Optional[float] = Query(None, description="Filter by minimum rating, e.g. 4.0"),
    max_delivery_time: Optional[int] = Query(None, description="Filter max delivery time in minutes"),
    open_now: Optional[bool] = Query(None, description="Filter currently open restaurants"),
    has_offers: Optional[bool] = Query(None, description="Filter restaurants with active discounts"),
    sort_by: Optional[str] = Query("recommended", description="Sort by: recommended, rating, delivery_time, price"),
    db: Session = Depends(get_db)
):
    q = db.query(Restaurant).filter(Restaurant.is_active == True, Restaurant.is_approved == True)

    if query and query.strip():
        search_term = f"%{query.strip()}%"
        # Match restaurant name, cuisine, address, or food items
        matching_food_restaurant_ids = db.query(FoodItem.restaurant_id).filter(
            FoodItem.name.ilike(search_term)
        ).subquery()

        q = q.filter(
            or_(
                Restaurant.name.ilike(search_term),
                Restaurant.cuisine.ilike(search_term),
                Restaurant.address_text.ilike(search_term),
                Restaurant.id.in_(matching_food_restaurant_ids)
            )
        )

    if cuisine and cuisine.strip():
        q = q.filter(Restaurant.cuisine.ilike(f"%{cuisine.strip()}%"))

    if min_rating is not None:
        q = q.filter(Restaurant.rating >= min_rating)

    if open_now:
        q = q.filter(Restaurant.is_open == True)

    if is_veg:
        veg_restaurants = db.query(FoodItem.restaurant_id).filter(
            FoodItem.is_veg == True,
            FoodItem.is_available == True
        ).distinct().subquery()
        q = q.filter(Restaurant.id.in_(veg_restaurants))

    if has_offers:
        now = datetime.utcnow()
        offer_restaurants = db.query(Coupon.restaurant_id).filter(
            Coupon.is_active == True,
            Coupon.restaurant_id != None,
            (Coupon.end_date == None) | (Coupon.end_date >= now)
        ).distinct().subquery()
        q = q.filter(
            or_(
                Restaurant.id.in_(offer_restaurants),
                Restaurant.delivery_fee_paise == 0
            )
        )

    # Sorting
    if sort_by == "rating":
        q = q.order_by(desc(Restaurant.rating))
    elif sort_by == "delivery_time":
        q = q.order_by(asc(Restaurant.prep_time_minutes))
    elif sort_by == "price":
        q = q.order_by(asc(Restaurant.delivery_fee_paise))
    else:  # recommended
        q = q.order_by(desc(Restaurant.rating), asc(Restaurant.delivery_fee_paise))

    restaurants = q.all()

    # Enrich with active offer count
    now = datetime.utcnow()
    results = []
    for r in restaurants:
        offer_count = db.query(Coupon).filter(
            Coupon.is_active == True,
            or_(Coupon.restaurant_id == r.id, Coupon.restaurant_id == None),
            (Coupon.end_date == None) | (Coupon.end_date >= now)
        ).count()

        resp = RestaurantResponse(
            id=r.id,
            owner_id=r.owner_id,
            name=r.name,
            description=r.description,
            cuisine=r.cuisine,
            image_url=r.image_url,
            rating=r.rating,
            delivery_fee_paise=r.delivery_fee_paise,
            min_order_paise=r.min_order_paise,
            estimated_delivery_time=r.estimated_delivery_time,
            latitude=r.latitude,
            longitude=r.longitude,
            address_text=r.address_text,
            is_active=r.is_active,
            is_approved=r.is_approved,
            is_open=r.is_open,
            opening_time=r.opening_time,
            closing_time=r.closing_time,
            prep_time_minutes=r.prep_time_minutes,
            is_favorite=False,
            active_offers_count=offer_count
        )
        results.append(resp)

    return results

@router.get("/{restaurant_id}", response_model=RestaurantDetailResponse)
def get_restaurant_detail(restaurant_id: int, db: Session = Depends(get_db)):
    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    now = datetime.utcnow()
    offer_count = db.query(Coupon).filter(
        Coupon.is_active == True,
        or_(Coupon.restaurant_id == restaurant.id, Coupon.restaurant_id == None),
        (Coupon.end_date == None) | (Coupon.end_date >= now)
    ).count()

    categories = db.query(FoodCategory).filter(FoodCategory.restaurant_id == restaurant_id).all()
    foods = db.query(FoodItem).filter(FoodItem.restaurant_id == restaurant_id).all()

    return RestaurantDetailResponse(
        id=restaurant.id,
        owner_id=restaurant.owner_id,
        name=restaurant.name,
        description=restaurant.description,
        cuisine=restaurant.cuisine,
        image_url=restaurant.image_url,
        rating=restaurant.rating,
        delivery_fee_paise=restaurant.delivery_fee_paise,
        min_order_paise=restaurant.min_order_paise,
        estimated_delivery_time=restaurant.estimated_delivery_time,
        latitude=restaurant.latitude,
        longitude=restaurant.longitude,
        address_text=restaurant.address_text,
        is_active=restaurant.is_active,
        is_approved=restaurant.is_approved,
        is_open=restaurant.is_open,
        opening_time=restaurant.opening_time,
        closing_time=restaurant.closing_time,
        prep_time_minutes=restaurant.prep_time_minutes,
        is_favorite=False,
        active_offers_count=offer_count,
        categories=categories,
        foods=foods
    )

@router.get("/{restaurant_id}/foods", response_model=List[FoodItemResponse])
def get_restaurant_foods(restaurant_id: int, db: Session = Depends(get_db)):
    return db.query(FoodItem).filter(
        FoodItem.restaurant_id == restaurant_id,
        FoodItem.is_available == True
    ).all()
