# FoodFlow System Architecture

## 1. Overview
FoodFlow is an end-to-end, multi-role food delivery platform consisting of a high-performance **FastAPI** backend microservice and a cross-platform **Flutter** client application supporting 4 distinct user personas:
1. **Customer:** Discovery, cart management, saved address book, checkout, coupons, real-time live map tracking, and verified reviews.
2. **Restaurant Owner:** Restaurant profile, categories & food item management, availability toggles, incoming orders queue, and preparation status updates.
3. **Delivery Partner:** Vehicle profile, online/offline status toggle, assigned deliveries, GPS location streaming, status progression, and earnings dashboard.
4. **Admin:** System metrics, user account management, restaurant approval workflow, coupon configuration, live operations map, and audit logs.

---

## 2. Technical Stack
- **Frontend:** Flutter 3, Dart 3, Material 3, Riverpod 2 (State Management), GoRouter 14 (Routing), Dio 5 (HTTP Client), `flutter_map` (OpenStreetMap Tile Rendering), `web_socket_channel` (Bi-directional Live GPS Streaming), Cached Network Image, Google Fonts.
- **Backend:** Python 3.11, FastAPI, WebSockets (`/tracking/ws/{order_id}`), SQLAlchemy ORM, Pydantic V2, Passlib (`bcrypt`), PyJWT / Python-Jose, SQLite / PostgreSQL.
- **Financial Precision:** All monetary amounts (prices, GST taxes, delivery fees, discounts, subtotals, totals) are processed and stored as **integer paise** (`100 paise = ₹1.00`) to prevent floating-point rounding errors.
