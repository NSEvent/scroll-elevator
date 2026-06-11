# Scroll Elevator

A tiny macOS menu-bar utility: when you scroll, two translucent elevator
buttons appear right where your hand already is — jump to top above the
cursor, jump to bottom below it. Click one and the scrolled app leaps to its
beginning or end. Hold one to page up/down. Move the mouse away and they
vanish.

## How it works

- A global `scrollWheel` monitor groups scroll events into bursts (a pure,
  unit-tested state machine). The overlay appears the moment a burst crosses
  the scroll threshold (default 10 pt) — mid-gesture, essentially as soon as
  you begin to scroll. Continued scrolling keeps it alive.
- It anchors at the cursor position at show time and lives inside a tall,
  narrow corridor: tight left/right (a bit wider than the buttons), roomier
  up/down (a bit past the buttons). Leave the corridor and it hides.
- The overlay is a non-activating borderless `NSPanel`; only the two button
  circles are clickable — clicks in the gap between them pass through to the
  content underneath. It never steals focus.
- **Jumping (Automatic mode):** the Accessibility scrollbar of the scroll view
  under your pointer is set directly — no keystrokes, no caret movement, and
  background windows scroll without coming forward. Where no scrollbar is
  exposed, a per-app key ladder takes over: Finder gets Home/End (⌘↑ would
  navigate to the enclosing folder), terminals get ⌘Home/⌘End, everything
  else gets ⌘↑/⌘↓. Per-app rules are editable in Settings → Apps.
- **Edge awareness:** when the scroll position is readable, the button that
  can't do anything (already at top/bottom) dims further.
- **Long-press** a button (≥0.35 s) for page up/down; the overlay stays up so
  you can keep paging.
- By default the overlay never hides on its own — corridor exit, button click,
  outside click, or app switch dismiss it. An optional hide-after timeout can
  be enabled in Settings.

## Permissions

Accessibility access is required (scrollbar control and jump keystrokes). The
first-run welcome window walks through the grant; it's also available from the
menu-bar menu and Settings.

## Settings

Menu bar → Settings… (tabs: General / Buttons / Apps)

- Enable/disable, launch at login
- Never hide automatically (default on) / hide timeout (1–6 s)
- Optional modifier gate (only show while holding ⌘/⌥/⌃/⇧)
- Button distance from cursor (30–80 pt, default 56)
- Scroll threshold before the overlay shows (0–200 pt, default 10)
- Idle opacity with live preview (default 30%)
- Per-app rules: Automatic / ⌘-arrows / Home-End / ⌘Home-⌘End / Ignore

Menu-bar quick actions: toggle Enabled (icon tracks state), one-click
"Ignore <frontmost app>", Welcome Guide.

## Build

```sh
make install   # xcodegen + xcodebuild + codesign + copy to /Applications + launch
make test      # unit tests (scroll-burst state machine)
```

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
The install step signs with a Developer ID certificate so the Accessibility
grant survives rebuilds. Version lives in `version.env`.
