import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import sys, os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app
from app.database import Base, get_db
from app.models import (
    User, UserRole, Restaurant, FoodCategory, FoodItem, Order,
    OrderStatus, Coupon, CouponUsage, DeliveryPartner, Favorite, Notification
)
from app.auth import get_password_hash

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

client = TestClient(app)

def test_public_registration_cannot_create_admin():
    reg_resp = client.post(
        "/auth/register",
        json={
            "email": "hacker@test.com",
            "password": "password123",
            "full_name": "Hacker User",
            "role": "ADMIN"
        }
    )
    assert reg_resp.status_code == 200
    assert reg_resp.json()["user"]["role"] == "CUSTOMER"

def test_coupon_engine_strict_rules_and_calculations():
    db = TestingSessionLocal()
    # Create Customer
    customer = User(
        email="coupon_user@test.com",
        hashed_password=get_password_hash("password123"),
        full_name="Coupon Tester",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    # Create Restaurant
    rest = Restaurant(
        name="Burger Haven",
        cuisine="American",
        delivery_fee_paise=3000,
        min_order_paise=10000,
        is_active=True,
        is_approved=True,
        is_open=True
    )
    db.add_all([customer, rest])
    db.commit()
    db.refresh(customer)
    db.refresh(rest)

    # 1. Percentage coupon with cap
    c_percent = Coupon(
        code="SAVE50",
        title="50% OFF",
        discount_type="PERCENTAGE",
        discount_value=50,
        min_order_paise=20000, # ₹200
        max_discount_paise=10000, # Max ₹100
        usage_limit=10,
        per_user_limit=1,
        is_active=True
    )
    # 2. Flat coupon
    c_flat = Coupon(
        code="FLAT75",
        title="Flat ₹75",
        discount_type="FLAT",
        discount_value=7500,
        min_order_paise=15000,
        is_active=True
    )
    # 3. Expired coupon
    c_expired = Coupon(
        code="OLDEXPIRED",
        discount_type="PERCENTAGE",
        discount_value=20,
        is_active=True,
        end_date=datetime.utcnow() - timedelta(days=2)
    )
    # 4. Inactive coupon
    c_inactive = Coupon(
        code="INACTIVE10",
        discount_type="PERCENTAGE",
        discount_value=10,
        is_active=False
    )
    # 5. Restaurant specific coupon
    c_rest_specific = Coupon(
        code="BURGERONLY",
        discount_type="PERCENTAGE",
        discount_value=25,
        restaurant_id=rest.id,
        is_active=True
    )
    db.add_all([c_percent, c_flat, c_expired, c_inactive, c_rest_specific])
    db.commit()

    # Login customer
    login = client.post("/auth/login", data={"username": "coupon_user@test.com", "password": "password123"})
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Case A: Valid SAVE50 with subtotal ₹300 (30000 paise). 50% = 15000, capped at 10000 (₹100).
    val_resp = client.post(
        "/coupons/validate",
        json={"code": "SAVE50", "restaurant_id": rest.id, "subtotal_paise": 30000, "delivery_fee_paise": 3000},
        headers=headers
    )
    assert val_resp.status_code == 200
    res_data = val_resp.json()
    assert res_data["valid"] is True
    assert res_data["discount_paise"] == 10000

    # Case B: Min order failure for SAVE50 (subtotal 15000 < min 20000)
    val_fail = client.post(
        "/coupons/validate",
        json={"code": "SAVE50", "restaurant_id": rest.id, "subtotal_paise": 15000, "delivery_fee_paise": 3000},
        headers=headers
    )
    assert val_fail.status_code == 200
    assert val_fail.json()["valid"] is False
    assert "Min order" in val_fail.json()["message"]

    # Case C: Expired coupon
    val_exp = client.post(
        "/coupons/validate",
        json={"code": "OLDEXPIRED", "restaurant_id": rest.id, "subtotal_paise": 30000},
        headers=headers
    )
    assert val_exp.json()["valid"] is False
    assert "expired" in val_exp.json()["message"].lower()

    # Case D: Inactive coupon
    val_inact = client.post(
        "/coupons/validate",
        json={"code": "INACTIVE10", "restaurant_id": rest.id, "subtotal_paise": 30000},
        headers=headers
    )
    assert val_inact.json()["valid"] is False
    assert "inactive" in val_inact.json()["message"].lower()

    # Case E: Restaurant mismatch
    val_mismatch = client.post(
        "/coupons/validate",
        json={"code": "BURGERONLY", "restaurant_id": 9999, "subtotal_paise": 30000},
        headers=headers
    )
    assert val_mismatch.json()["valid"] is False
    assert "only valid at" in val_mismatch.json()["message"]

    # Case F: Flat coupon calculation
    val_flat = client.post(
        "/coupons/validate",
        json={"code": "FLAT75", "restaurant_id": rest.id, "subtotal_paise": 20000},
        headers=headers
    )
    assert val_flat.json()["valid"] is True
    assert val_flat.json()["discount_paise"] == 7500

    db.close()

def test_favorites_reorder_and_cancellation():
    db = TestingSessionLocal()
    # 1. Setup Users & Restaurant
    customer = User(
        email="test_cust@foodflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="Alice Customer",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    owner = User(
        email="owner_italian@foodflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="Mario Chef",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    rest = Restaurant(
        name="Mario Pizzeria",
        cuisine="Italian",
        delivery_fee_paise=3000,
        min_order_paise=10000,
        is_active=True,
        is_approved=True,
        is_open=True
    )
    db.add_all([customer, owner, rest])
    db.commit()
    db.refresh(customer)
    db.refresh(owner)
    db.refresh(rest)

    rest.owner_id = owner.id
    food1 = FoodItem(restaurant_id=rest.id, name="Cheese Pizza", price_paise=25000, is_available=True)
    food2 = FoodItem(restaurant_id=rest.id, name="Garlic Bread", price_paise=10000, is_available=True)
    db.add_all([food1, food2])
    db.commit()
    db.refresh(food1)
    db.refresh(food2)

    # 2. Login customer
    cust_login = client.post("/auth/login", data={"username": "test_cust@foodflow.com", "password": "password123"})
    cust_token = cust_login.json()["access_token"]
    cust_headers = {"Authorization": f"Bearer {cust_token}"}

    # 3. Test Favorites API
    fav_add = client.post(f"/users/favorites/{rest.id}", headers=cust_headers)
    assert fav_add.status_code == 200
    assert fav_add.json()["is_favorite"] is True

    fav_list = client.get("/users/favorites", headers=cust_headers)
    assert fav_list.status_code == 200
    assert len(fav_list.json()) == 1
    assert fav_list.json()[0]["id"] == rest.id

    fav_ids = client.get("/users/favorites/ids", headers=cust_headers)
    assert fav_ids.status_code == 200
    assert rest.id in fav_ids.json()

    # 4. Test Add To Cart & Create Order with Coupon
    c_order = Coupon(
        code="MARIO20",
        discount_type="PERCENTAGE",
        discount_value=20,
        max_discount_paise=5000,
        min_order_paise=10000,
        is_active=True
    )
    db.add(c_order)
    db.commit()

    cart_add1 = client.post("/cart/items", json={"food_item_id": food1.id, "quantity": 1}, headers=cust_headers)
    assert cart_add1.status_code == 200
    cart_add2 = client.post("/cart/items", json={"food_item_id": food2.id, "quantity": 1}, headers=cust_headers)
    assert cart_add2.status_code == 200

    # Place order with coupon
    order_req = client.post(
        "/orders",
        json={
            "delivery_address": "Flat 101, Park Street",
            "payment_method": "ONLINE",
            "coupon_code": "MARIO20"
        },
        headers=cust_headers
    )
    assert order_req.status_code == 200
    order_data = order_req.json()
    order_id = order_data["id"]
    # Subtotal: 25000 + 10000 = 35000. 20% of 35000 = 7000, capped at 5000.
    assert order_data["subtotal_paise"] == 35000
    assert order_data["discount_paise"] == 5000
    assert order_data["total_paise"] == 35000 + 3000 + int(35000 * 0.05) - 5000

    # Check notification created for customer
    notif_resp = client.get("/notifications", headers=cust_headers)
    assert notif_resp.status_code == 200
    assert len(notif_resp.json()) >= 1
    assert "Order Placed" in notif_resp.json()[0]["title"]

    # 5. Test Cancellation Rules
    # Customer cancels PLACED order
    cancel_resp = client.post(
        f"/orders/{order_id}/cancel",
        json={"reason": "Changed my dinner plans"},
        headers=cust_headers
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "CANCELLED"
    assert cancel_resp.json()["is_refunded"] is True

    # Attempting to re-cancel should fail
    re_cancel = client.post(
        f"/orders/{order_id}/cancel",
        json={"reason": "Duplicate cancel"},
        headers=cust_headers
    )
    assert re_cancel.status_code == 400

    # 6. Test Reorder Endpoint
    reorder_resp = client.post(f"/orders/{order_id}/reorder", headers=cust_headers)
    assert reorder_resp.status_code == 200
    reorder_data = reorder_resp.json()
    assert reorder_data["success"] is True
    assert reorder_data["added_items_count"] == 2
    assert reorder_data["cart_summary"]["subtotal_paise"] == 35000

    db.close()

def test_owner_and_admin_promotions_and_analytics():
    db = TestingSessionLocal()
    # Seed Admin & Owner
    admin = User(
        email="shahinsha@foodflow.com",
        hashed_password=get_password_hash("262007"),
        full_name="Super Admin",
        role=UserRole.ADMIN,
        is_active=True,
        is_approved=True
    )
    owner = User(
        email="boss@foodflow.com",
        hashed_password=get_password_hash("password123"),
        full_name="Boss Owner",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    rest = Restaurant(
        name="Grand Feast",
        cuisine="Continental",
        delivery_fee_paise=2500,
        min_order_paise=10000,
        is_active=True,
        is_approved=True,
        is_open=True
    )
    db.add_all([admin, owner, rest])
    db.commit()
    db.refresh(admin)
    db.refresh(owner)
    db.refresh(rest)
    rest.owner_id = owner.id
    db.commit()

    # Login Admin
    admin_login = client.post("/auth/login", data={"username": "shahinsha@foodflow.com", "password": "262007"})
    admin_token = admin_login.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Admin creates platform-wide promotion
    promo_resp = client.post(
        "/admin/promotions",
        json={
            "code": "SUPERADMIN50",
            "title": "Admin Mega Sale",
            "description": "50% off everywhere",
            "discount_type": "PERCENTAGE",
            "discount_value": 50,
            "min_order_paise": 20000,
            "max_discount_paise": 15000,
            "usage_limit": 500
        },
        headers=admin_headers
    )
    assert promo_resp.status_code == 200
    promo_id = promo_resp.json()["id"]

    # 2. Admin fetches promotions list & analytics
    admin_promos = client.get("/admin/promotions?status_filter=active", headers=admin_headers)
    assert admin_promos.status_code == 200
    assert any(p["code"] == "SUPERADMIN50" for p in admin_promos.json())

    admin_analytics = client.get("/admin/analytics?timeframe=30d", headers=admin_headers)
    assert admin_analytics.status_code == 200
    assert "gross_order_value_paise" in admin_analytics.json()

    # 3. Owner login & creates restaurant promotion
    owner_login = client.post("/auth/login", data={"username": "boss@foodflow.com", "password": "password123"})
    owner_token = owner_login.json()["access_token"]
    owner_headers = {"Authorization": f"Bearer {owner_token}"}

    owner_promo = client.post(
        "/owner/promotions",
        json={
            "code": "FEAST20",
            "title": "20% Grand Feast",
            "discount_type": "PERCENTAGE",
            "discount_value": 20,
            "min_order_paise": 15000,
            "max_discount_paise": 6000
        },
        headers=owner_headers
    )
    assert owner_promo.status_code == 200
    assert owner_promo.json()["restaurant_id"] == rest.id

    # Owner analytics
    owner_analytics = client.get("/owner/analytics", headers=owner_headers)
    assert owner_analytics.status_code == 200
    assert "average_order_value_paise" in owner_analytics.json()

    db.close()
