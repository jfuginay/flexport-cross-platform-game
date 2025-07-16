#\!/bin/bash
# Create a simple gradient using ImageMagick alternative or built-in tools
# Using sips to create a solid color image and then we'll add gradient with other methods

# Create a solid blue square
/usr/bin/sips -s format png -s pixelWidth 1024 -s pixelHeight 1024 --setProperty color 4ECDC4 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns --out temp_base.png 2>/dev/null || echo "Using alternative method..."

# If that fails, create using a different approach
if [ \! -f temp_base.png ]; then
    # Create using Python with only standard library
    python3 << 'PYTHON_EOF'
import struct
import os

def create_simple_png(width, height, r, g, b, filename):
    """Create a simple PNG file with solid color using pure Python"""
    
    def write_chunk(f, chunk_type, data):
        f.write(struct.pack('>I', len(data)))
        f.write(chunk_type)
        f.write(data)
        crc = 0xffffffff
        for byte in chunk_type + data:
            crc ^= byte
            for _ in range(8):
                if crc & 1:
                    crc = (crc >> 1) ^ 0xedb88320
                else:
                    crc >>= 1
        f.write(struct.pack('>I', crc ^ 0xffffffff))
    
    with open(filename, 'wb') as f:
        # PNG signature
        f.write(b'\x89PNG\r\n\x1a\n')
        
        # IHDR chunk
        ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
        write_chunk(f, b'IHDR', ihdr)
        
        # IDAT chunk with image data
        import zlib
        scanlines = []
        for y in range(height):
            # Create gradient effect
            ratio = y / height
            current_r = int(r * (1 - ratio) + 69 * ratio)  # Blend to blue
            current_g = int(g * (1 - ratio) + 183 * ratio)
            current_b = int(b * (1 - ratio) + 209 * ratio)
            
            scanline = bytearray([0])  # Filter type 0 (None)
            for x in range(width):
                scanline.extend([current_r, current_g, current_b])
            scanlines.extend(scanline)
        
        compressor = zlib.compressobj()
        png_data = compressor.compress(bytes(scanlines))
        png_data += compressor.flush()
        write_chunk(f, b'IDAT', png_data)
        
        # IEND chunk
        write_chunk(f, b'IEND', b'')

# Create gradient from coral to blue
create_simple_png(1024, 1024, 255, 107, 107, 'AppIcon-1024x1024@1x.png')
create_simple_png(180, 180, 255, 107, 107, 'AppIcon-60x60@3x.png')
create_simple_png(120, 120, 255, 107, 107, 'AppIcon-60x60@2x.png')
create_simple_png(120, 120, 255, 107, 107, 'AppIcon-40x40@3x.png')
create_simple_png(87, 87, 255, 107, 107, 'AppIcon-29x29@3x.png')
create_simple_png(80, 80, 255, 107, 107, 'AppIcon-40x40@2x.png')
create_simple_png(76, 76, 255, 107, 107, 'AppIcon-76x76@1x.png')
create_simple_png(167, 167, 255, 107, 107, 'AppIcon-83.5x83.5@2x.png')
create_simple_png(152, 152, 255, 107, 107, 'AppIcon-76x76@2x.png')
create_simple_png(60, 60, 255, 107, 107, 'AppIcon-20x20@3x.png')
create_simple_png(58, 58, 255, 107, 107, 'AppIcon-29x29@2x.png')
create_simple_png(40, 40, 255, 107, 107, 'AppIcon-40x40@1x.png')
create_simple_png(40, 40, 255, 107, 107, 'AppIcon-20x20@2x.png')
create_simple_png(29, 29, 255, 107, 107, 'AppIcon-29x29@1x.png')
create_simple_png(20, 20, 255, 107, 107, 'AppIcon-20x20@1x.png')

print("App icons created successfully\!")
PYTHON_EOF
fi
