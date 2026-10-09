# FoodFlow Local Development & Android Device Setup

## 1. Running the FastAPI Backend
```bash
cd backend
python seed.py
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
API Documentation will be live at `http://localhost:8000/docs`.

---

## 2. Connecting Physical Android Device (`R5CY41WVF1H`)
To connect the physical Android phone over USB ADB:
```bash
adb -s R5CY41WVF1H reverse --remove-all
adb -s R5CY41WVF1H reverse tcp:8000 tcp:8000
```
This routes `http://localhost:8000` on the Android device directly to the PC's port 8000.

---

## 3. Launching the Flutter App
```bash
flutter run -d R5CY41WVF1H --android-skip-build-dependency-validation
```
