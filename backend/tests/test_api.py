import pytest
from datetime import datetime, timedelta
import sys, os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tests.conftest import engine, TestingSessionLocal, client
from app.models import (
    User, UserRole, Restaurant, FoodCategory, FoodItem, Order,
    OrderStatus, Coupon, CouponUsage, DeliveryPartner, Favorite, Notification
)
from app.auth import get_password_hash, create_access_token

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


def test_method1_admin_created_restaurant_flow():
    db = TestingSessionLocal()
    admin = User(
        email="admin_m1@foodflow.com",
        hashed_password=get_password_hash("adminpass"),
        full_name="Super Admin",
        role=UserRole.ADMIN,
        is_active=True,
        is_approved=True
    )
    db.add(admin)
    db.commit()

    admin_login = client.post("/auth/login", json={"username": "admin_m1@foodflow.com", "password": "adminpass"})
    assert admin_login.status_code == 200
    admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}

    # 1. Admin creates restaurant and creates a new owner on the fly
    create_resp = client.post(
        "/admin/restaurants",
        json={
            "name": "Admin Direct Palace",
            "cuisine": "North Indian, Mughlai",
            "description": "Grand dining experience",
            "address_text": "Indiranagar 100ft Road",
            "delivery_fee_paise": 4000,
            "min_order_paise": 15000,
            "estimated_delivery_time": "30-40 min",
            "owner_email": "direct_owner@foodflow.com",
            "owner_full_name": "Direct Hotel Owner",
            "owner_password": "ownerpassword123",
            "owner_phone": "9876543210"
        },
        headers=admin_headers
    )
    assert create_resp.status_code == 200
    rest_data = create_resp.json()
    assert rest_data["name"] == "Admin Direct Palace"
    assert rest_data["is_approved"] is True
    assert rest_data["is_active"] is True
    assert rest_data["owner_id"] is not None

    # Verify newly created owner account
    owner_user = db.query(User).filter(User.email == "direct_owner@foodflow.com").first()
    assert owner_user is not None
    assert owner_user.role == UserRole.RESTAURANT_OWNER

    # Verify immediate customer visibility
    cust_resp = client.get("/restaurants")
    assert cust_resp.status_code == 200
    assert any(r["id"] == rest_data["id"] for r in cust_resp.json())

    # 2. Admin creates another restaurant assigning an existing user
    existing_user = User(
        email="existing_user@foodflow.com",
        hashed_password=get_password_hash("pass123"),
        full_name="Existing User",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    db.add(existing_user)
    db.commit()
    db.refresh(existing_user)

    create_resp2 = client.post(
        "/admin/restaurants",
        json={
            "name": "Assigned Pizza Hub",
            "cuisine": "Italian, Pizza",
            "description": "Wood fired pizzas",
            "address_text": "MG Road",
            "delivery_fee_paise": 3500,
            "min_order_paise": 12000,
            "owner_id": existing_user.id
        },
        headers=admin_headers
    )
    assert create_resp2.status_code == 200
    assert create_resp2.json()["owner_id"] == existing_user.id
    assert create_resp2.json()["is_approved"] is True
    assert create_resp2.json()["is_active"] is True

    # User promoted to RESTAURANT_OWNER
    db.refresh(existing_user)
    assert existing_user.role == UserRole.RESTAURANT_OWNER
    db.close()


def test_method2_owner_self_registration_approval_rejection_and_visibility():
    db = TestingSessionLocal()
    admin = User(
        email="admin_m2@foodflow.com",
        hashed_password=get_password_hash("adminpass"),
        full_name="Super Admin",
        role=UserRole.ADMIN,
        is_active=True,
        is_approved=True
    )
    db.add(admin)
    db.commit()

    # 1. Public owner self-registration
    reg_resp = client.post(
        "/auth/register-owner",
        json={
            "full_name": "Applicant Owner",
            "email": "applicant@foodflow.com",
            "password": "applicantpass",
            "phone": "9998887776",
            "restaurant_name": "Applicant Biryani Point",
            "cuisine": "Hyderabadi Biryani",
            "description": "Authentic coal-cooked dum biryani",
            "address_text": "Koramangala 5th Block",
            "delivery_fee_paise": 3000,
            "min_order_paise": 10000,
            "estimated_delivery_time": "25-35 min"
        }
    )
    assert reg_resp.status_code == 200
    reg_data = reg_resp.json()
    assert reg_data["user"]["role"] == "RESTAURANT_OWNER"
    owner_token = reg_data["access_token"]
    owner_headers = {"Authorization": f"Bearer {owner_token}"}

    # 2. Owner checks their restaurant profile
    my_rest = client.get("/owner/restaurant", headers=owner_headers)
    assert my_rest.status_code == 200
    rest_id = my_rest.json()["id"]
    assert my_rest.json()["name"] == "Applicant Biryani Point"
    assert my_rest.json()["is_approved"] is False
    assert my_rest.json()["is_active"] is False

    # 3. Owner adds a food item before approval
    food_resp = client.post(
        "/owner/foods",
        json={
            "name": "Chicken Dum Biryani",
            "description": "Spiced basmati rice with tender chicken",
            "price_paise": 28000,
            "is_veg": False,
            "is_available": True
        },
        headers=owner_headers
    )
    assert food_resp.status_code == 200
    food_id = food_resp.json()["id"]

    owner_foods = client.get("/owner/foods", headers=owner_headers)
    assert owner_foods.status_code == 200
    assert len(owner_foods.json()) == 1

    # 4. Strict customer visibility check: Unapproved restaurant must NOT be visible
    cust_rests = client.get("/restaurants")
    assert cust_rests.status_code == 200
    assert not any(r["id"] == rest_id for r in cust_rests.json())

    cust_detail = client.get(f"/restaurants/{rest_id}")
    assert cust_detail.status_code == 404

    cust_foods = client.get(f"/restaurants/{rest_id}/foods")
    assert cust_foods.status_code == 404

    # 5. Admin reviews application and tests Rejection
    admin_login = client.post("/auth/login", json={"username": "admin_m2@foodflow.com", "password": "adminpass"})
    admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}

    reject_resp = client.put(f"/admin/restaurants/{rest_id}/reject", headers=admin_headers)
    assert reject_resp.status_code == 200
    assert reject_resp.json()["is_approved"] is False
    assert reject_resp.json()["is_active"] is False

    # Still hidden from customers
    assert client.get(f"/restaurants/{rest_id}").status_code == 404

    # 6. Admin approves restaurant
    approve_resp = client.put(f"/admin/restaurants/{rest_id}/approve", headers=admin_headers)
    assert approve_resp.status_code == 200
    assert approve_resp.json()["is_approved"] is True
    assert approve_resp.json()["is_active"] is True

    # 7. Customer visibility check: Now visible and orderable!
    cust_rests_approved = client.get("/restaurants")
    assert cust_rests_approved.status_code == 200
    assert any(r["id"] == rest_id for r in cust_rests_approved.json())

    cust_detail_approved = client.get(f"/restaurants/{rest_id}")
    assert cust_detail_approved.status_code == 200
    assert cust_detail_approved.json()["name"] == "Applicant Biryani Point"

    cust_foods_approved = client.get(f"/restaurants/{rest_id}/foods")
    assert cust_foods_approved.status_code == 200
    assert len(cust_foods_approved.json()) == 1
    assert cust_foods_approved.json()[0]["id"] == food_id

    # 8. Admin suspends the restaurant
    toggle_resp = client.put(f"/admin/restaurants/{rest_id}/toggle-active", headers=admin_headers)
    assert toggle_resp.status_code == 200
    assert toggle_resp.json()["is_active"] is False

    # Suspended restaurant is hidden from customer searches again
    assert not any(r["id"] == rest_id for r in client.get("/restaurants").json())
    assert client.get(f"/restaurants/{rest_id}").status_code == 404

    db.close()


