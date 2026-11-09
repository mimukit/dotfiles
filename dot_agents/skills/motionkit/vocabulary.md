# motionkit vocabulary

The lookup branch matches the description to a term here and answers with the term, its definition, and the closest related term.

When no term fits, give the nearest one and call it approximate.

## Entrances and exits

- **Fade in, fade out**: opacity alone carries the appearance or the removal.
- **Slide in**: the element travels in from an edge or from off screen.
- **Scale in**: the element grows to full size as it appears, usually with a fade.
- **Pop in**: a scale in that overshoots a little and settles.
- **Reveal**: a clip-path or mask uncovers the content gradually.

## Sequencing and timing

- **Keyframes**: fixed points in an animation; the browser fills the frames between.
- **Stagger**: each item in a group starts a little after the one before.
- **Orchestration**: several animations timed to read as one motion.
- **Fill mode**: whether the first or last frame holds outside the run.

## Movement and transforms

- **Translate, scale, rotate**: the three basic transforms: move, resize, spin.

- **3D tilt, flip**: a `rotateX()` or `rotateY()` turn that adds depth.
- **Transform origin**: the anchor point a scale or rotation uses.
- **Origin-aware animation**: an element grows from its trigger, not its own center.

## State transitions

- **Crossfade**: one element fades out while another fades in at the same spot.
- **Morph**: one shape turns smoothly into another.
- **Shared element transition**: one element travels and reshapes between two places.
- **Layout animation**: a change in size or position animates instead of jumping.
- **Accordion, collapse**: a section animates its height to open or close.
- **Direction-aware transition**: content moves one way forward and the other way back.

## Scroll

- **Scroll reveal**: elements fade or slide in as they enter the viewport.
- **Scroll-driven animation**: progress follows the scroll position directly.
- **Parallax**: layers scroll at different speeds to suggest depth.
- **View transition**: the browser animates between two DOM states or pages.

## Feedback and interaction

- **Hover effect**: a visual change while the pointer is over an element.
- **Press feedback**: a small scale down on press, so the control feels physical.
- **Hold to confirm**: a fill that completes while the user holds the control.
- **Drag**: the user moves the element directly, often with momentum on release.
- **Drag to reorder**: the user drags list items, and the others move aside.
- **Swipe to dismiss**: the user drags an element off screen to close it.
- **Rubber-banding**: growing resistance past an edge, then a return to the edge.
- **Shake**: a quick side-to-side jitter that signals an error.
- **Ripple**: a circle that spreads from the tap point.

## Easing

- **Ease-out**: fast start, slow finish; the default for UI.
- **Ease-in**: slow start, fast finish; it makes UI feel late.
- **Ease-in-out**: slow, fast, slow; for movement on screen.
- **Linear**: constant speed; for spinners, marquees, and progress.
- **Cubic-bezier**: a custom curve set by four control values.
- **Asymmetric easing**: a curve that speeds up and slows down at different rates.

## Springs

- **Spring**: motion set by stiffness, damping, and mass, not by a duration.
- **Stiffness**: the pull toward the target; higher is snappier.
- **Damping**: the resistance that settles the spring; lower bounces more.
- **Bounce**: the overshoot before the spring settles.
- **Perceptual duration**: the time a spring looks finished.
- **Momentum**: velocity that carries on after a release.
- **Interruptible animation**: motion that retargets mid-flight instead of finishing first.

## Looping and ambient

- **Loop**: an animation that repeats a set number of times or forever.
- **Alternate, yoyo**: a loop that plays forward, then in reverse.
- **Marquee**: content that scrolls on in a continuous loop.
- **Pulse**: a gentle repeated change of scale or opacity that draws the eye.
- **Float**: a slow up-and-down drift.

## Polish

- **Blur**: a filter that softens an element or hides a crossfade seam.
- **Clip-path**: a shape that clips an element, for reveals and sliders.
- **Mask**: like clip-path, but with soft or gradient edges.
- **Before and after slider**: a draggable divider between two stacked images.
- **Text morph**: changed text animates character by character.
- **Skeleton, shimmer**: a loading placeholder with a moving sheen.
- **Number ticker**: digits that roll or count to a value.
- **Tabular numbers**: fixed-width digits, so a changing number does not shift.

## Performance

See [Property cost](SKILL.md#property-cost).

- **Frame rate**: frames drawn per second; 60 is the floor, 120 on newer screens.
- **Jank**: visible stutter from frames that miss their deadline.
- **Compositing**: the GPU moves or fades a layer with no new layout or paint.
- **Hardware acceleration**: an animation that runs off the main thread.
- **will-change**: a CSS hint that promotes an element to its own layer early.
- **Layout thrashing**: forced layout every frame, from animated size or position.

## Principles

- **Purposeful animation**: motion that orients or confirms, not decoration.
- **Anticipation**: a small wind-up opposite to the coming move.
- **Follow-through**: parts settle a little after the main motion stops.
- **Perceived performance**: motion that makes the interface feel faster.
- **Frequency of use**: the more often seen, the shorter and quieter the motion.
- **Spatial consistency**: an element keeps its identity and place across states.
- **Reduced motion**: the user's setting for fewer, gentler effects.
