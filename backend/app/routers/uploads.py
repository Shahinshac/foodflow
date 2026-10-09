import os
import shutil
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from ..auth import get_current_user
from ..models import User

router = APIRouter(prefix="/uploads", tags=["File & Image Storage"])

UPLOAD_DIR = "uploads/images"
os.makedirs(UPLOAD_DIR, exist_ok=True)

CLOUDINARY_URL = os.getenv("CLOUDINARY_URL")
cloudinary_enabled = False

if CLOUDINARY_URL:
    try:
        import cloudinary
        import cloudinary.uploader
        cloudinary.config(cloudinary_url=CLOUDINARY_URL)
        cloudinary_enabled = True
    except Exception as e:
        print(f"Warning: Cloudinary initialization failed: {e}. Falling back to local storage.")

@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")

    # Prevent large files (> 5MB)
    file.file.seek(0, 2)
    file_size = file.file.tell()
    file.file.seek(0)
    if file_size > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum size is 5MB.")

    # If Cloudinary is configured, upload directly to cloud persistent storage
    if cloudinary_enabled:
        try:
            upload_result = cloudinary.uploader.upload(
                file.file,
                folder="foodflow_uploads",
                resource_type="image"
            )
            return {"url": upload_result.get("secure_url")}
        except Exception as e:
            print(f"Cloud upload error: {e}. Falling back to local storage.")

    # Fallback to local storage
    ext = file.filename.split('.')[-1] if '.' in file.filename else 'jpg'
    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    return {"url": f"/uploads/images/{filename}"}
