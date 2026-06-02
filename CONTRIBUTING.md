# Contributing

Thanks for your interest in contributing to Calendar Airplane.

## Setup

1. Fork and clone the repository.
2. Open `CalendarAirplane.xcodeproj` in Xcode 15+.
3. Configure your local OAuth credentials as described in `README.md`.
4. Build and run on macOS 14+.

## Development guidelines

- Keep secrets out of git:
  - Do not commit `CalendarAirplane/GoogleOAuth.local.plist`.
  - Do not commit any `client_secret*.json` files or tokens.
- Keep changes focused and small when possible.
- Preserve current app behavior unless your PR intentionally changes it.
- Update `README.md` when setup, behavior, or UX changes.

## Pull requests

- Use a clear title and description of what changed and why.
- Include manual test steps (for example: sign-in flow, menu bar popover, demo flight).
- If your change impacts onboarding, include docs updates in the same PR.

## Code style

- Follow existing Swift/SwiftUI style in the repo.
- Prefer readable, maintainable code over clever shortcuts.
