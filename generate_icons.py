#!/usr/bin/env python3
import os
import subprocess
import sys

def create_png_from_svg(svg_path, png_path, size):
    """Convert SVG to PNG using ImageMagick"""
    try:
        subprocess.run([
            'magick', 'convert', 
            '-background', 'transparent',
            '-size', f'{size}x{size}',
            svg_path, png_path
        ], check=True, capture_output=True)
        print(f"✓ Created {png_path} ({size}x{size})")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"⚠ Could not create {png_path}")
        return False

def main():
    svg_path = 'assets/logo.svg'
    
    if not os.path.exists(svg_path):
        print(f"Error: {svg_path} not found")
        sys.exit(1)
    
    # Define only essential Android icon sizes
    icon_configs = [
        ('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48),
        ('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72), 
        ('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96),
        ('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144),
        ('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192),
    ]
    
    print("Generating essential app icons from SVG...")
    success_count = 0
    
    for png_path, size in icon_configs:
        os.makedirs(os.path.dirname(png_path), exist_ok=True)
        if create_png_from_svg(svg_path, png_path, size):
            success_count += 1
    
    print(f"\n✅ Generated {success_count}/{len(icon_configs)} icons successfully!")

if __name__ == "__main__":
    main()