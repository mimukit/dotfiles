# motionkit recipes

Starting points for common components. Each entry gives the curve, duration, properties, and reduced-motion behavior; adapt it to the project's tokens and markup. The curve names are the tokens in [Easing](SKILL.md#easing), and the reduced-motion rule is [Reduced motion and pointer gating](SKILL.md#reduced-motion-and-pointer-gating). The `data-starting-style` and `data-ending-style` attributes are Base UI's; map them to the project's own open and closed states.

## Button press

Curve `--ease-out`. Duration 160 ms. Properties `transform`. Reduced motion: drop the scale and mark the press with a background-color change.

```css
.button { transition: transform 160ms var(--ease-out); }
.button:active { transform: scale(0.97); }
```

`:active` is a real press on touch, so it needs no pointer gate; gate any `:hover` style on its own.

## Dropdown, popover, menu, select

Curve `--ease-out`. Duration 200 ms. Properties `opacity`, `transform`. Reduced motion: opacity only, at the same duration.

```css
.popover {
  transform-origin: var(--transform-origin);
  transition: opacity 200ms var(--ease-out), transform 200ms var(--ease-out);
}
.popover[data-starting-style],
.popover[data-ending-style] { opacity: 0; transform: scale(0.95); }
```

The origin carries the effect: the panel reads as coming out of the control that opened it.

## Tooltip

Curve `--ease-out`. Duration 125 ms. Properties `opacity`, `transform`. Reduced motion: opacity only.

Use the popover shape at 125 ms, starting from `scale(0.97)`. Keep the library's open delay on the first tooltip, because it stops accidental opens. Once one tooltip is open, open its neighbors with no delay and no transition (`skipDelayDuration` on the Radix provider; `[data-instant] { transition-duration: 0ms; }` in Base UI).

## Modal

Curve `--ease-out`. Duration 250 ms. Properties `opacity`, `transform` on the panel, `opacity` on the backdrop. Reduced motion: opacity only on both.

The panel enters from `scale(0.96)` with `opacity: 0` and keeps `transform-origin: center`, because a modal belongs to the viewport, not to a trigger. Run the backdrop's opacity on the same duration and curve so the two read as one surface.

## Drawer or sheet

Curve `--ease-drawer`. Duration 500 ms. Properties `transform`. Reduced motion: fade in place with `opacity` over 200 ms on `ease`, with no translate.

```css
.drawer { transform: translateY(0); transition: transform 500ms var(--ease-drawer); }
.drawer[data-closed] { transform: translateY(100%); }
```

