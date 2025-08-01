#!/usr/bin/env python3
"""
Generate Robot App Icons for AhamAI
Creates icons for both light and dark themes from the robot design
"""

import os
import subprocess
import sys

def create_robot_svg(is_dark_theme=False):
    """Create SVG content for robot icon"""
    
    # Colors based on theme
    if is_dark_theme:
        bg_color = "#000000"  # Dark background
        robot_fill = "#FFFFFF"  # White robot
        robot_stroke = "#000000"  # Black stroke
        eye_color = "#000000"  # Black eyes
        eye_sparkle = "#FFFFFF"  # White sparkles
        antenna_tip = "#FFFFFF"  # White antenna tip
    else:
        bg_color = "#F4F3F0"  # Light background (app color)
        robot_fill = "#FFFFFF"  # White robot
        robot_stroke = "#000000"  # Black stroke
        eye_color = "#000000"  # Black eyes
        eye_sparkle = "#FFFFFF"  # White sparkles
        antenna_tip = "#000000"  # Black antenna tip
    
    svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="512" height="512" rx="90" ry="90" fill="{bg_color}"/>
  
  <!-- Robot centered in icon -->
  <g transform="translate(256, 256)">
    
    <!-- Robot Body -->
    <rect x="-45" y="-25" width="90" height="110" rx="20" ry="20" 
          fill="{robot_fill}" stroke="{robot_stroke}" stroke-width="4"/>
    
    <!-- Robot Head -->
    <circle cx="0" cy="-80" r="44" 
            fill="{robot_fill}" stroke="{robot_stroke}" stroke-width="4"/>
    
    <!-- Eyes -->
    <circle cx="-14" cy="-85" r="8" fill="{eye_color}"/>
    <circle cx="14" cy="-85" r="8" fill="{eye_color}"/>
    
    <!-- Eye sparkles -->
    <circle cx="-12" cy="-88" r="3" fill="{eye_sparkle}"/>
    <circle cx="16" cy="-88" r="3" fill="{eye_sparkle}"/>
    
    <!-- Happy mouth -->
    <path d="M -16 -65 Q 0 -52 16 -65" 
          fill="none" stroke="{robot_stroke}" stroke-width="6" stroke-linecap="round"/>
    
    <!-- Antenna -->
    <line x1="0" y1="-124" x2="0" y2="-140" 
          stroke="{robot_stroke}" stroke-width="4" stroke-linecap="round"/>
    
    <!-- Antenna tip -->
    <circle cx="0" cy="-140" r="6" fill="{antenna_tip}"/>
    <circle cx="0" cy="-140" r="3" fill="{eye_sparkle}"/>
    
    <!-- Arms -->
    <line x1="-45" y1="-15" x2="-70" y2="-40" 
          stroke="{robot_stroke}" stroke-width="8" stroke-linecap="round"/>
    <line x1="45" y1="-15" x2="75" y2="-20" 
          stroke="{robot_stroke}" stroke-width="8" stroke-linecap="round"/>
    
    <!-- Legs -->
    <line x1="-24" y1="85" x2="-24" y2="120" 
          stroke="{robot_stroke}" stroke-width="8" stroke-linecap="round"/>
    <line x1="24" y1="85" x2="24" y2="120" 
          stroke="{robot_stroke}" stroke-width="8" stroke-linecap="round"/>
    
    <!-- Feet -->
    <circle cx="-24" cy="125" r="8" fill="{robot_stroke}"/>
    <circle cx="24" cy="125" r="8" fill="{robot_stroke}"/>
    
    <!-- Chest panel -->
    <rect x="-18" y="-10" width="36" height="48" rx="6" ry="6" 
          fill="none" stroke="{robot_stroke}" stroke-width="2"/>
    
    <!-- Chest buttons -->
    <circle cx="-10" cy="-5" r="4" fill="{robot_stroke}"/>
    <circle cx="10" cy="-5" r="4" fill="{robot_stroke}"/>
    <circle cx="0" cy="15" r="4" fill="{robot_stroke}"/>
    
    <!-- Extra details for personality -->
    <!-- Heart on chest (optional cute detail) -->
    <path d="M -3 5 C -3 2, 0 2, 0 5 C 0 2, 3 2, 3 5 C 3 8, 0 11, 0 11 C 0 11, -3 8, -3 5 Z" 
          fill="{robot_stroke}" opacity="0.3"/>
    
  </g>
</svg>'''
    
    return svg_content

def generate_icons():
    """Generate robot app icons for different sizes and themes"""
    
    # Icon sizes for Android
    sizes = [
        (48, "mipmap-mdpi"),
        (72, "mipmap-hdpi"), 
        (96, "mipmap-xhdpi"),
        (144, "mipmap-xxhdpi"),
        (192, "mipmap-xxxhdpi")
    ]
    
    # Create SVG files for both themes
    light_svg = create_robot_svg(is_dark_theme=False)
    dark_svg = create_robot_svg(is_dark_theme=True)
    
    with open("robot_icon_light.svg", "w") as f:
        f.write(light_svg)
    
    with open("robot_icon_dark.svg", "w") as f:
        f.write(dark_svg)
    
    print("🤖 Generated robot SVG files!")
    
    # Generate PNG icons for each size and theme
    for size, folder in sizes:
        # Create directories
        light_dir = f"android/app/src/main/res/{folder}"
        os.makedirs(light_dir, exist_ok=True)
        
        # For now, we'll use the light theme for all icons
        # In a full implementation, you'd want adaptive icons for both themes
        try:
            # Try with inkscape first
            cmd_light = [
                "inkscape", 
                "--export-type=png",
                f"--export-width={size}",
                f"--export-height={size}",
                f"--export-filename={light_dir}/ic_launcher.png",
                "robot_icon_light.svg"
            ]
            
            result = subprocess.run(cmd_light, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✅ Generated {size}x{size} robot icon with Inkscape")
            else:
                raise Exception("Inkscape failed")
                
        except:
            try:
                # Fallback to ImageMagick
                cmd_light = [
                    "convert",
                    "robot_icon_light.svg",
                    "-resize", f"{size}x{size}",
                    f"{light_dir}/ic_launcher.png"
                ]
                
                result = subprocess.run(cmd_light, capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"✅ Generated {size}x{size} robot icon with ImageMagick")
                else:
                    print(f"❌ Failed to generate {size}x{size} icon")
                    
            except Exception as e:
                print(f"❌ Error generating {size}x{size} icon: {e}")
    
    # Clean up SVG files
    try:
        os.remove("robot_icon_light.svg")
        os.remove("robot_icon_dark.svg")
        print("🧹 Cleaned up temporary SVG files")
    except:
        pass
    
    print("🎉 Robot app icons generated successfully!")
    print("📱 The robot from your splash screen is now your app icon!")

if __name__ == "__main__":
    generate_icons()