import pytest
from tests.conftest import engine, TestingSessionLocal, client
from app.models import User, UserRole, Restaurant, UserAddress, Order, OrderStatus
from app.auth import get_password_hash, create_access_token

def test_restaurant_onboarding_requires_coordinates_and_address():
    db = TestingSessionLocal()
    owner = User(
        email="owner_loc_test@foodflow.com",
        hashed_password=get_password_hash("pass123"),
        full_name="Owner Loc",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    db.add(owner)
    db.commit()
    db.refresh(owner)
    token = create_access_token({"sub": owner.email})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Attempt onboarding without coordinates -> 400 Bad Request
    resp_no_coords = client.post(
        "/owner/restaurant",
        json={
            "name": "Map Test Bistro",
            "cuisine": "Continental",
            "delivery_fee_paise": 2500,
            "min_order_paise": 5000,
            "estimated_delivery_time": "20-30 min",
            "address_text": "123 Main St"
        },
        headers=headers
    )
    assert resp_no_coords.status_code == 400
    assert "coordinates" in resp_no_coords.json()["detail"].lower()

    # 2. Attempt onboarding with invalid coordinates -> 400
    resp_invalid_lat = client.post(
        "/owner/restaurant",
        json={
            "name": "Map Test Bistro",
            "cuisine": "Continental",
            "delivery_fee_paise": 2500,
            "min_order_paise": 5000,
            "estimated_delivery_time": "20-30 min",
            "latitude": 120.0,
            "longitude": 77.5946,
            "address_text": "123 Main St"
        },
        headers=headers
    )
    assert resp_invalid_lat.status_code == 400

    # 3. Successful onboarding with exact coordinates
    resp_success = client.post(
        "/owner/restaurant",
        json={
            "name": "Map Test Bistro",
            "cuisine": "Continental",
            "delivery_fee_paise": 2500,
            "min_order_paise": 5000,
            "estimated_delivery_time": "20-30 min",
            "latitude": 13.0827,
            "longitude": 80.2707,
            "address_text": "Anna Salai, Chennai"
        },
        headers=headers
    )
    assert resp_success.status_code == 200
    rest_data = resp_success.json()
    assert rest_data["latitude"] == 13.0827
    assert rest_data["longitude"] == 80.2707
    assert rest_data["address_text"] == "Anna Salai, Chennai"

def test_restaurant_settings_location_update():
    db = TestingSessionLocal()
    owner = User(
        email="owner_settings_test@foodflow.com",
        hashed_password=get_password_hash("pass123"),
        full_name="Owner Settings",
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    db.add(owner)
    db.commit()
    db.refresh(owner)
    token = create_access_token({"sub": owner.email})
    headers = {"Authorization": f"Bearer {token}"}

    # Onboard
    client.post(
        "/owner/restaurant",
        json={
            "name": "Settings Bistro",
            "cuisine": "Indian",
            "latitude": 19.0760,
            "longitude": 72.8777,
            "address_text": "Bandra West, Mumbai"
        },
        headers=headers
    )

    # Update location via /owner/restaurant/settings
    resp_update = client.put(
        "/owner/restaurant/settings",
        json={
            "latitude": 19.1136,
            "longitude": 72.8697,
            "address_text": "Andheri East, Mumbai",
            "prep_time_minutes": 35
        },
        headers=headers
    )
    assert resp_update.status_code == 200
    updated = resp_update.json()
    assert updated["latitude"] == 19.1136
    assert updated["longitude"] == 72.8697
    assert updated["address_text"] == "Andheri East, Mumbai"
    assert updated["prep_time_minutes"] == 35

def test_customer_address_creation_update_and_order_coordinates():
    db = TestingSessionLocal()
    cust = User(
        email="cust_map_test@foodflow.com",
        hashed_password=get_password_hash("pass123"),
        full_name="Cust Map",
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    db.add(cust)
    db.commit()
    db.refresh(cust)
    token = create_access_token({"sub": cust.email})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Add Address with exact coordinates
    resp_addr = client.post(
        "/users/addresses",
        json={
            "label": "HOME",
            "street_address": "Flat 302, Green Acres",
            "city": "Pune",
            "pincode": "411001",
            "latitude": 18.5204,
            "longitude": 73.8567
        },
        headers=headers
    )
    assert resp_addr.status_code == 200
    addr_data = resp_addr.json()
    addr_id = addr_data["id"]
    assert addr_data["latitude"] == 18.5204
    assert addr_data["longitude"] == 73.8567

    # 2. Update address coordinates
    resp_addr_up = client.put(
        f"/users/addresses/{addr_id}",
        json={
            "street_address": "Villa 12, Royal Palms",
            "latitude": 18.5300,
            "longitude": 73.8600
        },
        headers=headers
    )
    assert resp_addr_up.status_code == 200
    up_data = resp_addr_up.json()
    assert up_data["street_address"] == "Villa 12, Royal Palms"
    assert up_data["latitude"] == 18.5300
    assert up_data["longitude"] == 73.8600

    # 3. Test coordinate validation in order placement
    resp_invalid_order_coords = client.post(
        "/orders",
        json={
            "delivery_address": "Test",
            "delivery_lat": 95.0,  # Invalid
            "delivery_lng": 73.8600,
            "payment_method": "COD"
        },
        headers=headers
    )
    assert resp_invalid_order_coords.status_code == 400
