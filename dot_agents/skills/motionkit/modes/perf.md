# motionkit perf mode

`perf` asks whether each frame finishes inside the budget, and why not. The curve and the motion's right to exist are `review`'s. The budget, tiers, and swaps live in [Property cost](../SKILL.md#property-cost).

A fast laptop hides almost every cause here. Judge against a mid-range phone at 120 Hz; "smooth on my machine" is no evidence.

## 1. List what animates

Run [Stack detection](../SKILL.md#stack-detection), then list every animation in the user's scope in one table:

| Element | Driver | Properties | Plays during | Where |
| --- | --- | --- | --- | --- |
| Tab indicator | Motion `layoutId` | layout (width, left) | route change | `Tabs.tsx:31` |

- **Expand every shorthand into what it really animates.** `transition: all` animates every property that changes on that element, so read the state rules and list them. Tailwind `transition` covers colors, shadow, opacity, transform, and filter; `transition-all` covers everything. Motion `x`, `y`, `scale`, and `rotate` animate CSS variables. Motion `layout` and `layoutId` animate size and position.
- **Name the moment it plays**: hover, drag, mount, route change, data load, or hydration.

**Done when** every animation in scope has a row with all five columns filled, and no row reads `all` or a shorthand unexpanded.

## 2. Match the symptom

Match the user's words, or a recording, to a row. Each cause names its fix.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Stutters on open, close, or resize | Layout property animates | Swap to `scale()` or `translate()` |
| Shadow or corner animation is choppy | Paint property animates (`box-shadow`, `border-radius`) | `filter: drop-shadow()`, or a pseudo-element whose `opacity` animates |
| Janks only during navigation or loading | Busy main thread under a JS driver | Move to a CSS transition or WAAPI |
| A hand-made animation drops frames in React | State update per frame | Write to `ref.current.style` or a motion value |
| Gets slower as the list or drawer fills | Cost grows with content: an inherited CSS variable or too many animating nodes | Set `transform` on the moving element; animate fewer nodes |
| Motion `x`/`y` drops frames under load | Animated CSS variable | Animate a full `transform` string |
| Blur transition lags, worst in Safari | Large animated blur | Keep `blur()` under 20 px, or promote a small blurred layer |
| Properties nobody meant to animate move | `transition: all` | Name each property |
| A 1 px shift when the motion starts or ends | Layer promotion mid-flight | `will-change: transform` on that element |

**Done when** each reported symptom points to a row, or the run states that none matches.

## 3. Diagnose down the cause list

Check every animation against these causes, in order of how often each is the culprit. One animation can carry several causes.

1. **Non-composite properties.** Layout properties first, then `box-shadow` and `border-radius`, which repaint every frame and are easy to miss.
2. **A busy main thread.** The motion plays during a route change, a fetch, hydration, or a long task, and a `requestAnimationFrame` loop or a Motion component drives it. Move it to CSS or WAAPI.
3. **A React re-render per frame.** `setState` inside `requestAnimationFrame`, `pointermove`, `scroll`, or a drag handler.
4. **Cost that grows with content.** A parent's CSS variable read by a child's `transform`, or dozens of nodes animating at once.
5. **An animated CSS variable**, set directly or through Motion's shorthands.
6. **Large blur**, any animated `blur()` over 20 px.
7. **`will-change` last**, only after a recording shows the shift or dropped frames that persist once every cause above is cleared.

Code settles most causes; the busy thread and `will-change` need a recording. With a browser driver, capture one per the [Guards](../SKILL.md#guards). Without one, label the finding "needs a recording" and name what to record: the DevTools Performance panel on a mid-range phone over remote debugging. Desktop CPU throttling does not model a weak GPU.

**Done when** every animation in the table has each of the seven causes marked found or clear, and no animation is called smooth on code evidence or on a fast machine.

## 4. Report, then stop

One block per finding, ordered by cost: layout, then paint, then the rest; busy before idle within a tier.

```
**Card hover**: `card.css:12`
Cause: non-composite properties
Before: `transition: all 200ms` (animates `padding` and `box-shadow`)
After: `transition: transform 200ms, opacity 200ms` with `scale(1.02)` and a shadow layer that fades
Evidence: from code
```

Each `before` and `after` quotes real code. When nothing is found, say which causes were checked and which still need a recording.

Then stop. Apply only the named fixes, and only when the user asks.

**Done when** every found cause has a block, the blocks are in cost order, and no file has changed.

## 5. Hand off

**What changed.** Say "nothing changed" after the report. After a fix request, list each applied fix with its cause.

**Where it landed.** Give `file:line` for each finding, or for each edited line after a fix.

**Next.** Before a fix, say "apply the fixes" to apply them. After a fix, record the motion again to confirm the frames. When the frames are fine but the motion still feels wrong, run `motionkit review`.
