#!/usr/bin/env python3
"""
Generate AhamAI Text Logo App Icons
Creates text-based icons using the same font as the app
"""

import os
import subprocess
import sys

def create_ahamai_text_svg(is_dark_theme=False):
    """Create SVG content for AhamAI text logo icon"""
    
    # Colors based on theme
    if is_dark_theme:
        bg_color = "#000000"  # Dark background
        text_color = "#FFFFFF"  # White text
        accent_color = "#FFFFFF"  # White accent
    else:
        bg_color = "#F4F3F0"  # Light background (app color)
        text_color = "#000000"  # Black text
        accent_color = "#000000"  # Black accent
    
    svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="512" height="512" rx="90" ry="90" fill="{bg_color}"/>
  
  <!-- AhamAI Text Logo -->
  <g transform="translate(256, 256)">
    
    <!-- Main AhamAI Text -->
    <text x="0" y="10" 
          font-family="Monaco, 'Space Mono', 'Courier New', monospace" 
          font-size="64" 
          font-weight="bold" 
          text-anchor="middle" 
          fill="{text_color}"
          letter-spacing="2px">AhamAI</text>
    
    <!-- AI Badge/Accent -->
    <rect x="-80" y="-45" width="32" height="32" rx="8" ry="8" fill="{accent_color}"/>
    <circle cx="-64" cy="-29" r="8" fill="{bg_color}"/>
    <circle cx="-64" cy="-29" r="3" fill="{accent_color}"/>
    
    <!-- Small decorative elements -->
    <circle cx="85" cy="-35" r="4" fill="{accent_color}" opacity="0.6"/>
    <circle cx="95" cy="-20" r="3" fill="{accent_color}" opacity="0.4"/>
    <circle cx="75" cy="-15" r="2" fill="{accent_color}" opacity="0.8"/>
    
    <!-- Bottom accent line -->
    <rect x="-60" y="35" width="120" height="3" rx="1.5" ry="1.5" fill="{accent_color}" opacity="0.3"/>
    
  </g>
</svg>'''
    
    return svg_content

def generate_text_icons():
    """Generate AhamAI text logo app icons for different sizes and themes"""
    
    # Icon sizes for Android
    sizes = [
        (48, "mipmap-mdpi"),
        (72, "mipmap-hdpi"), 
        (96, "mipmap-xhdpi"),
        (144, "mipmap-xxhdpi"),
        (192, "mipmap-xxxhdpi")
    ]
    
    # Create SVG files for both themes
    light_svg = create_ahamai_text_svg(is_dark_theme=False)
    dark_svg = create_ahamai_text_svg(is_dark_theme=True)
    
    with open("ahamai_text_icon_light.svg", "w") as f:
        f.write(light_svg)
    
    with open("ahamai_text_icon_dark.svg", "w") as f:
        f.write(dark_svg)
    
    print("✍️ Generated AhamAI text logo SVG files!")
    
    # Generate PNG icons for each size
    for size, folder in sizes:
        # Create directories
        light_dir = f"android/app/src/main/res/{folder}"
        os.makedirs(light_dir, exist_ok=True)
        
        try:
            # Try with inkscape first
            cmd_light = [
                "inkscape", 
                "--export-type=png",
                f"--export-width={size}",
                f"--export-height={size}",
                f"--export-filename={light_dir}/ic_launcher.png",
                "ahamai_text_icon_light.svg"
            ]
            
            result = subprocess.run(cmd_light, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✅ Generated {size}x{size} AhamAI text icon with Inkscape")
            else:
                raise Exception("Inkscape failed")
                
        except:
            try:
                # Fallback to ImageMagick
                cmd_light = [
                    "convert",
                    "ahamai_text_icon_light.svg",
                    "-resize", f"{size}x{size}",
                    f"{light_dir}/ic_launcher.png"
                ]
                
                result = subprocess.run(cmd_light, capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"✅ Generated {size}x{size} AhamAI text icon with ImageMagick")
                else:
                    print(f"❌ Failed to generate {size}x{size} icon")
                    
            except Exception as e:
                print(f"❌ Error generating {size}x{size} icon: {e}")
    
    # Clean up SVG files
    try:
        os.remove("ahamai_text_icon_light.svg")
        os.remove("ahamai_text_icon_dark.svg")
        print("🧹 Cleaned up temporary SVG files")
    except:
        pass
    
    print("🎉 AhamAI text logo app icons generated successfully!")
    print("📱 Your app now has the same AhamAI text logo as your app!")

if __name__ == "__main__":
    generate_text_icons()