---
name: image-magick
description: V1.0 - Expert in ImageMagick CLI for image manipulation, conversion, resizing, format changes, composition, effects, and batch processing. Use when working with images.
hooks:
  PostToolUse:
    - matcher: "Read|Write|Edit"
      hooks:
        - type: prompt
          prompt: |
            If a file was read, written, or edited in the image-magick directory (path contains 'image-magick'), verify that history logging occurred.
            
            Check if History/{YYYY-MM-DD}.md exists and contains an entry for this interaction with:
            - Format: "## HH:MM - {Action Taken}"
            - One-line summary
            - Accurate timestamp (obtained via `Get-Date -Format "HH:mm"` command, never guessed)
            
            If history entry is missing or incomplete, provide specific feedback on what needs to be added.
            If history entry exists and is properly formatted, acknowledge completion.
  Stop:
    - matcher: "*"
      hooks:
        - type: prompt
          prompt: |
            Before stopping, if image-magick was used (check if any files in image-magick directory were modified), verify that the interaction was logged:
            
            1. Check if History/{YYYY-MM-DD}.md exists in image-magick directory
            2. Verify it contains an entry with format "## HH:MM - {Action Taken}" where HH:MM was obtained via `Get-Date -Format "HH:mm"` (never guessed)
            3. Ensure the entry includes a one-line summary of what was done
            4. If retrospectives are enabled, verify retrospective check was performed
            
            If history entry is missing:
            - Return {"decision": "block", "reason": "History entry missing. Please log this interaction to History/{YYYY-MM-DD}.md with format: ## HH:MM - {Action Taken}\n{One-line summary}"}
            
            If history entry exists:
            - Return {"decision": "approve"}
            
            Include a systemMessage with details about the history entry status.
---

# ImageMagick Expert

Expert in using ImageMagick CLI for all image manipulation tasks.

## Core Commands

### magick (Main Command)

All operations use the `magick` command:

```powershell
magick input.png output.jpg
```

### convert (Legacy)

Older ImageMagick versions use `convert`:

```powershell
convert input.png output.jpg
```

## Common Operations

### Format Conversion

```powershell
# PNG to JPG
magick image.png image.jpg

# Multiple formats
magick image.png image.jpg image.webp image.gif

# Batch conversion
magick *.png -set filename:base "%[basename]" "%[filename:base].jpg"
```

### Resizing

```powershell
# Resize to specific width (maintain aspect ratio)
magick input.jpg -resize 800x output.jpg

# Resize to specific height (maintain aspect ratio)
magick input.jpg -resize x600 output.jpg

# Resize to exact dimensions (may distort)
magick input.jpg -resize 800x600! output.jpg

# Resize percentage
magick input.jpg -resize 50% output.jpg

# Resize with max dimensions (fit within box)
magick input.jpg -resize 800x600 output.jpg
```

### Quality Control

```powershell
# Set JPEG quality (1-100)
magick input.jpg -quality 85 output.jpg

# Compress PNG
magick input.png -quality 75 output.png

# WebP quality
magick input.jpg -quality 80 output.webp
```

### Cropping

```powershell
# Crop to specific dimensions from top-left
magick input.jpg -crop 800x600+0+0 output.jpg

# Crop from center
magick input.jpg -gravity center -crop 800x600+0+0 output.jpg

# Auto-crop whitespace
magick input.jpg -trim output.jpg
```

### Rotation & Flipping

```powershell
# Rotate 90 degrees clockwise
magick input.jpg -rotate 90 output.jpg

# Rotate 180 degrees
magick input.jpg -rotate 180 output.jpg

# Flip horizontal
magick input.jpg -flop output.jpg

# Flip vertical
magick input.jpg -flip output.jpg
```

### Image Information

```powershell
# Get image details
magick identify input.jpg

# Verbose information
magick identify -verbose input.jpg

# Specific properties
magick identify -format "%w x %h" input.jpg  # Dimensions
magick identify -format "%m" input.jpg        # Format
magick identify -format "%b" input.jpg        # File size
```

### Compositing & Overlays

```powershell
# Overlay one image on another
magick background.jpg overlay.png -gravity center -composite output.jpg

# Watermark
magick input.jpg watermark.png -gravity southeast -geometry +10+10 -composite output.jpg

# Tile pattern
magick input.jpg tile.png -tile -composite output.jpg
```

### Effects & Filters

```powershell
# Blur
magick input.jpg -blur 0x8 output.jpg

# Sharpen
magick input.jpg -sharpen 0x1 output.jpg

# Grayscale
magick input.jpg -colorspace Gray output.jpg

# Sepia tone
magick input.jpg -sepia-tone 80% output.jpg

# Border
magick input.jpg -border 10x10 -bordercolor black output.jpg

# Shadow
magick input.jpg -background black -shadow 80x3+5+5 output.jpg
```

