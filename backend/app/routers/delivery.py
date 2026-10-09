from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import (
    User, DeliveryPartner, DeliveryAssignment, DeliveryAssignmentStatus,
    Order, OrderStatus, UserRole
)
from ..schemas import (
    DeliveryPartnerResponse, DeliveryPartnerProfileCreate,
    DeliveryAssignmentResponse, DeliveryStatusUpdate
)
from ..auth import require_delivery_partner

router = APIRouter(prefix="/delivery", tags=["Delivery Partner Portal"])

@router.get("/profile", response_model=DeliveryPartnerResponse)
def get_delivery_profile(
    current_user: User = Depends(require_delivery_partner),
    db: Session = Depends(get_db)
):
    dp = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == current_user.id).first()
    if not dp:
        dp = DeliveryPartner(user_id=current_user.id, vehicle_number="REG-1001", is_online=True, is_verified=True)
        db.add(dp)
        db.commit()
        db.refresh(dp)
    return dp

@router.put("/toggle-online", response_model=DeliveryPartnerResponse)
def toggle_online_status(
    current_user: User = Depends(require_delivery_partner),
    db: Session = Depends(get_db)
):
    dp = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == current_user.id).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Delivery profile not found")

    dp.is_online = not dp.is_online
    db.commit()
    db.refresh(dp)
    return dp

@router.get("/assignments", response_model=List[DeliveryAssignmentResponse])
def get_my_assignments(
    current_user: User = Depends(require_delivery_partner),
    db: Session = Depends(get_db)
):
    dp = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == current_user.id).first()
    if not dp:
        return []

    return db.query(DeliveryAssignment).filter(DeliveryAssignment.delivery_partner_id == dp.id).order_by(DeliveryAssignment.assigned_at.desc()).all()

@router.get("/available-orders", response_model=List[DeliveryAssignmentResponse])
def get_available_orders_for_delivery(
    current_user: User = Depends(require_delivery_partner),
    db: Session = Depends(get_db)
):
    dp = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == current_user.id).first()
    if not dp or not dp.is_online:
        return []

    ready_orders = db.query(Order).filter(Order.status == OrderStatus.READY_FOR_PICKUP).all()
    for ro in ready_orders:
        existing = db.query(DeliveryAssignment).filter(DeliveryAssignment.order_id == ro.id).first()
        if not existing:
            new_assign = DeliveryAssignment(
                order_id=ro.id,
                delivery_partner_id=dp.id,
                status=DeliveryAssignmentStatus.ASSIGNED
            )
            db.add(new_assign)
            ro.status = OrderStatus.DELIVERY_PARTNER_ASSIGNED
            db.commit()

    return db.query(DeliveryAssignment).filter(DeliveryAssignment.delivery_partner_id == dp.id).all()

@router.put("/assignments/{assignment_id}/status", response_model=DeliveryAssignmentResponse)
def update_delivery_status(
    assignment_id: int,
    status_in: DeliveryStatusUpdate,
    current_user: User = Depends(require_delivery_partner),
    db: Session = Depends(get_db)
):
    dp = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == current_user.id).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Delivery profile not found")

    assignment = db.query(DeliveryAssignment).filter(
        DeliveryAssignment.id == assignment_id,
        DeliveryAssignment.delivery_partner_id == dp.id
    ).first()

    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    assignment.status = status_in.status
    order = assignment.order

    if status_in.status == DeliveryAssignmentStatus.ARRIVED_AT_RESTAURANT:
        order.status = OrderStatus.DELIVERY_PARTNER_AT_RESTAURANT
    elif status_in.status == DeliveryAssignmentStatus.PICKED_UP:
        assignment.picked_up_at = datetime.utcnow()
        order.status = OrderStatus.PICKED_UP
    elif status_in.status == DeliveryAssignmentStatus.OUT_FOR_DELIVERY:
        order.status = OrderStatus.OUT_FOR_DELIVERY
    elif status_in.status == DeliveryAssignmentStatus.ARRIVED_AT_CUSTOMER:
        order.status = OrderStatus.NEAR_CUSTOMER
    elif status_in.status == DeliveryAssignmentStatus.DELIVERED:
        assignment.delivered_at = datetime.utcnow()
        order.status = OrderStatus.DELIVERED
        order.payment_status = "COMPLETED"
        dp.total_earnings_paise += 5000

    db.commit()
    db.refresh(assignment)
    return assignment
