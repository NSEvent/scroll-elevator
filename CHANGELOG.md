# Changelog

## 0.2.2 — 2026-06-11

### Removed
- Long-press paging. A press is a press: both quick and held clicks jump.
  Paging never felt right on a transient overlay.

## 0.2.1 — 2026-06-11

### Fixed
- Long-press paging now sends a synthetic scroll-wheel event to the view under
  the pointer instead of PageUp/PageDown keystrokes. Paging keys are
  interpreted inconsistently per app (terminals snap scrollback to the prompt
  on any keystroke; chat apps rebind them); a wheel event pages anything
  scrollable. Page size derives from the AX scroll area's height.
- Home/End key chords now carry the function-key modifier flag, matching real
  hardware events.

## 0.2.0 — 2026-06-11

### Added
- Accessibility scrollbar jumps: in Automatic mode the scroll view under the
  pointer is scrolled directly — no keystrokes, no caret movement, and
  background windows scroll without being activated. Falls back to keys.
- Per-app jump rules (Automatic / ⌘-arrows / Home-End / ⌘Home-⌘End / Ignore)
  with built-in defaults: Finder uses Home/End (⌘↑ would navigate to the
  enclosing folder), terminals use ⌘Home/⌘End.
- Long-press a button for page up / page down; the overlay stays for repeats.
- Edge awareness: the up button dims when already at the top, down at bottom.
- First-run welcome window with Accessibility grant and launch-at-login.
- Launch at login (Settings → General).
- Menu bar polish: filled/outline icon tracks enabled state, one-click
  "Ignore <frontmost app>", Welcome Guide entry.
- Tabbed Settings (General / Buttons / Apps) with app icons, idle-opacity
  slider and live button preview, modifier-gate option.
- App icon.
- Unit-tested scroll-burst state machine (`make test`).

### Fixed
- Clicks in the gap between the buttons — where the cursor parks — now pass
  through to the content underneath instead of being swallowed.
- A corridor-exit hide no longer leaves a dead zone: continued scrolling
  re-shows the overlay after the cooldown.
- The global scroll monitor is fully torn down while the app is disabled.

## 0.1.0 — 2026-06-11

Initial MVP: scroll-burst detection, cursor-anchored non-activating overlay
with jump-to-top/bottom buttons posting ⌘↑/⌘↓ to the captured app, corridor
dismissal, never-hide default, menu-bar controls, settings window.
