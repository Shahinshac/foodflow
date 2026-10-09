import os
from PIL import Image, ImageDraw

def create_app_icon(size):
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    padding = int(size * 0.05)
    # Draw rounded square background with vibrant orange #FF5722
    radius = int(size * 0.22)
    bg_color = (255, 87, 34, 255) # #FF5722
    draw.rounded_rectangle([padding, padding, size - padding, size - padding], radius=radius, fill=bg_color)

    # Draw white central food icon elements (Plate/Bowl & Spoon/Fork accents)
    center_x = size / 2.0
    center_y = size / 2.0

    # Outer white ring/plate
    plate_radius = int(size * 0.28)
    draw.ellipse([center_x - plate_radius, center_y - plate_radius, center_x + plate_radius, center_y + plate_radius], outline=(255, 255, 255, 255), width=max(2, int(size * 0.04)))

    # Inner fork/spoon silhouettes
    inner_r = int(size * 0.16)
    draw.ellipse([center_x - inner_r, center_y - inner_r, center_x + inner_r, center_y + inner_r], fill=(255, 255, 255, 255))
    draw.ellipse([center_x - inner_r * 0.6, center_y - inner_r * 0.6, center_x + inner_r * 0.6, center_y + inner_r * 0.6], fill=bg_color)

    return img

densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

base_res_dir = os.path.join('android', 'app', 'src', 'main', 'res')

for folder, dim in densities.items():
    folder_path = os.path.join(base_res_dir, folder)
    os.makedirs(folder_path, exist_ok=True)
    icon_img = create_app_icon(dim)
    icon_path = os.path.join(folder_path, 'ic_launcher.png')
    icon_img.save(icon_path)
    print(f"Generated {icon_path} ({dim}x{dim})")

print("All FeastFlow launcher icons generated successfully!")