The percentage moves the drawer by its own height whatever its content. A draggable drawer adds [Drag to dismiss](#drag-to-dismiss).

## Toast

Curve `ease`. Duration 400 ms. Properties `opacity`, `transform`. Reduced motion: opacity only, at the same duration.

```css
.toast {
  transition: opacity 400ms ease, transform 400ms ease;
  @starting-style { opacity: 0; transform: translateY(100%); }
}
```

A toast can run slower than the UI band on plain `ease`, which suits its personality. Without `@starting-style`, set `data-mounted` in an effect after mount and transition on it. It is a transition, never keyframes, because a second toast can arrive mid-motion. When stacked toasts reflow, tune opacity against height by eye and label it "needs a recording".

## Accordion or collapse

Curve `--ease-out`. Duration 200 ms. Properties `height`, `opacity`. Reduced motion: the height changes at once and the opacity keeps its 200 ms fade.

Set `overflow: hidden` and animate to a measured pixel height, from JavaScript or a headless primitive that exposes it, rather than to `auto`. Keep it short: this is the one tolerated layout animation, and it costs layout every frame.

## Stagger a group entrance

Curve `--ease-out`. Duration 300 ms per item, offset 50 ms per item. Properties `opacity`, `transform`. Reduced motion: the whole group fades in together, with no offset and no translate.

```css
.item { opacity: 0; transform: translateY(8px); animation: rise 300ms var(--ease-out) forwards; }
.item:nth-child(2) { animation-delay: 50ms; }
.item:nth-child(3) { animation-delay: 100ms; }
@keyframes rise { to { opacity: 1; transform: translateY(0); } }
```

Use it for a group seen occasionally, never for a list people scroll every day. Items stay clickable while it plays.

## Hold to confirm

Curve `linear` while held, `--ease-out` on release. Duration 2 s while held, 200 ms on release. Properties `clip-path` on the fill, `transform` on the button. Reduced motion: keep the fill, because it shows how long to hold, and drop the press scale.

```css
.fill { clip-path: inset(0 100% 0 0); transition: clip-path 200ms var(--ease-out); }
.button:active .fill { clip-path: inset(0); transition: clip-path 2s linear; }
.button:active { transform: scale(0.97); }
```

The fill is progress, and progress does not ease. Use it for destructive actions, where one click fires too easily.

## Tab indicator with a color transition

Curve `--ease-in-out`. Duration 250 ms. Properties `clip-path`. Reduced motion: no transition on the clip, so the active tab switches at once.

Duplicate the tab list, style the copy as the active state (background and text color), and clip the copy to the active tab's box. Animate only the clip, for example from `inset(0 60% 0 20%)` to the next tab's insets. Text and background change in step because one layer is revealed, where per-tab color transitions drift apart.

## Scroll reveal

Curve `--ease-in-out`. Duration 600 ms. Properties `clip-path`. Reduced motion: the content fades in with `opacity` over 200 ms on `ease`, with no clip.

Clip from `inset(0 0 100% 0)` to `inset(0)` when the element enters view, through `IntersectionObserver` or Motion's `useInView` with `{ once: true, margin: "-100px" }`. Fire it once. Use it on marketing surfaces only, never on UI people visit daily.

## Drag to dismiss

Curve: a spring, `{ type: "spring", duration: 0.5, bounce: 0.2 }`, for the settle. Duration: the spring's. Properties `transform` on the dragged element. Reduced motion: the element still tracks the finger, and the release settles with `bounce: 0` or dismisses with an opacity fade.

```js
const velocity = Math.abs(dragDistance) / (Date.now() - dragStart);
if (Math.abs(dragDistance) >= DISMISS_DISTANCE || velocity > 0.11) dismiss();
el.style.transform = `translateY(${dragDistance}px)`;
```

Write the transform on the element itself, not through a parent's CSS variable. Apply the capture, damping, and touch rules in [Gestures and drag](SKILL.md#gestures-and-drag).

Track 1:1 from the grab point: store the offset between the pointer and the element's edge at `pointerdown`, so the element never jumps to center under the finger. Keep the last few `pointermove` positions with timestamps, because the release velocity comes from that history, not from one sample. When the user grabs the element mid-settle, start from its live on-screen transform, never from the target.

## Sheet with snap points

Curve: a spring, `{ type: "spring", duration: 0.3, bounce: 0.2 }` after a flick, `bounce: 0` after a slow release. Duration: the spring's. Properties `transform` on the sheet. Reduced motion: the sheet still tracks the finger and lands on the snap point nearest the release, with `bounce: 0`.

Pick the snap point from where the gesture is going, not from where the finger lifted. Project the resting position with exponential decay, then hand the release velocity to the spring so dragging and settling show no seam:

```js
const project = (v, rate = 0.998) => (v / 1000) * rate / (1 - rate); // v in px/s; 0.99 feels snappier
const target = nearestSnapPoint(currentY + project(releaseVelocity));
animate(sheet, { y: target }, { type: "spring", velocity: releaseVelocity, bounce: Math.abs(releaseVelocity) > 500 ? 0.2 : 0 });
```

Let the in-between frames point at the outcome: a sheet heading to full height grows toward the finger, never sideways. Spring 2D motion as separate x and y springs, because one spring on the combined distance desyncs when the axes move at different speeds.

## Masking a crossfade

Curve `ease`. Duration 200 ms. Properties `filter`, `opacity`. Reduced motion: keep it as is, because neither property moves the element.

When two overlapping states still read as two objects after the curve and duration are tuned, blur the change: `filter: blur(2px)` with `opacity: 0.7` while it runs. Keep any blur under 20 px for Safari.

## No-library programmatic motion

Curve `--ease-in-out`, written as `cubic-bezier(0.77, 0, 0.175, 1)`. Duration 1000 ms for a reveal; use the UI band for UI. Properties `clip-path` in this example, or any composite-only property. Reduced motion: check `matchMedia("(prefers-reduced-motion: reduce)").matches` and animate `opacity` instead.

```js
el.animate(
  [{ clipPath: "inset(0 0 100% 0)" }, { clipPath: "inset(0)" }],
  { duration: 1000, easing: "cubic-bezier(0.77, 0, 0.175, 1)", fill: "forwards" }
);
```

WAAPI runs like CSS, can be interrupted, and adds no bundle weight.
