# FoodFlow — Production Architecture, Deployment & Local Development Guide

## 1. Product Architecture Overview

FoodFlow is a commercial multi-role food delivery platform engineered with a single shared FastAPI backend and Neon PostgreSQL database supporting two production client targets:
1. **Responsive Web Application (Hosted on Vercel):** Desktop, tablet, and browser customer experience, Admin dashboard, Restaurant Owner portal, and fleet monitoring.
2. **Native Android Application (Installable APK):** Customer ordering and Delivery Partner logistics interface with live GPS updates.

```
                   +-----------------------------------------------+
                   |             Production Clients                |
                   |                                               |
                   |  [Vercel Web: Desktop/Tablet/Admin/Owner]     |
                   |  [Android APK: Customer/Delivery Partner]     |
                   +-----------------------+-----------------------+
                                           | HTTPS / JSON
                                           v
                   +-----------------------------------------------+
                   |        FastAPI Commercial Backend             |
                   |               (on Render)                     |
                   |    - JWT Authentication & RBAC                |
                   |    - Real-Time Orders & Dynamic Coupons       |
                   |    - GPS Tracking & Notifications             |
                   |    - Photo Uploads (Cloudinary / Static)      |
                   +-----------------------+-----------------------+
                                           | SSL
                                           v
                   +-----------------------------------------------+
                   |        Neon Managed PostgreSQL                |
                   |    - Strict FKs & Relational Integrity        |
                   |    - Autoscaling Serverless Compute           |
                   |    - Isolated Role Permissions                |
                   +-----------------------------------------------+
```

---

## 2. Web Application Deployment (Vercel)

The Flutter Web application compiles into optimized static WebAssembly / HTML5 / CanvasKit assets in `build/web`.

### 2.1 Vercel Configuration (`vercel.json`)
The repository includes a production-ready `vercel.json` configured for Single Page Application (SPA) routing:
```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "flutter build web --release",
  "outputDirectory": "build/web",
  "framework": null,
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "SAMEORIGIN" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    },
    {
      "source": "/(assets|icons|canvaskit)/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ]
}
```

### 2.2 Deploying to Vercel
1. **Install Vercel CLI (or connect GitHub repository in Vercel Dashboard):**
   ```bash
   npm i -g vercel
   ```
2. **Build Web Release Locally (or rely on Vercel Build Pipeline):**
   ```bash
   flutter build web --release
   ```
3. **Deploy from Project Root:**
   ```bash
   # Preview Deployment
   vercel

   # Production Deployment
   vercel --prod
   ```
4. **Environment Variables (Optional overrides):**
   If deploying to a custom domain or staging API, set the build-time environment variable:
   - `API_URL`: `https://foodflow-api-lcxo.onrender.com`

---

## 3. Native Android Application (APK)

The Android application is configured in `android/` with package namespace `com.foodflow.foodflow` and target SDK 36.

### 3.1 Mobile Role Experience
- **Unified Sign-in Form:** A clean, single login form without role tabs.
- **Authoritative Routing:** Authenticated Customers are routed to the Home Screen (`/`), while Delivery Partners are routed directly to the Delivery Dashboard (`/delivery-dashboard`).
- **Platform Role Isolation:** Admin and Restaurant Owner accounts are denied access to mobile consumer ordering, directing them to the desktop web portal.

### 3.2 Building Android APKs
- **Debug APK (For Local Device Testing):**
  ```bash
  flutter build apk --debug
  # Output: build/app/outputs/flutter-apk/app-debug.apk
  ```
- **Release APK (Standalone Production Build):**
  ```bash
  flutter build apk --release
  # Output: build/app/outputs/flutter-apk/app-release.apk
  ```
- **Install Directly onto Connected Android Device:**
  ```bash
  flutter install
  ```

---

## 4. FastAPI Backend & Database (Render + Neon)

### 4.1 Render Service Overview
- **Service Name:** `foodflow-api`
- **Public URL:** `https://foodflow-api-lcxo.onrender.com`
- **Runtime:** Python 3.11 with `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- **CORS Allowed Origins:** Localhost (`localhost:8080`, `127.0.0.1`), Render domain, and all `*.vercel.app` production and preview domains via regex matching.

### 4.2 Production Environment Variables (Configured on Render)
- `DATABASE_URL`: `postgresql://foodflow_owner:***@ep-***-pooler.ap-southeast-1.aws.neon.tech/foodflow?sslmode=require`
- `JWT_SECRET_KEY`: High-entropy generated HMAC key
- `CLOUDINARY_URL`: Cloudinary storage configuration for persistent image hosting

---

## 5. Local Development Workflow (Zero Deployment Needed)

Developers can iterate, test, and debug both frontend and backend locally without deploying changes.

### 5.1 Running Flutter Web Locally (Chrome)
1. Launch local dev server in Chrome:
   ```bash
   flutter run -d chrome
   ```
2. By default, the app uses the live Render cloud API. To point to a local backend, pass:
   ```bash
   flutter run -d chrome --dart-define=USE_CLOUD=false
   ```

### 5.2 Running FastAPI Backend Locally
1. Activate Python virtual environment and navigate to `backend/`:
   ```bash
   cd backend
   uvicorn app.main:app --reload --port 8000
   ```
2. Local API Docs are available at: `http://localhost:8000/docs`

### 5.3 Running the Full Verification Suite Locally
Run before opening a pull request or building releases:
```bash
# 1. Flutter static analysis (0 errors required)
flutter analyze

# 2. Flutter unit & widget tests
flutter test

# 3. Backend pytest suite (16/16 tests)
python -m pytest backend/tests -v

# 4. Web Release build check
flutter build web --release
```

---

## 6. Deployment Safety & User Action Items

### Safe Release Rules
1. **Never commit secrets:** Passwords, database URLs, and JWT secret keys are never placed in frontend code or git.
2. **Never seed or reset production database:** All schema modifications must preserve production data integrity.
3. **Decoupled deployments:** Frontend changes are deployed to Vercel without requiring backend redeployment, unless backend API contracts change.

### Required User Actions (Before Going Live)
1. **Link Vercel Project:** Run `vercel` in the project root to link to your Vercel organization/account.
2. **Configure Custom Domains (Optional):** Add custom domains (e.g. `app.foodflow.com`) in Vercel project settings.
3. **Android Release Keystore (Optional for Play Store distribution):** When preparing for Google Play distribution, generate an upload keystore and configure `android/key.properties`.
