from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel
from ..database import get_db
from ..models import User, UserRole, Restaurant, DeliveryPartner
from ..schemas import UserCreate, UserResponse, Token, OwnerRegistrationRequest, RiderRegistrationRequest
from ..auth import get_password_hash, verify_password, create_access_token, get_current_user
from .notifications import create_system_notification

router = APIRouter(prefix="/auth", tags=["Authentication"])

class LoginRequestJSON(BaseModel):
    username: str
    password: str

@router.post("/register", response_model=Token)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user_in.email.strip().lower()).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pwd = get_password_hash(user_in.password)
    # Strictly enforce CUSTOMER role for public customer registration
    new_user = User(
        email=user_in.email.strip().lower(),
        hashed_password=hashed_pwd,
        full_name=user_in.full_name.strip(),
        phone=user_in.phone.strip() if user_in.phone else None,
        role=UserRole.CUSTOMER,
        is_active=True,
        is_approved=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    access_token = create_access_token(data={"sub": new_user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": new_user}

@router.post("/register-owner", response_model=Token)
def register_owner_with_restaurant(
    owner_in: OwnerRegistrationRequest,
    db: Session = Depends(get_db)
):
    clean_email = owner_in.email.strip().lower()
    existing_user = db.query(User).filter(User.email == clean_email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pwd = get_password_hash(owner_in.password)
    # Create owner user account
    owner_user = User(
        email=clean_email,
        hashed_password=hashed_pwd,
        full_name=owner_in.full_name.strip(),
        phone=owner_in.phone.strip() if owner_in.phone else None,
        role=UserRole.RESTAURANT_OWNER,
        is_active=True,
        is_approved=True
    )
    db.add(owner_user)
    db.commit()
    db.refresh(owner_user)

    # Create restaurant in PENDING_APPROVAL / INACTIVE state
    restaurant = Restaurant(
        owner_id=owner_user.id,
        name=owner_in.restaurant_name.strip(),
        cuisine=owner_in.cuisine.strip(),
        description=owner_in.description.strip() if owner_in.description else None,
        address_text=owner_in.address_text.strip() if owner_in.address_text else "Pending Address Verification",
        image_url=owner_in.image_url,
        delivery_fee_paise=owner_in.delivery_fee_paise,
        min_order_paise=owner_in.min_order_paise,
        estimated_delivery_time=owner_in.estimated_delivery_time,
        is_active=False,
        is_approved=False,
        is_open=True,
        prep_time_minutes=25
    )
    db.add(restaurant)
    db.commit()
    db.refresh(restaurant)

    # Notify super admin accounts of new restaurant application
    admin_users = db.query(User).filter(User.role == UserRole.ADMIN).all()
    for admin in admin_users:
        create_system_notification(
            db=db,
            user_id=admin.id,
            title="New Restaurant Application 🛎️",
            message=f"'{restaurant.name}' has been registered by {owner_user.email} and is awaiting your review.",
            notif_type="SYSTEM"
        )

    # Send confirmation notification to the owner
    create_system_notification(
        db=db,
        user_id=owner_user.id,
        title="Application Received ⏳",
        message=f"Thank you for registering '{restaurant.name}'. Your application is currently under review by Super Admin.",
        notif_type="SYSTEM"
    )

    access_token = create_access_token(data={"sub": owner_user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": owner_user}

@router.post("/register-rider", response_model=Token)
def register_rider(
    rider_in: RiderRegistrationRequest,
    db: Session = Depends(get_db)
):
    clean_email = rider_in.email.strip().lower()
    existing_user = db.query(User).filter(User.email == clean_email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    if len(rider_in.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    clean_vehicle = rider_in.vehicle_number.strip().upper()
    if not clean_vehicle:
        raise HTTPException(status_code=400, detail="Vehicle number is required")

    hashed_pwd = get_password_hash(rider_in.password)
    # Create rider account with server-assigned DELIVERY_PARTNER role and pending approval
    rider_user = User(
        email=clean_email,
        hashed_password=hashed_pwd,
        full_name=rider_in.full_name.strip(),
        phone=rider_in.phone.strip() if rider_in.phone else None,
        role=UserRole.DELIVERY_PARTNER,
        is_active=True,
        is_approved=False
    )
    db.add(rider_user)
    db.commit()
    db.refresh(rider_user)

    # Create DeliveryPartner profile linked to user
    dp = DeliveryPartner(
        user_id=rider_user.id,
        vehicle_type=rider_in.vehicle_type or "SCOOTER",
        vehicle_number=clean_vehicle,
        is_online=False,
        is_verified=False
    )
    db.add(dp)
    db.commit()
    db.refresh(dp)

    # Notify super admins of new rider application
    admin_users = db.query(User).filter(User.role == UserRole.ADMIN).all()
    for admin in admin_users:
        create_system_notification(
            db=db,
            user_id=admin.id,
            title="New Delivery Rider Application 🛵",
            message=f"'{rider_user.full_name}' ({clean_email}) has registered with vehicle {clean_vehicle} and is awaiting your review.",
            notif_type="SYSTEM"
        )

    # Confirmation notification to rider
    create_system_notification(
        db=db,
        user_id=rider_user.id,
        title="Rider Application Received ⏳",
        message="Thank you for applying to join FoodFlow delivery fleet. Your profile is currently under review by Super Admin.",
        notif_type="SYSTEM"
    )

    access_token = create_access_token(data={"sub": rider_user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": rider_user}

@router.post("/login", response_model=Token)
async def login(
    request: Request,
    db: Session = Depends(get_db)
):
    username = None
    password = None

    content_type = request.headers.get("content-type", "").lower()

    if "application/json" in content_type:
        try:
            json_body = await request.json()
            username = json_body.get("username") or json_body.get("email")
            password = json_body.get("password")
        except Exception:
            pass
    else:
        try:
            form_data = await request.form()
            username = form_data.get("username") or form_data.get("email")
            password = form_data.get("password")
        except Exception:
            pass

    if not username or not password:
        raise HTTPException(status_code=400, detail="Username and password are required")

    username_input = username.strip()
    user = db.query(User).filter(
        (User.email == username_input) |
        (User.email == f"{username_input}@foodflow.com")
    ).first()

    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": user}

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
