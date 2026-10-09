from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, Review, Order, OrderStatus, Restaurant
from ..schemas import ReviewCreate, ReviewResponse
from ..auth import require_customer

router = APIRouter(prefix="/reviews", tags=["Reviews & Ratings"])

@router.post("", response_model=ReviewResponse)
def create_review(
    review_in: ReviewCreate,
    current_user: User = Depends(require_customer),
    db: Session = Depends(get_db)
):
    # Verify completed order
    order = db.query(Order).filter(
        Order.id == review_in.order_id,
        Order.user_id == current_user.id
    ).first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found or unauthorized")

    if order.status != OrderStatus.DELIVERED:
        raise HTTPException(status_code=400, detail="Only delivered orders can be reviewed")

    # Prevent duplicate reviews
    existing = db.query(Review).filter(Review.order_id == review_in.order_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Order has already been reviewed")

    review = Review(
        user_id=current_user.id,
        restaurant_id=order.restaurant_id,
        order_id=order.id,
        rating=review_in.rating,
        comment=review_in.comment
    )
    db.add(review)
    db.commit()
    db.refresh(review)

    # Recalculate restaurant rating
    all_reviews = db.query(Review).filter(Review.restaurant_id == order.restaurant_id).all()
    if all_reviews:
        avg_rating = sum(r.rating for r in all_reviews) / len(all_reviews)
        restaurant = db.query(Restaurant).filter(Restaurant.id == order.restaurant_id).first()
        if restaurant:
            restaurant.rating = round(avg_rating, 1)
            db.commit()

    return review

@router.get("/restaurant/{restaurant_id}", response_model=List[ReviewResponse])
def get_restaurant_reviews(restaurant_id: int, db: Session = Depends(get_db)):
    return db.query(Review).filter(Review.restaurant_id == restaurant_id).order_by(Review.created_at.desc()).all()
