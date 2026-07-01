# Security Policy

## Reporting a vulnerability

If you find a security or privacy issue in Scroll Elevator, please report it
privately rather than opening a public issue.

- **Email:** martini-doubler7g@icloud.com
- Please include a description, reproduction steps, the app/build version (see
  `version.env` or the About window), and your macOS version.

I'll acknowledge reports as quickly as I can and keep you updated on a fix.
Please give a reasonable window to address the issue before any public
disclosure.

## Scope

Scroll Elevator is a local, sandbox-free menu-bar utility that requests only the
**Accessibility** permission and makes **no network connections** — no
analytics, no telemetry, nothing leaves your Mac. Relevant areas for reports:

- Misuse of the Accessibility permission (reading content, logging keystrokes)
- Any unexpected network activity
- Code-signing / notarization integrity of released builds
- Local privilege or data-exposure issues

## Supported versions

The latest released version (on
[Gumroad](https://thekevintang.gumroad.com/l/scroll-elevator) and tagged in this
repo) is the supported one. Fixes ship in a new release rather than as patches to
older builds.
