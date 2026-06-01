# Calendar Airplane (macOS)

SwiftUI app that connects to Google Calendar and plays a click-through overlay: an airplane flies left to right with a banner showing the upcoming meeting title.

## Requirements

- macOS 14+
- Xcode 15+ (full Xcode, not Command Line Tools only)
- Google Cloud project with Calendar API enabled

## Google Cloud setup

1. Create a project and enable **Google Calendar API**.
2. Configure the **OAuth consent screen** and add yourself as a test user (while in Testing).
3. Create an OAuth client ID of type **Desktop app**.
4. Under the client, add an authorized redirect URI:
   - `com.calendarairplane.app:/oauth2redirect`
5. Copy the **Client ID** into [`CalendarAirplane/Info.plist`](CalendarAirplane/Info.plist) as `GOOGLE_CLIENT_ID` (replace the placeholder).

## Run in Xcode

1. Open [`CalendarAirplane.xcodeproj`](CalendarAirplane.xcodeproj).
2. Select your **Signing Team** in the target’s Signing & Capabilities.
3. Build and run (⌘R).
4. **Calendar Airplane → Settings**: sign in with Google, enable **Open at login** if you want startup launch, set lead time, use **Demo View** to preview the animation.

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
