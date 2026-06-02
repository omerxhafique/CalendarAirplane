# Security Policy

## Supported versions

This project is maintained on the `main` branch.

## Reporting a vulnerability

Please do not open public issues for security vulnerabilities.

Report privately by contacting the maintainer directly and include:

- A clear description of the issue
- Steps to reproduce
- Impact assessment
- Suggested fix (if known)

## Secrets handling

- Never commit OAuth client secrets, refresh tokens, or access tokens.
- Keep local credentials in:
  - `~/Library/Application Support/CalendarAirplane/GoogleOAuth.local.plist` (recommended), or
  - `CalendarAirplane/GoogleOAuth.local.plist` for local development only (gitignored).
