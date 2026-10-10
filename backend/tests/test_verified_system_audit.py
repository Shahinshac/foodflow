import pytest
from datetime import datetime, timedelta
import sys, os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tests.conftest import engine, TestingSessionLocal, client
from app.models import (
    User, UserRole, Restaurant, FoodCategory, FoodItem, Order,
    OrderStatus, Coupon, CouponUsage, DeliveryPartner, DeliveryAssignment,
    DeliveryAssignmentStatus, DeliveryLocationLog, OrderStatusHistory, CartItem
)
from app.auth import get_password_hash, create_access_token

# ============================================================================
# 1. LIVE GPS AND REAL-TIME TRACKING TESTS
# ============================================================================

def test_gps_tracking_permissions_and_updates():
    db = TestingSessionLocal()
    # Create Customer, Owner, Restaurant, and 2 Delivery Partners
    cust = User(email="gps_cust@foodflow.com", hashed_password=get_password_hash("pass"), full_name="GPS Customer", role=UserRole.CUSTOMER, is_active=True, is_approved=True)
    other_cust = User(email="other_cust@foodflow.com", hashed_password=get_password_hash("pass"), full_name="Other Cust", role=UserRole.CUSTOMER, is_active=True, is_approved=True)
    owner = User(email="gps_owner@foodflow.com", hashed_password=get_password_hash("pass"), full_name="GPS Owner", role=UserRole.RESTAURANT_OWNER, is_active=True, is_approved=True)
    driver1_user = User(email="driver1@foodflow.com", hashed_password=get_password_hash("pass"), full_name="Driver One", role=UserRole.DELIVERY_PARTNER, is_active=True, is_approved=True)
    driver2_user = User(email="driver2@foodflow.com", hashed_password=get_password_hash("pass"), full_name="Driver Two", role=UserRole.DELIVERY_PARTNER, is_active=True, is_approved=True)
    
    rest = Restaurant(name="GPS Cafe", cuisine="Cafe", delivery_fee_paise=3000, min_order_paise=10000, is_approved=True, is_active=True, is_open=True)
    
    db.add_all([cust, other_cust, owner, driver1_user, driver2_user, rest])
    db.commit()
    db.refresh(cust)
    db.refresh(other_cust)
    db.refresh(driver1_user)
    db.refresh(driver2_user)
    db.refresh(rest)
    
    dp1 = DeliveryPartner(user_id=driver1_user.id, vehicle_type="Bike", vehicle_number="KA-01-1111", is_online=True, is_verified=True)
    dp2 = DeliveryPartner(user_id=driver2_user.id, vehicle_type="Bike", vehicle_number="KA-01-2222", is_online=True, is_verified=True)
    db.add_all([dp1, dp2])
    db.commit()
    db.refresh(dp1)
    db.refresh(dp2)

    # Create Order for Customer
    order = Order(
        user_id=cust.id,
        restaurant_id=rest.id,
        status=OrderStatus.OUT_FOR_DELIVERY,
        subtotal_paise=20000,
        delivery_fee_paise=3000,
        tax_paise=1000,
        discount_paise=0,
        total_paise=24000,
        delivery_address="123 Main St",
        delivery_lat=12.9716,
        delivery_lng=77.5946,
        payment_method="COD"
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    # Assign DP1 to Order
    assignment = DeliveryAssignment(order_id=order.id, delivery_partner_id=dp1.id, status=DeliveryAssignmentStatus.OUT_FOR_DELIVERY)
    db.add(assignment)
    db.commit()

    # Tokens
    cust_token = create_access_token({"sub": cust.email})
    other_cust_token = create_access_token({"sub": other_cust.email})
    dp1_token = create_access_token({"sub": driver1_user.email})
    dp2_token = create_access_token({"sub": driver2_user.email})

    # Test 1A: DP1 publishes valid GPS location
    loc_payload = {
        "order_id": order.id,
        "latitude": 12.9352,
        "longitude": 77.6245,
        "accuracy": 5.0,
        "heading": 180.0,
        "speed": 22.5
    }
    resp1 = client.post("/tracking/location", json=loc_payload, headers={"Authorization": f"Bearer {dp1_token}"})
    assert resp1.status_code == 200
    assert resp1.json()["status"] == "success"

    # Verify DB update on DeliveryPartner & DeliveryLocationLog
    db.refresh(dp1)
    assert dp1.current_lat == 12.9352
    assert dp1.current_lng == 77.6245
    assert dp1.heading == 180.0
    assert dp1.speed == 22.5
    logs = db.query(DeliveryLocationLog).filter(DeliveryLocationLog.order_id == order.id).all()
    assert len(logs) == 1
    assert logs[0].latitude == 12.9352

    # Test 1B: DP2 (unassigned) tries to publish location for DP1's order -> 403 Forbidden
    resp_unauth_dp = client.post("/tracking/location", json=loc_payload, headers={"Authorization": f"Bearer {dp2_token}"})
    assert resp_unauth_dp.status_code == 403
    assert "not assigned" in resp_unauth_dp.json()["detail"].lower()

    # Test 1C: Customer retrieves live tracking snapshot
    snap_resp = client.get(f"/tracking/order/{order.id}", headers={"Authorization": f"Bearer {cust_token}"})
    assert snap_resp.status_code == 200
    snap_data = snap_resp.json()
    assert snap_data["rider_assigned"] is True
    assert snap_data["rider_lat"] == 12.9352
    assert snap_data["rider_lng"] == 77.6245
    assert snap_data["rider_heading"] == 180.0

    # Test 1D: Other Customer (unauthorized) tries to track -> 403 Forbidden
    unauth_snap = client.get(f"/tracking/order/{order.id}", headers={"Authorization": f"Bearer {other_cust_token}"})
    assert unauth_snap.status_code == 403
    assert "unauthorized" in unauth_snap.json()["detail"].lower()

    db.close()


# ============================================================================
# 2. COUPON AND ORDER TOTAL MATHEMATICAL & BOUNDARY ASSERTIONS
# ============================================================================

def test_coupon_boundary_and_total_calculations():
    db = TestingSessionLocal()
    cust = User(email="math_cust@foodflow.com", hashed_password=get_password_hash("pass"), full_name="Math Customer", role=UserRole.CUSTOMER, is_active=True, is_approved=True)
    rest = Restaurant(name="Math Diner", cuisine="Fast Food", delivery_fee_paise=4000, min_order_paise=10000, is_approved=True, is_active=True, is_open=True)
    db.add_all([cust, rest])
    db.commit()
    db.refresh(cust)
    db.refresh(rest)

    food_burger = FoodItem(restaurant_id=rest.id, name="Double Cheeseburger", price_paise=15000, is_available=True)
    food_shake = FoodItem(restaurant_id=rest.id, name="Chocolate Shake", price_paise=8000, is_available=True)
    food_soldout = FoodItem(restaurant_id=rest.id, name="Sold Out Fries", price_paise=5000, is_available=False)
    db.add_all([food_burger, food_shake, food_soldout])
    db.commit()
    db.refresh(food_burger)
    db.refresh(food_shake)
    db.refresh(food_soldout)

    # Create coupons
    c_percent = Coupon(code="MEGADEAL", discount_type="PERCENTAGE", discount_value=50, min_order_paise=20000, max_discount_paise=10000, usage_limit=5, per_user_limit=2, is_active=True)
    c_flat = Coupon(code="FLAT50", discount_type="FLAT", discount_value=5000, min_order_paise=15000, usage_limit=10, per_user_limit=1, is_active=True)
    c_freedel = Coupon(code="FREEDEL", discount_type="FREE_DELIVERY", discount_value=0, min_order_paise=10000, usage_limit=10, per_user_limit=1, is_active=True)
    db.add_all([c_percent, c_flat, c_freedel])
    db.commit()

    cust_token = create_access_token({"sub": cust.email})
    headers = {"Authorization": f"Bearer {cust_token}"}

    # Case 2A: Empty cart order attempt -> 400 Bad Request
    resp_empty = client.post("/orders", json={"delivery_address": "Test", "payment_method": "COD"}, headers=headers)
    assert resp_empty.status_code == 400
    assert "empty" in resp_empty.json()["detail"].lower()

    # Case 2B: Add unavailable food item -> 400 Bad Request
    client.post("/cart/items", json={"food_item_id": food_soldout.id, "quantity": 1}, headers=headers)
    resp_unavail = client.post("/orders", json={"delivery_address": "Test", "payment_method": "COD"}, headers=headers)
    assert resp_unavail.status_code == 400
    assert "unavailable" in resp_unavail.json()["detail"].lower()
    
    # Clear cart
    client.delete("/cart/clear", headers=headers)

    # Case 2C: Mathematical breakdown with Percentage Coupon (Capped)
    # 2 Burgers = 30000 paise (₹300). Delivery = 4000 paise (₹40). Tax = 5% of 30000 = 1500 paise (₹15).
    # Discount: 50% of 30000 = 15000, capped at max 10000 paise (₹100).
    # Total: 30000 + 4000 + 1500 - 10000 = 25500 paise (₹255.00).
    client.post("/cart/items", json={"food_item_id": food_burger.id, "quantity": 2}, headers=headers)
    resp_order1 = client.post(
        "/orders",
        json={"delivery_address": "Flat 4B", "payment_method": "COD", "coupon_code": "MEGADEAL"},
        headers=headers
    )
    assert resp_order1.status_code == 200
    o1 = resp_order1.json()
    assert o1["subtotal_paise"] == 30000
    assert o1["delivery_fee_paise"] == 4000
    assert o1["tax_paise"] == 1500
    assert o1["discount_paise"] == 10000
    assert o1["total_paise"] == 25500
    assert o1["coupon_code"] == "MEGADEAL"

    # Case 2D: Flat discount coupon
    # 1 Burger + 1 Shake = 23000 paise (₹230). Delivery = 4000. Tax = 5% of 23000 = 1150 paise.
    # Discount: Flat 5000 paise (₹50).
    # Total: 23000 + 4000 + 1150 - 5000 = 23150 paise (₹231.50).
    client.post("/cart/items", json={"food_item_id": food_burger.id, "quantity": 1}, headers=headers)
    client.post("/cart/items", json={"food_item_id": food_shake.id, "quantity": 1}, headers=headers)
    resp_order2 = client.post(
        "/orders",
        json={"delivery_address": "Flat 4B", "payment_method": "ONLINE", "coupon_code": "FLAT50"},
        headers=headers
    )
    assert resp_order2.status_code == 200
    o2 = resp_order2.json()
    assert o2["subtotal_paise"] == 23000
    assert o2["delivery_fee_paise"] == 4000
    assert o2["tax_paise"] == 1150
    assert o2["discount_paise"] == 5000
    assert o2["total_paise"] == 23150

    # Case 2E: Repeated use of FLAT50 (per_user_limit=1) -> rejected on next attempt
    client.post("/cart/items", json={"food_item_id": food_burger.id, "quantity": 1}, headers=headers)
    client.post("/cart/items", json={"food_item_id": food_shake.id, "quantity": 1}, headers=headers)
    resp_order_reuse = client.post(
        "/orders",
        json={"delivery_address": "Flat 4B", "payment_method": "COD", "coupon_code": "FLAT50"},
        headers=headers
    )
    assert resp_order_reuse.status_code == 400
    assert "maximum allowed" in resp_order_reuse.json()["detail"]

    # Case 2F: Free delivery coupon
    # Clear cart and add 1 Burger = 15000 paise. Delivery = 4000. Tax = 5% of 15000 = 750 paise.
    # Discount = delivery_fee = 4000.
    # Total = 15000 + 4000 + 750 - 4000 = 15750 paise (₹157.50).
    client.delete("/cart/clear", headers=headers)
    client.post("/cart/items", json={"food_item_id": food_burger.id, "quantity": 1}, headers=headers)
    resp_freedel = client.post(
        "/orders",
        json={"delivery_address": "Flat 4B", "payment_method": "COD", "coupon_code": "FREEDEL"},
        headers=headers
    )
    assert resp_freedel.status_code == 200
    ofd = resp_freedel.json()
    assert ofd["subtotal_paise"] == 15000
    assert ofd["delivery_fee_paise"] == 4000
    assert ofd["tax_paise"] == 750
    assert ofd["discount_paise"] == 4000
    assert ofd["total_paise"] == 15750

    db.close()


# ============================================================================
# 3. ADMIN ANALYTICS AND COMMISSION VERIFICATION
# ============================================================================

def test_admin_analytics_and_status_filtering():
    db = TestingSessionLocal()
    db.query(Order).delete()
    db.query(User).delete()
    db.query(Restaurant).delete()
    db.commit()

    admin = User(email="admin_stat@foodflow.com", hashed_password=get_password_hash("pass"), full_name="Stat Admin", role=UserRole.ADMIN, is_active=True, is_approved=True)
    cust = User(email="stat_cust@foodflow.com", hashed_password=get_password_hash("pass"), full_name="Stat Customer", role=UserRole.CUSTOMER, is_active=True, is_approved=True)
    rest = Restaurant(name="Stat Diner", cuisine="Indian", delivery_fee_paise=3000, min_order_paise=5000, is_approved=True, is_active=True, is_open=True)
    
    db.add_all([admin, cust, rest])
    db.commit()
    db.refresh(admin)
    db.refresh(cust)
    db.refresh(rest)

    # Create 3 Controlled Orders:
    # 1. DELIVERED: subtotal=20000, delivery=3000, tax=1000, discount=2000 -> total=22000
    o1 = Order(user_id=cust.id, restaurant_id=rest.id, status=OrderStatus.DELIVERED, subtotal_paise=20000, delivery_fee_paise=3000, tax_paise=1000, discount_paise=2000, total_paise=22000, delivery_address="Addr 1", payment_method="COD")
    # 2. DELIVERED: subtotal=30000, delivery=3000, tax=1500, discount=5000 -> total=29500
    o2 = Order(user_id=cust.id, restaurant_id=rest.id, status=OrderStatus.DELIVERED, subtotal_paise=30000, delivery_fee_paise=3000, tax_paise=1500, discount_paise=5000, total_paise=29500, delivery_address="Addr 2", payment_method="ONLINE")
    # 3. CANCELLED: subtotal=15000, delivery=3000, tax=750, discount=0 -> total=18750
    o3 = Order(user_id=cust.id, restaurant_id=rest.id, status=OrderStatus.CANCELLED, subtotal_paise=15000, delivery_fee_paise=3000, tax_paise=750, discount_paise=0, total_paise=18750, delivery_address="Addr 3", payment_method="COD")
    # 4. PREPARING (Active In-flight): subtotal=25000, delivery=3000, tax=1250, discount=0 -> total=29250
    o4 = Order(user_id=cust.id, restaurant_id=rest.id, status=OrderStatus.PREPARING, subtotal_paise=25000, delivery_fee_paise=3000, tax_paise=1250, discount_paise=0, total_paise=29250, delivery_address="Addr 4", payment_method="COD")

    db.add_all([o1, o2, o3, o4])
    db.commit()

    admin_token = create_access_token({"sub": admin.email})
    headers = {"Authorization": f"Bearer {admin_token}"}

    # Fetch Admin Analytics
    analytics_resp = client.get("/admin/analytics?timeframe=all", headers=headers)
    assert analytics_resp.status_code == 200
    data = analytics_resp.json()

    # Assert exact numbers:
    # Total Orders = 4
    assert data["total_orders"] == 4
    # Completed Orders = 2 (only o1 and o2)
    assert data["completed_orders"] == 2
    # Cancelled Orders = 1 (o3)
    assert data["cancelled_orders"] == 1
    # Active Orders = 1 (o4)
    assert data["active_orders"] == 1

    # Gross Order Value (GMV) of DELIVERED = (20000+3000+1000) + (30000+3000+1500) = 24000 + 34500 = 58500 paise (₹585.00)
    assert data["gross_order_value_paise"] == 58500

    # Promotion Discounts of DELIVERED = 2000 + 5000 = 7000 paise (₹70.00)
    assert data["promotion_discounts_paise"] == 7000

    # Net Revenue = 22000 + 29500 = 51500 paise (₹515.00)
    assert data["net_revenue_paise"] == 51500

    # Idempotence: Second request returns identical values without duplicating records
    analytics_resp2 = client.get("/admin/analytics?timeframe=all", headers=headers)
    assert analytics_resp2.json() == data

    db.close()


# ============================================================================
# 4. SECURITY AND ROLE ISOLATION NEGATIVE TESTS
# ============================================================================

def test_security_and_role_isolation():
    db = TestingSessionLocal()
    db.query(DeliveryAssignment).delete()
    db.query(DeliveryPartner).delete()
    db.query(Order).delete()
    db.query(FoodItem).delete()
    db.query(Restaurant).delete()
    db.query(User).delete()
    db.commit()

    # 4 Users across distinct roles
    cust_a = User(email="cust_a@sec.com", hashed_password=get_password_hash("pass"), full_name="Cust A", role=UserRole.CUSTOMER, is_active=True, is_approved=True)
    cust_b = User(email="cust_b@sec.com", hashed_password=get_password_hash("pass"), full_name="Cust B", role=UserRole.CUSTOMER, is_active=True, is_approved=True)
    owner_a = User(email="owner_a@sec.com", hashed_password=get_password_hash("pass"), full_name="Owner A", role=UserRole.RESTAURANT_OWNER, is_active=True, is_approved=True)
    owner_b = User(email="owner_b@sec.com", hashed_password=get_password_hash("pass"), full_name="Owner B", role=UserRole.RESTAURANT_OWNER, is_active=True, is_approved=True)
    driver_a = User(email="driver_a@sec.com", hashed_password=get_password_hash("pass"), full_name="Driver A", role=UserRole.DELIVERY_PARTNER, is_active=True, is_approved=True)
    driver_b = User(email="driver_b@sec.com", hashed_password=get_password_hash("pass"), full_name="Driver B", role=UserRole.DELIVERY_PARTNER, is_active=True, is_approved=True)

    rest_a = Restaurant(name="Rest A", cuisine="Italian", is_approved=True, is_active=True, is_open=True)
    rest_b = Restaurant(name="Rest B", cuisine="Chinese", is_approved=True, is_active=True, is_open=True)

    db.add_all([cust_a, cust_b, owner_a, owner_b, driver_a, driver_b, rest_a, rest_b])
    db.commit()
    db.refresh(cust_a)
    db.refresh(cust_b)
    db.refresh(owner_a)
    db.refresh(owner_b)
    db.refresh(driver_a)
    db.refresh(driver_b)
    db.refresh(rest_a)
    db.refresh(rest_b)

    rest_a.owner_id = owner_a.id
    rest_b.owner_id = owner_b.id
    
    dp_a = DeliveryPartner(user_id=driver_a.id, vehicle_number="KA-01-A", is_online=True, is_verified=True)
    dp_b = DeliveryPartner(user_id=driver_b.id, vehicle_number="KA-01-B", is_online=True, is_verified=True)
    food_a = FoodItem(restaurant_id=rest_a.id, name="Pasta Carbonara", price_paise=25000, is_available=True)
    
    order_a = Order(user_id=cust_a.id, restaurant_id=rest_a.id, status=OrderStatus.PLACED, subtotal_paise=25000, delivery_fee_paise=3000, tax_paise=1250, discount_paise=0, total_paise=29250, delivery_address="Cust A Address", payment_method="COD")
    db.add_all([dp_a, dp_b, food_a, order_a])
    db.commit()
    db.refresh(dp_a)
    db.refresh(dp_b)
    db.refresh(food_a)
    db.refresh(order_a)

    assign_a = DeliveryAssignment(order_id=order_a.id, delivery_partner_id=dp_a.id, status=DeliveryAssignmentStatus.ASSIGNED)
    db.add(assign_a)
    db.commit()
    db.refresh(assign_a)

    token_cust_a = create_access_token({"sub": cust_a.email})
    token_cust_b = create_access_token({"sub": cust_b.email})
    token_owner_a = create_access_token({"sub": owner_a.email})
    token_owner_b = create_access_token({"sub": owner_b.email})
    token_driver_a = create_access_token({"sub": driver_a.email})
    token_driver_b = create_access_token({"sub": driver_b.email})

    # Test 4A: Customer cannot access Admin endpoints
    resp_c_admin = client.get("/admin/metrics", headers={"Authorization": f"Bearer {token_cust_a}"})
    assert resp_c_admin.status_code == 403

    # Test 4B: Customer cannot access Owner endpoints
    resp_c_owner = client.get("/owner/restaurant", headers={"Authorization": f"Bearer {token_cust_a}"})
    assert resp_c_owner.status_code == 403

    # Test 4C: Customer cannot access Delivery endpoints
    resp_c_driver = client.get("/delivery/profile", headers={"Authorization": f"Bearer {token_cust_a}"})
    assert resp_c_driver.status_code == 403

    # Test 4D: Owner B cannot edit Owner A's dish availability
    resp_o_dish = client.put(f"/owner/foods/{food_a.id}/toggle-availability", headers={"Authorization": f"Bearer {token_owner_b}"})
    assert resp_o_dish.status_code in [403, 404]

    # Test 4E: Customer B cannot view Customer A's order details
    resp_c_order = client.get(f"/orders/{order_a.id}", headers={"Authorization": f"Bearer {token_cust_b}"})
    assert resp_c_order.status_code in [403, 404]

    # Test 4F: Driver B cannot transition Driver A's assignment
    resp_d_assign = client.put(
        f"/delivery/assignments/{assign_a.id}/status",
        json={"status": "PICKED_UP"},
        headers={"Authorization": f"Bearer {token_driver_b}"}
    )
    assert resp_d_assign.status_code in [403, 404]

    # Test 4G: Public register privilege escalation attempt
    resp_reg_escalate = client.post(
        "/auth/register",
        json={"email": "attacker@evil.com", "password": "password", "full_name": "Attacker", "role": "ADMIN"}
    )
    assert resp_reg_escalate.status_code == 200
    assert resp_reg_escalate.json()["user"]["role"] == "CUSTOMER"

    # Test 4H: Unauthenticated request rejected
    resp_unauth = client.get("/orders", headers={})
    assert resp_unauth.status_code == 401

    # Test 4I: Forged / Invalid token rejected
    resp_forged = client.get("/orders", headers={"Authorization": "Bearer invalid.fake.token"})
    assert resp_forged.status_code == 401

    db.close()
