# The mobile layer

Fixes that make a web app on a phone behave like an installed one. `build` applies them on every surface that ships to phones; `audit` reports each one a shipped surface misses, as a 🟡 finding unless the row says otherwise. Apply each fix where its reason applies, never as a global habit: `user-select: none` is correct on a button and a defect on body text.

## Rules every fix follows

- **Gate by capability, not by device.** Use `(hover: hover)`, `(pointer: fine)`, `env()`, and the `dvh`/`svh` units. A tablet with a trackpad and a laptop with a touchscreen are both real, so write for touch and mouse at once. Never branch on the user agent or on screen width to guess at touch.
- **Keep zoom.** `user-scalable=no` and `maximum-scale=1` are accessibility failures (🔴 in `audit`). The zoom they suppress comes from a small input font, so fix the font.
- **A phone confirms it.** Device emulation reproduces none of sticky hover, the tap highlight, the URL bar's effect on viewport height, input zoom, the click delay, overscroll, safe areas, or the software keyboard. Report each of these fixes as "verified from code" and name the ones the user confirms on hardware: the dev server on `0.0.0.0`, opened by LAN IP, inspected with Safari's Web Inspector or `chrome://inspect`, on a phone a few years old, once with the keyboard open.

## The fixes

| Symptom | Cause | Fix |
|---|---|---|
| A hover style stays on after a tap | touch fakes `:hover` on first tap and keeps it | put every `:hover` rule inside `@media (hover: hover) and (pointer: fine)`; Tailwind v4's `hover:` already compiles to `(hover: hover)`, and v3 needs `future.hoverOnlyWhenSupported` |
| A gray or blue flash on tap | the browser paints a highlight on clickable elements | `html { -webkit-tap-highlight-color: transparent; }`, then give every tappable element its own `:active` state, because the flash was its only feedback |
| A bottom-pinned button sits under the URL bar | `100vh` is the viewport with browser chrome collapsed | `100dvh` for an app shell, a drawer, and bottom-pinned UI; `min-height: 100svh` for a hero, which never overflows and never shifts on scroll |
| The page zooms into a focused input and stays zoomed | iOS zooms on inputs under 16px | `font-size: 16px` on `input`, `textarea`, and `select`, or only under `@media (pointer: coarse)` when the desktop design wants smaller text |
| The wrong keyboard opens | the field does not declare its content | `inputmode="numeric"` for codes, `inputmode="decimal"` for amounts, `type="email"` and `type="tel"`, `autocapitalize="none"` and `autocorrect="off"` on usernames and codes, `enterkeyhint` naming what return does |
| A tap feels late | a double-tap wait, and feedback on release | `touch-action: manipulation` on buttons, links, and `[role="button"]`; style `:active` and listen to `pointerdown`, so feedback starts when the finger lands |
| Pulling past the top refreshes the page, or a sheet drags the page behind it | scroll chains to the document | `overscroll-behavior: none` on `html, body` in an app with its own scroll containers; `overscroll-behavior: contain` on each inner scroller; never a `touchmove` listener with `preventDefault()` |
| Content stops short of the notch, or sits under the home indicator | the page is letterboxed into the safe area | `viewport-fit=cover` in the viewport meta, then `env(safe-area-inset-*)` padding on fixed headers, bottom bars, toasts, and sheets, with a `0px` fallback inside `calc()` |
| A long press selects a button's label | control text is selectable | `user-select: none`, `-webkit-user-select: none`, and `-webkit-touch-callout: none` on controls only: buttons, tabs, chips, drag handles; content text stays selectable |
| A horizontal carousel makes the page jitter vertically | the browser cannot tell which axis the element owns | `touch-action: pan-y` on a horizontal gesture surface, `pan-x` on a vertical one, `none` only on an element that handles every axis; for a native-scroll carousel, `scroll-snap-type: x mandatory` with `scroll-snap-align: start` instead |
| The status bar color fights the page | one `theme-color` serves both schemes | one `theme-color` meta per `prefers-color-scheme`, matched to the color at the top of the page, plus `<meta name="color-scheme" content="light dark">`; a class-based theme toggle updates the tag in JavaScript |

## The baseline

A new mobile-facing app ships this before its first component:

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content" />
<meta name="theme-color" media="(prefers-color-scheme: light)" content="<top-of-page light color>" />
<meta name="theme-color" media="(prefers-color-scheme: dark)" content="<top-of-page dark color>" />
```

```css
html {
  -webkit-tap-highlight-color: transparent;
  -webkit-text-size-adjust: 100%;
  overscroll-behavior: none; /* drop for a scrolling document where pull-to-refresh is welcome */
}
input, textarea, select { font-size: 16px; }
button, a, [role="button"] {
  touch-action: manipulation;
  user-select: none;
  -webkit-user-select: none;
}
@media (hover: hover) and (pointer: fine) {
  /* every :hover rule lives here */
}
```

`interactive-widget=resizes-content` makes the Android keyboard shrink the layout viewport, so `100dvh` and bottom-pinned inputs react to it as they do on iOS. Take the theme colors from `DESIGN.md` or the shipped header, never a brand color picked here.

Press feedback is motion: its curve and duration come from **motionkit** when installed, and otherwise stay at 100 to 160 ms with an ease-out curve on `transform` and `background`.

Credit: the symptom list follows Emil Kowalski's `mobile-native` skill (github.com/emilkowalski/skills, MIT), rewritten for this skill.
