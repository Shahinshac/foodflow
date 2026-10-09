# FoodFlow Real Live Map Tracking & Adaptive GPS Architecture

## 1. Overview & Principles
Inspired by the live tracking experience of platforms like Swiggy and Zomato, FoodFlow features an authoritative real-time location streaming engine. Rather than relying on static status messages or artificial animations, FoodFlow streams actual GPS coordinate updates from the Delivery Partner's device to the Customer's map.

---

## 2. Live Map Architecture

```
Delivery Partner GPS (Device)
           │
           ▼ (HTTP POST /tracking/location or WS)
FastAPI Backend (GPS Engine & Location Log)
           │
           ▼ (WebSocket Broadcast /ws/tracking/{order_id})
Flutter Customer App (Live Interactive OpenStreetMap + Markers + ETA)
```

### Components
1. **Interactive OpenStreetMap Canvas (`flutter_map`):** Renders dynamic tiles and polylines without paid Google API keys.
2. **Custom Map Markers:**
   - **Restaurant Marker:** Amber icon anchored at restaurant coordinates (`latitude`, `longitude`).
   - **Customer Destination Marker:** Red pin anchored at customer saved address coordinates.
   - **Rider Partner Marker:** Animated orange motorbike marker that rotates according to the rider's GPS heading angle.
3. **Adaptive Tracking Frequency:**
   - **Active Delivery:** GPS updates sent every 3–10 seconds depending on rider movement.
   - **Stationary / Delivered / Cancelled:** Tracking frequency reduced or terminated.
4. **WebSocket & REST Polling Fallback:**
   - Primary: Bi-directional WebSocket channel (`ws://localhost:8000/tracking/ws/{order_id}`).
   - Fallback: Periodic REST polling (`GET /tracking/order/{order_id}`) every 6 seconds when WebSocket drops.

---

## 3. Data Schema

### GPS Update Payload (`POST /tracking/location`)
```json
{
  "order_id": 101,
  "latitude": 12.9480,
  "longitude": 77.6180,
  "accuracy": 4.5,
  "heading": 180.0,
  "speed": 12.5
}
```

### Live Tracking Snapshot Response (`GET /tracking/order/{order_id}`)
```json
{
  "order_id": 101,
  "status": "OUT_FOR_DELIVERY",
  "calculated_eta_minutes": 18,
  "is_delayed": false,
  "restaurant_name": "Urban Spice Grill",
  "restaurant_lat": 12.9352,
  "restaurant_lng": 77.6245,
  "restaurant_address": "Block 4, Koramangala Food Street",
  "delivery_lat": 12.9716,
  "delivery_lng": 77.5946,
  "delivery_address": "123 Tech Park, Suite 400",
  "rider_assigned": true,
  "rider_name": "Sam Rider (Delivery Partner)",
  "rider_phone": "+1122334455",
  "rider_lat": 12.9480,
  "rider_lng": 77.6180,
  "rider_heading": 180.0,
  "rider_speed": 12.5,
  "last_updated_at": "2026-03-29T10:15:30Z"
}
```
