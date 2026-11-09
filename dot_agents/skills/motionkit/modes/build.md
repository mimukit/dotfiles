# Mode `build`: make one animation

Build turns one request for motion into code that passes [the motion standard](../SKILL.md#the-motion-standard) on the first review. Two failures matter, and the first is worse: motion on something that should not move, and the right motion built from the wrong ingredients.

Run the steps in order; the first two decide whether any later step runs. At each choice, make the call, give the reason in one line, and write the code. Offer one answer, never a menu. Every curve, duration, and spring comes from the standard or from the project's tokens, never from memory.

### 1. Gate the request

Place the motion on a tier of [The frequency gate](../SKILL.md#the-frequency-gate), and apply its keyboard and function rules. A request that fails the gate gets the instant state change, or a static affordance, plus a one-line reason. Zero lines of motion code is a successful run here, so go straight to [Hand off](#9-hand-off).

**Done when** the tier is named and the request either passes or has shipped as an instant change with its reason.

### 2. Name the purpose

Name one purpose from [Purpose](../SKILL.md#purpose). When no word fits, or the only reason is that it looks good on a surface people see often, stop the same way a failed gate stops.

**Done when** one purpose word is stated, or the run has stopped with its reason.

### 3. Pick the cheapest tool

Read the drivers and tokens that [Stack detection](../SKILL.md#stack-detection) found, then take the first row that fits:

| The motion needs | Tool |
| --- | --- |
| A hover, press, color, or class or attribute toggle | CSS transition |
| An entrance on mount with no JavaScript state | CSS transition with `@starting-style` |
| Fixed motion that stays smooth while the page loads | CSS animation |
| Programmatic control with no dependency | WAAPI, `element.animate()` |
| Springs, layout animation, exit after unmount, gesture values | Motion |

Prefer a library the project already ships, and never install one for a fade. When the ask is a whole component (dropdown, toast, drawer, command menu) and the project has a headless component library, animate its primitive, because a hand-built `<div>` loses focus handling and keyboard support.

**Done when** one tool is chosen with a one-line reason, and any new dependency is justified by a row that no installed driver covers.

### 4. Start from a recipe

Component in the recipe list (press, popover or menu, tooltip, modal, drawer, toast, accordion, stagger, hold to confirm, tab indicator, scroll reveal, drag to dismiss, sheet with snap points, crossfade, no-library motion) → read [../recipes.md](../recipes.md), then follow it. Adapt it to the project's tokens and markup.

**Done when** the matching recipe is read, or no recipe matches and that is stated.

### 5. Choose the properties

Apply [Property cost](../SKILL.md#property-cost), [Physicality and origin](../SKILL.md#physicality-and-origin), and [Clip-path and transforms](../SKILL.md#clip-path-and-transforms). Name every transitioned property, start an entrance from almost its final state, and anchor a trigger-born surface at its trigger.

**Done when** every animated property is listed by name, and each one is `transform`, `opacity`, `clip-path`, or carries a stated reason.

### 6. Set the curve and duration, or a spring

Take the curve from [Easing](../SKILL.md#easing) and the duration from its band in [Duration](../SKILL.md#duration). Use a spring per [Springs](../SKILL.md#springs) when the motion follows a gesture or can reverse midway. Write each value through the project's token, and add a missing token beside the existing ones in their naming scheme.

**Done when** every curve, duration, and spring value in the diff traces to a token or to a row of the standard, and no new parallel token set exists.

### 7. Handle interruption and exit

Apply [Interruptibility](../SKILL.md#interruptibility) and [Asymmetric timing](../SKILL.md#asymmetric-timing). Motion a user can fire twice in a second uses a transition or a spring. Every surface that enters has a defined exit, along the same path and no slower than the entrance.

**Done when** each animated element has an exit, and none that can retrigger runs on keyframes.

### 8. Ship reduced motion and pointer gating

Apply [Reduced motion and pointer gating](../SKILL.md#reduced-motion-and-pointer-gating) in the same change as the animation, never as a follow-up. Keep the opacity and color that help a person follow the change, and drop the movement.

**Done when** the diff holds a reduced-motion variant for every moving property and a fine-pointer gate around every hover motion.

### 9. Hand off

**What changed.** List each file edited and each token added. When the gate or the purpose stopped the run, write "no motion code, because <reason>", and name any instant state change you wrote. Give the ingredients in one line each: tier and purpose, tool, properties, curve, and duration or spring.

**Where it landed.** Give the path and line of each animation and token.

**Next.** Watch the motion at a slow speed in a real browser. Use **verifykit** when it is installed. Otherwise open the page, and slow it in the DevTools animation panel. Name any value that only feel can settle, such as a spring's bounce. When the run wrote no code, there is no next step.