### Text & Annotations

```powershell
# Add text
magick input.jpg -pointsize 36 -fill white -annotate +50+50 "Hello" output.jpg

# Text with background
magick input.jpg -pointsize 36 -fill white -box '#00000080' -annotate +50+50 "Hello" output.jpg

# Center text
magick input.jpg -gravity center -pointsize 36 -fill white -annotate +0+0 "Centered" output.jpg
```

### Batch Processing

```powershell
# Resize all JPGs in directory
Get-ChildItem *.jpg | ForEach-Object {
    magick $_.Name -resize 800x "resized-$($_.Name)"
}

# Convert all PNGs to JPG
Get-ChildItem *.png | ForEach-Object {
    $newName = $_.BaseName + ".jpg"
    magick $_.Name -quality 90 $newName
}

# Add watermark to all images
Get-ChildItem *.jpg | ForEach-Object {
    magick $_.Name watermark.png -gravity southeast -composite "watermarked-$($_.Name)"
}
```

### Creating Images

```powershell
# Create blank canvas
magick -size 800x600 xc:white canvas.jpg

# Create gradient
magick -size 800x600 gradient:blue-white gradient.jpg

# Create solid color
magick -size 800x600 xc:#FF5733 solid.jpg
```

### Combining Images

```powershell
# Append horizontally
magick image1.jpg image2.jpg +append combined.jpg

# Append vertically
magick image1.jpg image2.jpg -append combined.jpg

# Create montage/grid
magick montage *.jpg -tile 3x2 -geometry +5+5 montage.jpg
```

### Optimization

```powershell
# Optimize JPEG (remove metadata, optimize encoding)
magick input.jpg -strip -interlace Plane -quality 85 output.jpg

# Optimize PNG (best compression)
magick input.png -strip -define png:compression-level=9 output.png

# Progressive JPEG
magick input.jpg -interlace Plane output.jpg
```

## Advanced Techniques

### Channel Operations

```powershell
# Extract alpha channel
magick input.png -alpha extract alpha.png

# Remove transparency (replace with white)
magick input.png -background white -alpha remove output.png

# Add transparency
magick input.jpg -transparent white output.png
```

### Color Manipulation

```powershell
# Adjust brightness
magick input.jpg -modulate 120,100,100 output.jpg  # +20% brightness

# Adjust saturation
magick input.jpg -modulate 100,150,100 output.jpg  # +50% saturation

# Adjust hue
magick input.jpg -modulate 100,100,120 output.jpg  # +20% hue

# Normalize colors
magick input.jpg -normalize output.jpg

# Auto-level
magick input.jpg -auto-level output.jpg
```

### Masks & Transparency

```powershell
# Apply mask
magick input.jpg mask.png -alpha off -compose copy-opacity -composite output.png

# Vignette effect
magick input.jpg -background black -vignette 0x150 output.jpg
```

## Best Practices

1. **Always use `magick` command** (not `convert`) for modern ImageMagick 7+
2. **Preserve originals** - Never overwrite source images
3. **Use appropriate quality** - JPEG: 85-95, WebP: 80-90, PNG: compression level 9
4. **Strip metadata** for web images to reduce file size
5. **Use progressive JPEGs** for faster web loading
6. **Batch operations** - PowerShell loops for processing multiple files
7. **Test first** - Try operations on a single image before batch processing

## Troubleshooting

### Check Version

```powershell
magick --version
```

### Common Issues

- **"command not found"** - Restart terminal or check PATH
- **"unable to read font"** - Specify full font path for text operations
- **Memory issues** - Use `-limit memory 2GB -limit map 2GB` flags
- **Slow processing** - Reduce image size or quality settings

## File Format Support

| Format | Extension    | Use Case                              |
|--------|--------------|---------------------------------------|
| JPEG   | .jpg, .jpeg  | Photos, web images                    |
| PNG    | .png         | Transparency, graphics, screenshots   |
| WebP   | .webp        | Modern web format, smaller files      |
| GIF    | .gif         | Animations, simple graphics           |
| TIFF   | .tiff, .tif  | High-quality, print, archival         |
| BMP    | .bmp         | Windows bitmap, uncompressed          |
| SVG    | .svg         | Vector graphics (read-only)           |
| PDF    | .pdf         | Documents (requires Ghostscript)      |
| ICO    | .ico         | Windows icons                         |
| HEIC   | .heic        | iPhone photos (requires libheif)      |

## When to Use This Skill

- Converting image formats
- Resizing or cropping images
- Adding watermarks or overlays
- Batch processing multiple images
- Creating thumbnails
- Optimizing images for web
- Adding text to images
- Applying effects or filters
- Creating composite images
- Extracting image information
