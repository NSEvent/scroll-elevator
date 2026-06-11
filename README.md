# Scroll Elevator

A tiny macOS menu-bar utility: when you scroll, it briefly shows two elevator
buttons right where your hand already is — jump to top above the cursor, jump
to bottom below it. Click one and the scrolled app leaps to its beginning or
end. Ignore them and they fade away.

## How it works

- A global `scrollWheel` monitor groups scroll events into bursts. When a burst
  ends (≈180 ms of quiet) and crossed the scroll threshold, the overlay appears
  anchored at the cursor position from the burst start — never on the first tick.
- The overlay is a non-activating borderless `NSPanel`, so clicking a button
  never steals focus from what you were scrolling.
- The window under the cursor is captured at burst start (scroll-follows-mouse
  means it isn't necessarily the frontmost window). Button clicks post
  `Cmd-↑` / `Cmd-↓` to that app's PID, activating it first if needed.
- The overlay hides on timeout, button click, any other click, key press,
  app switch, or when the pointer wanders well away from the anchor.

## Permissions

Accessibility access is required to post the jump keystrokes. The app prompts
on first launch; there's also a grant shortcut in the menu-bar menu and the
Settings window.

## Settings

Menu bar → Settings…

- Enable/disable
- Hide timeout (1–6 s)
- Button distance from cursor (30–80 pt)
- Scroll threshold before the overlay shows (20–200 pt)
- Ignored apps (games, remote desktops, design canvases…)

## Build

```sh
make install   # xcodegen + xcodebuild + codesign + copy to /Applications + launch
```

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
The install step signs with a Developer ID certificate so the Accessibility
grant survives rebuilds.
