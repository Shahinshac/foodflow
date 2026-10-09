# FoodFlow API Documentation

## Authentication & Authorization
Base URL: `http://localhost:8000` (or `http://10.0.2.2:8000` on Android Emulator).
All protected routes require standard HTTP header: `Authorization: Bearer <JWT_ACCESS_TOKEN>`.

### Authentication Endpoints (`/auth`)
- `POST /auth/register`: Create user account (`email`, `password`, `full_name`, `phone`, `role: CUSTOMER | RESTAURANT_OWNER | DELIVERY_PARTNER | ADMIN`).
- `POST /auth/login`: Authenticate OAuth2 password credentials (`username`, `password`). Returns JWT access token & user profile.
- `GET /auth/me`: Query current authenticated user profile.

### Customer Endpoints
- `GET /restaurants`: List active restaurants with optional `query` and `cuisine` filters.
- `GET /restaurants/{id}`: Detailed restaurant info, categories, and foods.
- `GET /restaurants/{id}/foods`: Query menu items for a restaurant.
- `GET /users/addresses`, `POST /users/addresses`, `DELETE /users/addresses/{id}`: Address book management.
- `GET /cart`, `POST /cart/items`, `PUT /cart/items/{id}`, `DELETE /cart/items/{id}`, `DELETE /cart/clear`: Cart management.
- `POST /orders`: Atomically create order from user cart items.
- `GET /orders`: List user's active & historical orders.
- `GET /orders/{id}`: Detailed order breakdown and timeline.
- `GET /tracking/order/{id}`: Real-time Live Tracking REST snapshot.
- `WebSocket /tracking/ws/{id}`: Bi-directional WebSocket channel for live GPS location updates and order state changes.
- `POST /reviews`: Create verified review for delivered orders.

### Restaurant Owner Endpoints (`/owner`)
- `GET /owner/restaurant`: Query owned restaurant details.
- `POST /owner/restaurant`: Register new restaurant.
- `POST /owner/categories`: Create food category.
- `POST /owner/foods`: Create food item.
- `PUT /owner/foods/{id}/toggle-availability`: Toggle food availability (In Stock / Out of Stock).
- `GET /owner/orders`: Query incoming orders queue for owned restaurant.
- `PUT /owner/orders/{id}/status`: Transition order status (`RESTAURANT_CONFIRMED`, `REJECTED`, `PREPARING`, `READY_FOR_PICKUP`).

### Delivery Partner Endpoints (`/delivery` & `/tracking`)
- `GET /delivery/profile`: Query delivery profile & total earnings.
- `PUT /delivery/toggle-online`: Toggle online/offline status.
- `GET /delivery/available-orders`: Query and receive available delivery assignments.
- `PUT /delivery/assignments/{id}/status`: Transition delivery status (`ARRIVED_AT_RESTAURANT`, `PICKED_UP`, `OUT_FOR_DELIVERY`, `ARRIVED_AT_CUSTOMER`, `DELIVERED`).
- `POST /tracking/location`: Stream real-time GPS coordinates (`order_id`, `latitude`, `longitude`, `accuracy`, `heading`, `speed`).

### Admin Endpoints (`/admin`)
- `GET /admin/metrics`: Real-time system analytics dashboard (users, restaurants, partners, orders, revenue).
- `GET /admin/users`: List all registered users.
- `PUT /admin/users/{id}/toggle-active`: Activate or disable user account.
- `GET /admin/restaurants`: List all registered restaurants.
- `PUT /admin/restaurants/{id}/approve`: Approve restaurant for public listing.
- `GET /admin/coupons`, `POST /admin/coupons`: Manage discount coupons.
