import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from .database import Base, engine
from .routers import (
    auth, restaurants, cart, orders, users, owner, delivery,
    admin, reviews, tracking, uploads, coupons, notifications
)

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="FoodFlow Commercial Food Delivery Platform API",
    description="Commercial Multi-Role Food Delivery Platform with Promotion Engine, Live GPS, Real Notifications, and Analytics",
    version="3.0.0"
)

# Ensure uploads directory exists
os.makedirs("uploads/images", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# CORS Middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:8080",
        "http://localhost:3000",
        "http://127.0.0.1",
        "http://127.0.0.1:8080",
        "https://foodflow-api-lcxo.onrender.com",
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?|https://.*\.vercel\.app",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(restaurants.router)
app.include_router(cart.router)
app.include_router(orders.router)
app.include_router(users.router)
app.include_router(owner.router)
app.include_router(delivery.router)
app.include_router(admin.router)
app.include_router(reviews.router)
app.include_router(tracking.router)
app.include_router(uploads.router)
app.include_router(coupons.router)
app.include_router(notifications.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to FoodFlow Ecosystem API", "docs": "/docs"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
