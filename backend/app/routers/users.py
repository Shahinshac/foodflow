from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, UserAddress, Favorite, Restaurant, Coupon
from ..schemas import AddressCreate, AddressResponse, UserResponse, RestaurantResponse
from ..auth import get_current_user

router = APIRouter(prefix="/users", tags=["User Profile, Addresses & Favorites"])

@router.get("/addresses", response_model=List[AddressResponse])
def get_user_addresses(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(UserAddress).filter(
        UserAddress.user_id == current_user.id
    ).order_by(UserAddress.is_default.desc(), UserAddress.id.desc()).all()

@router.post("/addresses", response_model=AddressResponse)
def add_user_address(
    addr_in: AddressCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    existing_count = db.query(UserAddress).filter(UserAddress.user_id == current_user.id).count()
    make_default = bool(addr_in.is_default or existing_count == 0)

    if make_default:
        db.query(UserAddress).filter(UserAddress.user_id == current_user.id).update({"is_default": False})

    new_addr = UserAddress(
        user_id=current_user.id,
        label=addr_in.label.upper().strip() if addr_in.label else "HOME",
        street_address=addr_in.street_address.strip(),
        building_floor=addr_in.building_floor,
        landmark=addr_in.landmark,
        city=addr_in.city.strip() if addr_in.city else "City",
        state=addr_in.state,
        pincode=addr_in.pincode.strip() if addr_in.pincode else "",
        latitude=addr_in.latitude or 12.9716,
        longitude=addr_in.longitude or 77.5946,
        is_default=make_default
    )
    db.add(new_addr)
    db.commit()
    db.refresh(new_addr)
    return new_addr

@router.delete("/addresses/{address_id}")
def delete_user_address(
    address_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    addr = db.query(UserAddress).filter(
        UserAddress.id == address_id,
        UserAddress.user_id == current_user.id
    ).first()
    if not addr:
        raise HTTPException(status_code=404, detail="Address not found")
    
    was_default = addr.is_default
    db.delete(addr)
    db.commit()

    if was_default:
        remaining = db.query(UserAddress).filter(
            UserAddress.user_id == current_user.id
        ).order_by(UserAddress.id.desc()).first()
        if remaining:
            remaining.is_default = True
            db.commit()

    return {"message": "Address deleted"}

# Favorites Management
@router.get("/favorites", response_model=List[RestaurantResponse])
def get_user_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    favs = db.query(Favorite).filter(Favorite.user_id == current_user.id).all()
    results = []
    now = datetime.utcnow()

    for fav in favs:
        r = fav.restaurant
        if r and r.is_active:
            offer_count = db.query(Coupon).filter(
                Coupon.is_active == True,
                (Coupon.restaurant_id == r.id) | (Coupon.restaurant_id == None),
                (Coupon.end_date == None) | (Coupon.end_date >= now)
            ).count()

            results.append(RestaurantResponse(
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
                is_favorite=True,
                active_offers_count=offer_count
            ))
    return results

@router.get("/favorites/ids", response_model=List[int])
def get_user_favorite_ids(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    favs = db.query(Favorite.restaurant_id).filter(Favorite.user_id == current_user.id).all()
    return [f[0] for f in favs]

@router.post("/favorites/{restaurant_id}")
def toggle_favorite(
    restaurant_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    existing = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.restaurant_id == restaurant_id
    ).first()

    if existing:
        db.delete(existing)
        db.commit()
        return {"is_favorite": False, "message": f"Removed {restaurant.name} from favorites"}
    else:
        new_fav = Favorite(
            user_id=current_user.id,
            restaurant_id=restaurant_id,
            created_at=datetime.utcnow()
        )
        db.add(new_fav)
        db.commit()
        return {"is_favorite": True, "message": f"Added {restaurant.name} to favorites"}

@router.delete("/favorites/{restaurant_id}")
def remove_favorite(
    restaurant_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    existing = db.query(Favorite).filter(
        Favorite.user_id == current_user.id,
        Favorite.restaurant_id == restaurant_id
    ).first()
    if existing:
        db.delete(existing)
        db.commit()
    return {"message": "Favorite removed"}
