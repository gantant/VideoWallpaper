https://github.com/user-attachments/assets/632269ea-a543-48a1-a6f9-4583deff1ca6

VideoWallpaper (macOS)

A lightweight menu bar app that lets you set looping videos as your desktop wallpaper. Built with SwiftUI and AVFoundation, it runs quietly in the background and gives quick access to your video wallpapers through a clean, minimal interface. (Entirely Vibe-Coded).

⸻

Features
- Live video wallpapers
Play any video file as your desktop background, looping seamlessly.
- Menu bar app
No dock clutter. Access everything from a compact popover.
- Multi-monitor support
Automatically applies the video across all connected displays.
- Collection system
Save wallpapers to a dedicated library:
- Grid layout with thumbnails
- Quick preview + apply
- Remove or manage saved videos
- Smart UI
- Dynamic "Already in Collection" state
- Hover effects and polished controls
- Fast switching between wallpapers
- No audio playback
Videos are muted by default for a clean desktop experience.

⸻

How it works

The app creates borderless windows positioned behind desktop icons and uses AVPlayer to render looping video content. Each display gets its own synchronized player instance for consistent playback.

⸻

Usage
1. Launch the app (menu bar icon appears)
2. Select a video file
3. Click Set as Wallpaper
4. (Optional) Save it to your collection for quick access later

⸻

Tech Stack
- SwiftUI (UI)
- AppKit (window management)
- AVFoundation (video playback)

⸻

Notes
- Works best with standard .mp4 or .mov files
- use this pathname to access apple's official aerials. '/Users/Name/Library/Application Support/com.apple.wallpaper/aerials/videos/'
- I found that this website has great videos for wallpapers "[moewalls.com](https://moewalls.com)"
- It will deny opening the first time because i'm too lazy to pay for something. Go to settings -> privacy & security -> open anyways
- This is my first git project so tell me if something is incorrect or off.

⸻

Future Improvements
- Startup launch option
- Wallpaper playlists
- Performance tuning for high-resolution videos
- More UI customization

⸻

Simple, fast, and focused—VideoWallpaper turns your desktop into a live canvas without getting in your way.
