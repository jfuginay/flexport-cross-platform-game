#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont
import colorsys

def create_gradient_background(width, height):
    """Create a gradient background"""
    image = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(image)
    
    # Define gradient colors (coral to turquoise to blue)
    colors = [
        (255, 107, 107),  # Coral red
        (78, 205, 196),   # Turquoise
        (69, 183, 209)    # Ocean blue
    ]
    
    for y in range(height):
        # Calculate which segment of the gradient we're in
        ratio = y / height
        
        if ratio < 0.5:
            # First half: coral to turquoise
            blend_ratio = ratio * 2
            r = int(colors[0][0] * (1 - blend_ratio) + colors[1][0] * blend_ratio)
            g = int(colors[0][1] * (1 - blend_ratio) + colors[1][1] * blend_ratio)
            b = int(colors[0][2] * (1 - blend_ratio) + colors[1][2] * blend_ratio)
        else:
            # Second half: turquoise to blue
            blend_ratio = (ratio - 0.5) * 2
            r = int(colors[1][0] * (1 - blend_ratio) + colors[2][0] * blend_ratio)
            g = int(colors[1][1] * (1 - blend_ratio) + colors[2][1] * blend_ratio)
            b = int(colors[1][2] * (1 - blend_ratio) + colors[2][2] * blend_ratio)
        
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    return image

def create_app_icon(size):
    """Create app icon of specified size"""
    # Create gradient background
    img = create_gradient_background(size, size)
    draw = ImageDraw.Draw(img)
    
    # Add ship emoji (we'll draw a simple ship shape instead)
    ship_size = size // 3
    ship_x = size // 2
    ship_y = size // 2 - size // 8
    
    # Draw ship hull
    hull_points = [
        (ship_x - ship_size//2, ship_y + ship_size//4),
        (ship_x + ship_size//2, ship_y + ship_size//4),
        (ship_x + ship_size//3, ship_y + ship_size//2),
        (ship_x - ship_size//3, ship_y + ship_size//2)
    ]
    draw.polygon(hull_points, fill=(255, 255, 255))
    
    # Draw mast
    mast_height = ship_size // 2
    draw.rectangle([
        ship_x - 2, ship_y - mast_height,
        ship_x + 2, ship_y + ship_size//4
    ], fill=(255, 255, 255))
    
    # Draw sail
    sail_width = ship_size // 3
    draw.polygon([
        (ship_x + 2, ship_y - mast_height),
        (ship_x + sail_width, ship_y - mast_height//2),
        (ship_x + 2, ship_y)
    ], fill=(255, 255, 255))
    
    # Add text if size is large enough
    if size >= 120:
        try:
            # Try to use system font
            font_size = max(8, size // 12)
            font = ImageFont.load_default()
            
            text = "FLEXPORT"
            text_bbox = draw.textbbox((0, 0), text, font=font)
            text_width = text_bbox[2] - text_bbox[0]
            text_height = text_bbox[3] - text_bbox[1]
            
            text_x = (size - text_width) // 2
            text_y = ship_y + ship_size//2 + 10
            
            # Add text outline for better visibility
            for offset in [(-1, -1), (-1, 1), (1, -1), (1, 1)]:
                draw.text((text_x + offset[0], text_y + offset[1]), text, 
                         fill=(0, 0, 0), font=font)
            
            draw.text((text_x, text_y), text, fill=(255, 255, 255), font=font)
        except:
            pass  # Skip text if font loading fails
    
    # Add AI badge for larger icons
    if size >= 60:
        badge_size = size // 8
        badge_x = size - badge_size - 8
        badge_y = 8
        
        # Draw badge background
        draw.ellipse([
            badge_x, badge_y,
            badge_x + badge_size, badge_y + badge_size
        ], fill=(255, 255, 255, 230))
        
        # Add AI text
        if size >= 120:
            try:
                ai_font_size = max(6, size // 20)
                font = ImageFont.load_default()
                draw.text((badge_x + 2, badge_y + 1), "AI", 
                         fill=(231, 76, 60), font=font)
            except:
                pass
    
    return img

def generate_all_icons():
    """Generate all required icon sizes"""
    base_path = "Sources/FlexPort/Assets.xcassets/AppIcon.appiconset"
    
    # Icon sizes to generate
    icon_specs = [
        ("AppIcon-20x20@2x.png", 40),
        ("AppIcon-20x20@3x.png", 60),
        ("AppIcon-29x29@2x.png", 58),
        ("AppIcon-29x29@3x.png", 87),
        ("AppIcon-40x40@2x.png", 80),
        ("AppIcon-40x40@3x.png", 120),
        ("AppIcon-60x60@2x.png", 120),
        ("AppIcon-60x60@3x.png", 180),
        ("AppIcon-20x20@1x.png", 20),
        ("AppIcon-29x29@1x.png", 29),
        ("AppIcon-40x40@1x.png", 40),
        ("AppIcon-76x76@1x.png", 76),
        ("AppIcon-76x76@2x.png", 152),
        ("AppIcon-83.5x83.5@2x.png", 167),
        ("AppIcon-1024x1024@1x.png", 1024),
    ]
    
    for filename, size in icon_specs:
        print(f"Generating {filename} ({size}x{size})")
        icon = create_app_icon(size)
        icon.save(os.path.join(base_path, filename), "PNG")
    
    print("All app icons generated successfully!")

if __name__ == "__main__":
    generate_all_icons()