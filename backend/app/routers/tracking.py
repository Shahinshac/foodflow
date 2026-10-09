from typing import Dict, List, Set
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import (
    User, Order, OrderStatus, DeliveryPartner, DeliveryAssignment,
    DeliveryLocationLog, OrderStatusHistory, UserRole
)
from ..schemas import LocationUpdateSchema, LiveTrackingResponse
from ..auth import get_current_user, require_delivery_partner

router = APIRouter(prefix="/tracking", tags=["Live Tracking & GPS Engine"])

# WebSocket Connection Manager for live order streams
class TrackingConnectionManager:
    def __init__(self):
        # Maps order_id -> Set of active WebSockets
        self.active_connections: Dict[int, Set[WebSocket]] = {}

    async def connect(self, order_id: int, websocket: WebSocket):
        await websocket.accept()
        if order_id not in self.active_connections:
            self.active_connections[order_id] = set()
        self.active_connections[order_id].add(websocket)

    def disconnect(self, order_id: int, websocket: WebSocket):
        if order_id in self.active_connections:
            self.active_connections[order_id].remove(websocket)
            if not self.active_connections[order_id]:
                del self.active_connections[order_id]

    async def broadcast_to_order(self, order_id: int, message: dict):
        if order_id in self.active_connections:
            to_remove = set()
            for ws in self.active_connections[order_id]:
                try:
                    await ws.send_json(message)
                except Exception:
                    to_remove.add(ws)
            for ws in to_remove:
                self.disconnect(order_id, ws)

manager = TrackingConnectionManager()

@router.get("/order/{order_id}", response_model=LiveTrackingResponse)
def get_live_tracking_snapshot(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Verify authorization
    if current_user.role == UserRole.CUSTOMER and order.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Unauthorized to track this order")

    # Find active assignment
    assignment = db.query(DeliveryAssignment).filter(DeliveryAssignment.order_id == order_id).first()
    rider_lat = None
    rider_lng = None
    rider_heading = 0.0
    rider_speed = 0.0
    rider_name = None
    rider_phone = None
    last_updated = None
    rider_assigned = False

    if assignment and assignment.delivery_partner:
        dp = assignment.delivery_partner
        rider_assigned = True
        rider_lat = dp.current_lat
        rider_lng = dp.current_lng
        rider_heading = dp.heading or 0.0
        rider_speed = dp.speed or 0.0
        rider_name = dp.user.full_name
        rider_phone = dp.user.phone or "+1-800-FOODFLOW"
        last_updated = dp.last_location_update

    return LiveTrackingResponse(
        order_id=order.id,
        status=order.status,
        calculated_eta_minutes=order.calculated_eta_minutes,
        is_delayed=order.is_delayed,
        restaurant_name=order.restaurant.name,
        restaurant_lat=order.restaurant.latitude,
        restaurant_lng=order.restaurant.longitude,
        restaurant_address=order.restaurant.address_text,
        delivery_lat=order.delivery_lat,
        delivery_lng=order.delivery_lng,
        delivery_address=order.delivery_address,
        rider_assigned=rider_assigned,
        rider_name=rider_name,
        rider_phone=rider_phone,
        rider_lat=rider_lat,
        rider_lng=rider_lng,
        rider_heading=rider_heading,
        rider_speed=rider_speed,
        last_updated_at=last_updated
    )

@router.post("/location")
async def update_delivery_location(
    loc_in: LocationUpdateSchema,
    current_user: User = Depends(require_delivery_partner),
    db: Session = Depends(get_db)
):
    dp = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == current_user.id).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Delivery partner profile not found")

    # Verify active assignment
    assignment = db.query(DeliveryAssignment).filter(
        DeliveryAssignment.order_id == loc_in.order_id,
        DeliveryAssignment.delivery_partner_id == dp.id
    ).first()

    if not assignment:
        raise HTTPException(status_code=403, detail="Rider is not assigned to this order")

    now = datetime.utcnow()

    # 1. Update Partner Profile Location
    dp.current_lat = loc_in.latitude
    dp.current_lng = loc_in.longitude
    dp.heading = loc_in.heading or 0.0
    dp.speed = loc_in.speed or 0.0
    dp.last_location_update = now

    # 2. Log GPS point
    log = DeliveryLocationLog(
        delivery_partner_id=dp.id,
        order_id=loc_in.order_id,
        latitude=loc_in.latitude,
        longitude=loc_in.longitude,
        accuracy=loc_in.accuracy,
        heading=loc_in.heading,
        speed=loc_in.speed,
        timestamp=now
    )
    db.add(log)
    db.commit()

    # 3. Broadcast real-time WS event
    payload = {
        "event": "LOCATION_UPDATED",
        "order_id": loc_in.order_id,
        "rider_lat": loc_in.latitude,
        "rider_lng": loc_in.longitude,
        "rider_heading": loc_in.heading,
        "rider_speed": loc_in.speed,
        "timestamp": now.isoformat()
    }
    await manager.broadcast_to_order(loc_in.order_id, payload)

    return {"status": "success", "message": "Location updated and broadcasted"}

@router.websocket("/ws/{order_id}")
async def websocket_tracking_endpoint(websocket: WebSocket, order_id: int):
    await manager.connect(order_id, websocket)
    try:
        while True:
            # Keep connection alive
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(order_id, websocket)