def test_owner_authorization_isolation():
    db = TestingSessionLocal()
    owner1 = User(
        email="owner1@foodflow.com",
        hashed_password=get_password_hash("pass1"),
        full_name="Owner One",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    owner2 = User(
        email="owner2@foodflow.com",
        hashed_password=get_password_hash("pass2"),
        full_name="Owner Two",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    rest1 = Restaurant(
        owner_id=None,
        name="Rest One",
        cuisine="Indian",
        is_approved=True,
        is_active=True
    )
    rest2 = Restaurant(
        owner_id=None,
        name="Rest Two",
        cuisine="Mexican",
        is_approved=True,
        is_active=True
    )
    db.add_all([owner1, owner2, rest1, rest2])
    db.commit()
    db.refresh(owner1)
    db.refresh(owner2)
    db.refresh(rest1)
    db.refresh(rest2)

    rest1.owner_id = owner1.id
    rest2.owner_id = owner2.id
    food1 = FoodItem(restaurant_id=rest1.id, name="Biryani 1", price_paise=20000, is_veg=False, is_available=True)
    db.add(food1)
    db.commit()
    db.refresh(food1)

    # Owner 2 logs in
    o2_login = client.post("/auth/login", json={"username": "owner2@foodflow.com", "password": "pass2"})
    o2_headers = {"Authorization": f"Bearer {o2_login.json()['access_token']}"}

    # Owner 2 tries to toggle food availability of Owner 1's dish
    toggle_attack = client.put(f"/owner/foods/{food1.id}/toggle-availability", headers=o2_headers)
    assert toggle_attack.status_code == 404

    # Owner 2 updates their own restaurant
    my_update = client.put(
        "/owner/restaurant",
        json={
            "name": "Rest Two Updated",
            "cuisine": "Mexican Tacos",
            "delivery_fee_paise": 2500,
            "min_order_paise": 8000
        },
        headers=o2_headers
    )
    assert my_update.status_code == 200
    assert my_update.json()["name"] == "Rest Two Updated"

    # Rest 1 was not affected
    db.refresh(rest1)
    assert rest1.name == "Rest One"

    db.close()


def test_end_to_end_cross_role_order_lifecycle():
    db = TestingSessionLocal()
    # 1. Admin Setup
    admin = User(
        email="super_admin_e2e@foodflow.com",
        hashed_password=get_password_hash("adminpass123"),
        full_name="Super Admin E2E",
        role=UserRole.ADMIN,
        is_active=True,
        is_approved=True
    )
    # 2. Owner Setup with Active Restaurant
    owner = User(
        email="e2e_chef@foodflow.com",
        hashed_password=get_password_hash("chefpass123"),
        full_name="Chef Ramesh",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    rest = Restaurant(
        name="Grand Spice Palace",
        cuisine="North Indian",
        delivery_fee_paise=3500,
        min_order_paise=15000,
        is_approved=True,
        is_active=True,
        is_open=True
    )
    # 3. Customer Setup
    customer = User(
        email="e2e_diner@foodflow.com",
        hashed_password=get_password_hash("dinerpass123"),
        full_name="Priya Diner",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    # 4. Delivery Partner Setup
    driver_user = User(
        email="e2e_rider@foodflow.com",
        hashed_password=get_password_hash("riderpass123"),
        full_name="Ravi Rider",
        role=UserRole.DELIVERY_PARTNER,
        is_active=True,
        is_approved=True
    )
    db.add_all([admin, owner, rest, customer, driver_user])
    db.commit()
    db.refresh(owner)
    db.refresh(rest)
    db.refresh(driver_user)
    
    rest.owner_id = owner.id
    driver_profile = DeliveryPartner(
        user_id=driver_user.id,
        vehicle_type="Motorcycle",
        vehicle_number="KA-05-AB-9999",
        is_online=True,
        is_verified=True
    )
    db.add(driver_profile)
    db.commit()

    # Log in all four roles
    adm_token = client.post("/auth/login", data={"username": "super_admin_e2e@foodflow.com", "password": "adminpass123"}).json()["access_token"]
    adm_headers = {"Authorization": f"Bearer {adm_token}"}

    own_token = client.post("/auth/login", data={"username": "e2e_chef@foodflow.com", "password": "chefpass123"}).json()["access_token"]
    own_headers = {"Authorization": f"Bearer {own_token}"}

    cst_token = client.post("/auth/login", data={"username": "e2e_diner@foodflow.com", "password": "dinerpass123"}).json()["access_token"]
    cst_headers = {"Authorization": f"Bearer {cst_token}"}

    drw_token = client.post("/auth/login", data={"username": "e2e_rider@foodflow.com", "password": "riderpass123"}).json()["access_token"]
    drw_headers = {"Authorization": f"Bearer {drw_token}"}

    # Step 1: Owner adds food item
    food_resp = client.post(
        "/owner/foods",
        json={
            "name": "Kadhai Paneer Special",
            "description": "Rich cottage cheese in spicy kadhai gravy",
            "price_paise": 28000,
            "is_veg": True,
            "is_available": True
        },
        headers=own_headers
    )
    assert food_resp.status_code == 200
    food_id = food_resp.json()["id"]

    # Step 2: Customer adds to cart & checks out
    client.post("/cart/items", json={"food_item_id": food_id, "quantity": 2}, headers=cst_headers)
    order_resp = client.post(
        "/orders",
        json={"delivery_address": "Apartment 5B, Lotus Park", "payment_method": "COD"},
        headers=cst_headers
    )
    assert order_resp.status_code == 200
    order_id = order_resp.json()["id"]
    assert order_resp.json()["status"] == "PLACED" or order_resp.json()["status"] == "CONFIRMED"

    # Step 3: Owner transitions order to RESTAURANT_CONFIRMED -> PREPARING -> READY_FOR_PICKUP
    client.put(f"/owner/orders/{order_id}/status", json={"status": "RESTAURANT_CONFIRMED"}, headers=own_headers)
    client.put(f"/owner/orders/{order_id}/status", json={"status": "PREPARING"}, headers=own_headers)
    ready_resp = client.put(f"/owner/orders/{order_id}/status", json={"status": "READY_FOR_PICKUP"}, headers=own_headers)
    assert ready_resp.status_code == 200

    # Step 4: Driver gets available orders & assigns
    avail = client.get("/delivery/available-orders", headers=drw_headers)
    assert avail.status_code == 200
    assignments = avail.json()
    assert len(assignments) >= 1
    assignment_id = assignments[0]["id"]

    # Step 5: Driver updates status to ARRIVED_AT_RESTAURANT -> PICKED_UP -> OUT_FOR_DELIVERY -> DELIVERED
    client.put(f"/delivery/assignments/{assignment_id}/status", json={"status": "ARRIVED_AT_RESTAURANT"}, headers=drw_headers)
    client.put(f"/delivery/assignments/{assignment_id}/status", json={"status": "PICKED_UP"}, headers=drw_headers)
    client.put(f"/delivery/assignments/{assignment_id}/status", json={"status": "OUT_FOR_DELIVERY"}, headers=drw_headers)
    
    # Broadcast live location
    client.put(f"/tracking/{order_id}/location", json={"rider_lat": 12.9352, "rider_lng": 77.6245, "rider_heading": 90.0}, headers=drw_headers)
    
    deliv_resp = client.put(f"/delivery/assignments/{assignment_id}/status", json={"status": "DELIVERED"}, headers=drw_headers)
    assert deliv_resp.status_code == 200

    # Step 6: Customer confirms order status DELIVERED & writes review
    cust_order = client.get(f"/orders/{order_id}", headers=cst_headers).json()
    assert cust_order["status"] == "DELIVERED"

    review_resp = client.post(
        "/reviews",
        json={"order_id": order_id, "restaurant_id": rest.id, "rating": 5.0, "comment": "Delicious food and prompt delivery!"},
        headers=cst_headers
    )
    assert review_resp.status_code == 200

    # Step 7: Admin inspects Executive Analytics
    analytics = client.get("/admin/analytics", headers=adm_headers)
    assert analytics.status_code == 200
    assert analytics.json()["total_orders"] >= 1

    db.close()


def test_admin_user_deletion_safeguards_and_soft_delete():
    db = TestingSessionLocal()

    admin = User(
        email="super_admin_del_test@foodflow.com",
        hashed_password=get_password_hash("admin123"),
        full_name="Super Admin Deletion Test",
        role=UserRole.ADMIN,
        is_active=True,
        is_approved=True
    )
    clean_user = User(
        email="clean_user@foodflow.com",
        hashed_password=get_password_hash("pass123"),
        full_name="Clean Customer",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    user_with_order = User(
        email="user_with_order@foodflow.com",
        hashed_password=get_password_hash("pass123"),
        full_name="Ordered Customer",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    db.add_all([admin, clean_user, user_with_order])
    db.commit()
    db.refresh(admin)
    db.refresh(clean_user)
    db.refresh(user_with_order)

    # Attach an order to user_with_order
    rest = Restaurant(
        name="Del Test Diner",
        cuisine="Fast Food",
        address_text="123 Street",
        is_active=True,
        is_approved=True
    )
    db.add(rest)
    db.commit()
    db.refresh(rest)

    order = Order(
        user_id=user_with_order.id,
        restaurant_id=rest.id,
        status="PLACED",
        subtotal_paise=20000,
        delivery_fee_paise=3000,
        tax_paise=1000,
        discount_paise=0,
        total_paise=24000,
        delivery_address="123 Street"
    )
    db.add(order)
    db.commit()

    admin_token = create_access_token(data={"sub": admin.email, "role": "ADMIN"})
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    cst_token = create_access_token(data={"sub": clean_user.email, "role": "CUSTOMER"})
    cst_headers = {"Authorization": f"Bearer {cst_token}"}

    # 1. Non-admin cannot delete
    unauth_resp = client.delete(f"/admin/users/{clean_user.id}", headers=cst_headers)
    assert unauth_resp.status_code == 403

    # 2. Admin cannot delete themselves
    self_del_resp = client.delete(f"/admin/users/{admin.id}", headers=admin_headers)
    assert self_del_resp.status_code == 400
    assert "cannot delete your own" in self_del_resp.json()["detail"].lower()

    # 3. Clean user is permanently deleted
    clean_del_resp = client.delete(f"/admin/users/{clean_user.id}", headers=admin_headers)
    assert clean_del_resp.status_code == 200
    assert clean_del_resp.json()["soft_deleted"] is False
    assert db.query(User).filter(User.id == clean_user.id).first() is None

    # 4. User with dependent business records (orders) is safely soft-deleted/archived
    order_user_del_resp = client.delete(f"/admin/users/{user_with_order.id}", headers=admin_headers)
    assert order_user_del_resp.status_code == 200
    assert order_user_del_resp.json()["soft_deleted"] is True
    
    # Verify user record is archived & deactivated, but preserved for order relation
    db.expire_all()
    archived_user = db.query(User).filter(User.id == user_with_order.id).first()
    assert archived_user is not None
    assert archived_user.is_active is False
    assert archived_user.is_approved is False
    assert "deleted_" in archived_user.email

    # Order history remains intact
    persisted_order = db.query(Order).filter(Order.id == order.id).first()
    assert persisted_order is not None
    assert persisted_order.user_id == user_with_order.id

    db.close()


def test_rider_self_registration_flow_and_security():
    db = TestingSessionLocal()
    # 1. Register a new delivery rider
    rider_data = {
        "email": "new_fleet_rider@test.com",
        "password": "secure_password_123",
        "full_name": "Rider Flash",
        "phone": "9876500001",
        "vehicle_type": "SCOOTER",
        "vehicle_number": "KA-01-AB-9999"
    }
    reg_resp = client.post("/auth/register-rider", json=rider_data)
    assert reg_resp.status_code == 200
    reg_json = reg_resp.json()
    assert "access_token" in reg_json
    assert reg_json["user"]["email"] == "new_fleet_rider@test.com"
    assert reg_json["user"]["role"] == "DELIVERY_PARTNER"
    assert reg_json["user"]["is_approved"] is False # Pending admin approval

    rider_id = reg_json["user"]["id"]

    # Verify database model details
    rider_user = db.query(User).filter(User.id == rider_id).first()
    assert rider_user is not None
    assert rider_user.role == UserRole.DELIVERY_PARTNER
    assert rider_user.is_approved is False
    assert rider_user.hashed_password != "secure_password_123"
    
    partner_profile = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == rider_id).first()
    assert partner_profile is not None
    assert partner_profile.vehicle_type == "SCOOTER"
    assert partner_profile.vehicle_number == "KA-01-AB-9999"
    assert partner_profile.is_verified is False
    assert partner_profile.is_online is False

    # 2. Duplicate email rejection
    dup_resp = client.post("/auth/register-rider", json=rider_data)
    assert dup_resp.status_code == 400
    assert "already registered" in dup_resp.json()["detail"].lower()

    # 3. Short password validation
    short_pass_data = dict(rider_data)
    short_pass_data["email"] = "short_pass_rider@test.com"
    short_pass_data["password"] = "123"
    short_resp = client.post("/auth/register-rider", json=short_pass_data)
    assert short_resp.status_code == 400
    assert "6 characters" in short_resp.json()["detail"].lower()

    # 4. Unapproved rider cannot toggle online or receive orders
    rider_token = reg_json["access_token"]
    rider_headers = {"Authorization": f"Bearer {rider_token}"}

    toggle_resp = client.put("/delivery/toggle-online", headers=rider_headers)
    assert toggle_resp.status_code == 403
    assert "pending administrator approval" in toggle_resp.json()["detail"].lower()

    orders_resp = client.get("/delivery/available-orders", headers=rider_headers)
    assert orders_resp.status_code == 200
    assert orders_resp.json() == []

    # 5. Create an Admin user for approval workflow
    admin = User(
        email="super_fleet_admin@test.com",
        hashed_password=get_password_hash("adminpass123"),
        full_name="Fleet Admin",
        role=UserRole.ADMIN,
        is_active=True,
        is_approved=True
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)

    admin_token = create_access_token(data={"sub": admin.email, "role": "ADMIN"})
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # Non-admin cannot approve rider
    cust = User(
        email="any_customer@test.com",
        hashed_password=get_password_hash("custpass123"),
        full_name="Any Customer",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    db.add(cust)
    db.commit()
    cust_token = create_access_token(data={"sub": cust.email, "role": "CUSTOMER"})
    unauth_approve = client.put(f"/admin/users/{rider_id}/approve", headers={"Authorization": f"Bearer {cust_token}"})
    assert unauth_approve.status_code == 403

    # Admin approves rider
    approve_resp = client.put(f"/admin/users/{rider_id}/approve", headers=admin_headers)
    assert approve_resp.status_code == 200
    assert approve_resp.json()["is_approved"] is True

    # Check DB state
    db.expire_all()
    updated_rider = db.query(User).filter(User.id == rider_id).first()
    assert updated_rider.is_approved is True
    updated_partner = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == rider_id).first()
    assert updated_partner.is_verified is True

    # 6. Approved rider can now go online
    approved_toggle = client.put("/delivery/toggle-online", headers=rider_headers)
    assert approved_toggle.status_code == 200
    assert approved_toggle.json()["is_online"] is True

    # 7. Admin rejects/deactivates rider
    reject_resp = client.put(f"/admin/users/{rider_id}/reject", headers=admin_headers)
    assert reject_resp.status_code == 200
    assert reject_resp.json()["is_approved"] is False
    assert reject_resp.json()["is_active"] is False

    db.expire_all()
    rejected_partner = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == rider_id).first()
    assert rejected_partner.is_verified is False
    assert rejected_partner.is_online is False

    db.close()


