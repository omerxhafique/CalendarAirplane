# Calendar Airplane (macOS)

SwiftUI app that connects to Google Calendar and plays a click-through overlay: an airplane flies left to right with a banner showing the upcoming meeting title.

## Requirements

- macOS 14+
- Xcode 15+ (full Xcode, not Command Line Tools only)
- Google Cloud project with Calendar API enabled

## Google Cloud setup

1. Create a project and enable **Google Calendar API**.
2. Configure the **OAuth consent screen** and add yourself as a test user (while in Testing).
3. Create an OAuth client ID of type **Desktop app** (there is no redirect URI field — that is normal).
4. **OAuth credentials (keep secrets out of git):**
   ```bash
   cp CalendarAirplane/GoogleOAuth.local.plist.example CalendarAirplane/GoogleOAuth.local.plist
   ```
   Edit `GoogleOAuth.local.plist` with your Desktop client **Client ID** and **Client secret**.  
   This file is listed in `.gitignore` and is **not** pushed to GitHub.

5. (Recommended for safer local installs) store secrets outside the repo and app bundle:
   ```bash
   mkdir -p "$HOME/Library/Application Support/CalendarAirplane"
   cp CalendarAirplane/GoogleOAuth.local.plist.example "$HOME/Library/Application Support/CalendarAirplane/GoogleOAuth.local.plist"
   ```
   The app checks this external file first, then falls back to bundled `GoogleOAuth.local.plist` for development.
   `Info.plist` only contains placeholders.

The app uses Google’s loopback redirect `http://127.0.0.1:8765/oauth2redirect`, which Desktop clients allow automatically.

## Run in Xcode

1. Open [`CalendarAirplane.xcodeproj`](CalendarAirplane.xcodeproj).
2. Select your **Signing Team** in the target’s Signing & Capabilities.
3. Build and run (⌘R).
4. **Calendar Airplane → Settings**: sign in with Google, enable **Open at login** if you want startup launch, set lead time/speed, use **Demo flight** to preview the animation.

## Open-source safety checklist

Before making the repo public:

- Keep `CalendarAirplane/GoogleOAuth.local.plist` untracked (already in `.gitignore`).
- Rotate OAuth credentials if they were ever shared or committed before.
- Keep `Info.plist` values as placeholders only (`YOUR_*`).
- Avoid distributing binaries that contain your personal OAuth secret.
- Prefer the external config file (`~/Library/Application Support/CalendarAirplane/GoogleOAuth.local.plist`) for personal builds.

## Local release/install checklist (no paid Apple developer account)

1. In Xcode target **Signing & Capabilities**, select your **Personal Team**.
2. Build a **Release** archive (`Product` → `Archive`).
3. Export, then move `Calendar Airplane.app` to `/Applications`.
4. Launch once; if blocked, allow via **System Settings → Privacy & Security → Open Anyway**.
5. Verify:
   - Menu bar airplane icon is visible.
   - **Settings** opens from the popover.
   - Google sign-in works.
   - **Demo flight** runs.
   - **Open at login** toggle works after relaunch.

## Behavior

- Polls your **primary** calendar every 60 seconds.
- When a meeting starts within your configured lead time (default 10 minutes), the flyover runs once per event instance.
- Overlay is click-through and appears above normal windows (macOS may still hide it in some full-screen cases).

## Project layout

- `CalendarAirplane/App` — app entry
- `CalendarAirplane/Services` — OAuth, calendar API, scheduler
- `CalendarAirplane/Overlay` — `NSPanel` overlay host
- `CalendarAirplane/Views` — UI and animation
- `CalendarAirplane/Assets.xcassets/FlyoverPlane` — cartoon plane image (replace PNG to customize)

## Customize the plane & icon

The **flyover animation** uses the `FlyoverPlane` image asset (transparent PNG). The **app icon** uses the same art on a white square.

The **Dock/Finder icon** uses `Assets.xcassets/AppIcon.appiconset/` — plane centered on a **white** square. To change it, replace `FlyoverPlane.png` with a **transparent** PNG (side view, nose right), regenerate `AppIcon.appiconset/icon_*.png`, then clean build (⇧⌘K, ⌘R).
