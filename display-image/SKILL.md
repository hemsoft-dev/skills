---
name: display-image
description: V1.1 - Displays images using Directory Opus viewer with zoom-to-fit for visual verification. Use when you need to show screenshots, photos, or any image file to the user.
---

# Display Image

Display images using Directory Opus viewer for visual verification.

## ALWAYS: Log This Interaction

After completing work using this skill, append to `History/{YYYY-MM-DD}.md`:

```markdown
## {HH:MM} - {Action Taken}
{One-line summary of what was done}
```

## Usage

Call this skill when you need to display an image file to the user for verification or review.

## Implementation

Use Directory Opus d8viewer to open images with zoom-to-fit:

```powershell
& "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe" /fittopage "{FULL_IMAGE_PATH}"
```

Replace `{FULL_IMAGE_PATH}` with the absolute path to the image file.

### Command-Line Options

- `/fittopage` - Zoom image to fit window without scrollbars (recommended)
- `/fullscreen` - Open in fullscreen mode
- No option - Display at actual size (may require scrolling for large images)

## Supported Formats

- PNG, JPG, JPEG, BMP, GIF, TIFF
- Any format supported by Directory Opus viewer

## Example

```powershell
$imagePath = "C:\Users\User\Pictures\screenshot.png"
& "C:\Program Files\GPSoftware\Directory Opus\d8viewer.exe" /fittopage $imagePath
```
