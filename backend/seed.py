import sys
import os
from datetime import datetime, timedelta

# Check root .env.local for Neon database credentials
env_local_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".env.local"))
if os.path.exists(env_local_path):
    env_vars = {}
    with open(env_local_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                env_vars[key] = val
    target_url = env_vars.get("DATABASE_URL_UNPOOLED") or env_vars.get("DATABASE_URL")
    if target_url:
        os.environ["DATABASE_URL"] = target_url

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import Base, engine, SessionLocal
from app.models import (
    User, UserRole, UserAddress, Restaurant, FoodCategory, FoodItem,
    DeliveryPartner, Coupon, Notification
)
from app.auth import get_password_hash

def seed_db():
    print("Connecting to database and creating schema if not exists...", flush=True)
    # Safely create tables if they do not already exist (non-destructive)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    print("Seeding/Updating FoodFlow database with idempotent records...", flush=True)

    # Helper function to create or update user
    def upsert_user(email, password, full_name, phone, role):
        u = db.query(User).filter(User.email == email).first()
        if not u:
            u = User(
                email=email,
                hashed_password=get_password_hash(password),
                full_name=full_name,
                phone=phone,
                role=role,
                is_active=True,
                is_approved=True
            )
            db.add(u)
        else:
            u.hashed_password = get_password_hash(password)
            u.full_name = full_name
            u.role = role
            u.is_active = True
            u.is_approved = True
        db.commit()
        db.refresh(u)
        return u

    # 1. Users for all 4 Roles
    customer = upsert_user("customer@foodflow.com", "password123", "Alex Johnson (Customer)", "+1234567890", UserRole.CUSTOMER)
    owner = upsert_user("owner@foodflow.com", "password123", "Chef Marco (Restaurant Owner)", "+1987654321", UserRole.RESTAURANT_OWNER)
    delivery_user = upsert_user("delivery@foodflow.com", "password123", "Sam Rider (Delivery Partner)", "+1122334455", UserRole.DELIVERY_PARTNER)
    super_admin = upsert_user("shahinsha@foodflow.com", "262007", "Shahinsha (Super Admin)", "+1000000000", UserRole.ADMIN)

    # 2. Customer Saved Addresses
    existing_addr = db.query(UserAddress).filter(UserAddress.user_id == customer.id, UserAddress.label == "HOME").first()
    if not existing_addr:
        addr1 = UserAddress(
            user_id=customer.id,
            label="HOME",
            street_address="123 Tech Park, Suite 400",
            building_floor="Floor 4, Apt 402",
            landmark="Near Central Park",
            city="Innovation City",
            pincode="100001",
            latitude=12.9716,
            longitude=77.5946,
            is_default=True
        )
        addr2 = UserAddress(
            user_id=customer.id,
            label="WORK",
            street_address="789 Cyber Tower, Floor 8",
            city="Innovation City",
            pincode="100002",
            latitude=12.9800,
            longitude=77.6000,
            is_default=False
        )
        db.add_all([addr1, addr2])
        db.commit()

    # 3. Delivery Partner Profile
    dp_profile = db.query(DeliveryPartner).filter(DeliveryPartner.user_id == delivery_user.id).first()
    if not dp_profile:
        dp_profile = DeliveryPartner(
            user_id=delivery_user.id,
            vehicle_type="SCOOTER",
            vehicle_number="KA-01-EV-9999",
            is_online=True,
            is_verified=True,
            current_lat=12.9450,
            current_lng=77.6150,
            total_earnings_paise=15000
        )
        db.add(dp_profile)
        db.commit()

    # Helper function to upsert restaurant
    def upsert_restaurant(name, description, cuisine, image_url, rating, delivery_fee_paise, min_order_paise, est_time, lat, lng, address_text, prep_time, owner_id=None):
        r = db.query(Restaurant).filter(Restaurant.name == name).first()
        if not r:
            r = Restaurant(
                name=name,
                description=description,
                cuisine=cuisine,
                image_url=image_url,
                rating=rating,
                delivery_fee_paise=delivery_fee_paise,
                min_order_paise=min_order_paise,
                estimated_delivery_time=est_time,
                latitude=lat,
                longitude=lng,
                address_text=address_text,
                is_open=True,
                prep_time_minutes=prep_time,
                is_active=True,
                is_approved=True,
                owner_id=owner_id
            )
            db.add(r)
            db.commit()
            db.refresh(r)
        else:
            if owner_id and not r.owner_id:
                r.owner_id = owner_id
                db.commit()
                db.refresh(r)
        return r

    # 4. Restaurants
    rest1 = upsert_restaurant(
        name="Urban Spice Grill",
        description="Authentic North Indian & Tandoori specialties crafted by Master Chefs",
        cuisine="North Indian, Tandoor",
        image_url="https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80",
        rating=4.8,
        delivery_fee_paise=2500,
        min_order_paise=15000,
        est_time="25-35 min",
        lat=12.9352,
        lng=77.6245,
        address_text="Block 4, Koramangala Food Street",
        prep_time=25,
        owner_id=owner.id
    )

    rest2 = upsert_restaurant(
        name="Bella Italia Bistro",
        description="Handcrafted Neapolitan pizzas, artisanal pasta and Italian desserts",
        cuisine="Italian, Pizza, Pasta",
        image_url="https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80",
        rating=4.6,
        delivery_fee_paise=3500,
        min_order_paise=20000,
        est_time="30-45 min",
        lat=12.9500,
        lng=77.6300,
        address_text="Indiranagar 100ft Road",
        prep_time=30
    )

    rest3 = upsert_restaurant(
        name="Sakura Sushi & Ramen",
        description="Fresh sushi rolls, piping hot tonkotsu ramen bowls & bento boxes",
        cuisine="Japanese, Asian",
        image_url="https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&q=80",
        rating=4.9,
        delivery_fee_paise=4000,
        min_order_paise=25000,
        est_time="35-50 min",
        lat=12.9600,
        lng=77.6400,
        address_text="MG Road Boulevard",
        prep_time=35
    )

    # Helper function for categories and food items
    def upsert_category(cat_name, restaurant_id):
        cat = db.query(FoodCategory).filter(FoodCategory.name == cat_name, FoodCategory.restaurant_id == restaurant_id).first()
        if not cat:
            cat = FoodCategory(name=cat_name, restaurant_id=restaurant_id)
            db.add(cat)
            db.commit()
            db.refresh(cat)
        return cat

    def upsert_food_item(restaurant_id, category_id, name, description, price_paise, is_veg, image_url):
        item = db.query(FoodItem).filter(FoodItem.name == name, FoodItem.restaurant_id == restaurant_id).first()
        if not item:
            item = FoodItem(
                restaurant_id=restaurant_id,
                category_id=category_id,
                name=name,
                description=description,
                price_paise=price_paise,
                is_veg=is_veg,
                is_available=True,
                image_url=image_url
            )
            db.add(item)
            db.commit()
            db.refresh(item)
        return item

    # 5. Food Categories & Food Items
    cat1_1 = upsert_category("Starters & Appetizers", rest1.id)
    cat1_2 = upsert_category("Main Course", rest1.id)
    cat1_3 = upsert_category("Breads & Rice", rest1.id)

    upsert_food_item(rest1.id, cat1_1.id, "Paneer Tikka Grill", "Cubes of cottage cheese marinated in spiced hung yogurt and clay oven grilled", 28000, True, "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=800&q=80")
    upsert_food_item(rest1.id, cat1_2.id, "Butter Chicken Deluxe", "Succulent chicken pieces in a slow-cooked buttery tomato cashew cream sauce", 34000, False, "https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?auto=format&fit=crop&w=800&q=80")
    upsert_food_item(rest1.id, cat1_3.id, "Garlic Butter Naan", "Freshly baked tandoor flatbread infused with crushed garlic and melted butter", 6000, True, "https://images.unsplash.com/photo-1626074353765-517a681e40be?auto=format&fit=crop&w=800&q=80")

    cat2_1 = upsert_category("Artisanal Pizzas", rest2.id)
    cat2_2 = upsert_category("Pastas & Sides", rest2.id)

    upsert_food_item(rest2.id, cat2_1.id, "Margherita Wood-Fired Pizza", "Fresh buffalo mozzarella, San Marzano tomato sauce, fresh basil & extra virgin olive oil", 39000, True, "https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?auto=format&fit=crop&w=800&q=80")
    upsert_food_item(rest2.id, cat2_2.id, "Creamy Truffle Fettuccine", "Handmade fettuccine pasta tossed in rich wild mushroom and truffle cream", 42000, True, "https://images.unsplash.com/photo-1621996346565-e3d5d6281691?auto=format&fit=crop&w=800&q=80")

    cat3_1 = upsert_category("Ramen & Bowls", rest3.id)
    cat3_2 = upsert_category("Sushi Rolls", rest3.id)

    upsert_food_item(rest3.id, cat3_1.id, "Signature Tonkotsu Ramen", "Rich pork bone broth, springy ramen noodles, chashu slices, soft-boiled egg and nori", 48000, False, "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=800&q=80")
    upsert_food_item(rest3.id, cat3_2.id, "Crispy Avocado Tempura Roll", "Crispy avocado, cucumber, toasted sesame seeds with spicy mayo glaze", 36000, True, "https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?auto=format&fit=crop&w=800&q=80")

    # Helper function for coupons
    def upsert_coupon(code, title, description, discount_type, discount_value, max_discount_paise, min_order_paise, usage_limit, per_user_limit, first_order_only=False, restaurant_id=None):
        c = db.query(Coupon).filter(Coupon.code == code).first()
        now = datetime.utcnow()
        if not c:
            c = Coupon(
                code=code,
                title=title,
                description=description,
                discount_type=discount_type,
                discount_value=discount_value,
                max_discount_paise=max_discount_paise,
                min_order_paise=min_order_paise,
                usage_limit=usage_limit,
                per_user_limit=per_user_limit,
                first_order_only=first_order_only,
                restaurant_id=restaurant_id,
                is_active=True,
                start_date=now - timedelta(days=1),
                end_date=now + timedelta(days=90)
            )
            db.add(c)
            db.commit()
            db.refresh(c)
        return c

    # 6. Commercial Promotions & Coupons
    upsert_coupon("WELCOME50", "50% OFF First Order", "Get 50% OFF up to ₹100 on your first food order", "PERCENTAGE", 50, 10000, 15000, 1000, 1, first_order_only=True)
    upsert_coupon("FLAT100", "Flat ₹100 Discount", "Save flat ₹100 on orders above ₹300 across all restaurants", "FLAT", 10000, 10000, 30000, 500, 2)
    upsert_coupon("FREEDEL", "Free Delivery Pass", "Zero delivery fees on orders above ₹200", "FREE_DELIVERY", 0, 5000, 20000, 2000, 5)
    upsert_coupon("URBAN30", "30% OFF Urban Spice", "Exclusive 30% discount on all gourmet dishes at Urban Spice Grill", "PERCENTAGE", 30, 15000, 25000, 300, 3, restaurant_id=rest1.id)

    # 7. Initial Welcome Notification for Customer
    existing_notif = db.query(Notification).filter(Notification.user_id == customer.id, Notification.title.like("Welcome to FoodFlow%")).first()
    if not existing_notif:
        welcome_notif = Notification(
            user_id=customer.id,
            title="Welcome to FoodFlow! 🎉",
            message="Use coupon code WELCOME50 to get 50% OFF up to ₹100 on your first order!",
            type="PROMO",
            is_read=False,
            created_at=datetime.utcnow()
        )
        db.add(welcome_notif)
        db.commit()

    db.close()
    print("Multi-Role FoodFlow database seeded successfully!")

if __name__ == "__main__":
    seed_db()
