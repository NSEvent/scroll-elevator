# Changelog

## 0.3.2 - 2026-06-11

### Fixed
- Hold-to-cruise actually cruises now. The hold and cruise timers were
  scheduled in the default run-loop mode, which never fires while the mouse
  button is held down (event-tracking mode) - exactly when cruising happens.
  All overlay timers now run in .common modes.
- make install clean-replaces the /Applications bundle (ditto merges into an
  existing bundle, and stale files break the signature seal, resetting the
  Accessibility grant) and signs in place after the copy, with a strict verify.

## 0.3.1 — 2026-06-11

### Fixed
- Releasing off the button cancels: press, drag away, let go — no jump fires.
  The pressed look tracks whether the pointer is on the button mid-drag, and a
  hold that has already left the button won't start a cruise.

## 0.3.0 — 2026-06-11

### Added
- Hold to cruise: press and hold a button and the page scrolls continuously
  in that direction, accelerating gently (500 → 2500 pt/s), until you release.
  Quick presses still jump. Synthetic pixel-scroll events route to the window
  beneath the overlay, so cruising works in anything scrollable; a global
  mouse-up backstop and a 20 s hard cap make a lost release harmless.

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
