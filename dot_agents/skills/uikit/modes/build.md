# Mode `build`: make the UI

### 1. Ground it

Walk [the ladder](../SKILL.md#the-precedence-ladder) and name the rung that matched. Detect the stack from the project's manifest and config rather than assuming, naming the framework, styling system, component library, and whether it's Tailwind v3 or v4, because [that distinction changes what renders](../stack.md). Greenfield or undeclared, default to **Tailwind v4 + shadcn/ui** and say out loud that it's a default. Name whether the surface ships to phones (a responsive app, a PWA, a mobile-first route), because that decides whether [the mobile layer](../SKILL.md#the-mobile-layer) applies.

This step is done when the rung, the stack, whether the surface ships to phones, and every behavior the request specifies are named.

### 2. State the design read

[Five words](../SKILL.md#the-design-read), one line, before any code exists. This step is done when all five words have a value and the signature changes no specified behavior.

### 3. Build

**Compose before you invent.** Use the existing component before writing a styled `div`; extend it before forking it; fork it only when the difference is real and say why. An agent's instinct is to write fresh markup because it's faster than reading what's there, and that instinct is what produces a codebase with four Buttons.

- **Clear [the accessibility floor](../SKILL.md#the-accessibility-floor)** without announcing it. It is a floor, not a feature. On a surface that ships to phones, clear [the mobile layer](../SKILL.md#the-mobile-layer) the same way.
- **Use a maintained primitive for the hard widgets.** Toasts, OTP inputs, command menus, and virtualized lists come from the project's existing library or a maintained package, never hand-rolled, because their focus, keyboard, and edge-case handling is where a fresh build fails.
- **Motion is justified in one sentence or it doesn't ship.** Animate `transform` and `opacity` only, never `transition: all`, never animate layout properties. One orchestrated moment beats scattered effects, and extra animation is itself a tell. **motionkit**, when installed, owns how the motion moves: the curve, the duration, the origin, and the rest.
- **Write the strings as design material.** Follow `DESIGN.md`'s voice rules when it has them. Otherwise: active voice, sentence case, name things by what people control rather than how the system is built. A control says what happens ("Save changes", not "Submit") and keeps the same verb through the whole flow, so a button that says "Publish" produces a toast that says "Published." Errors name the fix, not the failure. An empty screen is an invitation to act.
- **Match complexity to the direction.** Maximalist needs elaborate execution; minimal needs precision in spacing and type. Elegance is executing the chosen direction well, not choosing the smaller one.

This step is done when every specified behavior renders, and every new component names the existing one it reuses or extends, or the reason it is new.

### 4. Pre-flight

Run [self-critique](../SKILL.md#self-critique). It is a critique, not a gate: findings get fixed or get named, and the build is not blocked either way. This step is done when each of the four written checks has a result.

### 5. Hand off

**Called by a build skill** (implementkit, afkkit, or another kit that runs uikit as a step)? Return three items to the caller and stop: the design read verbatim, the changed file paths, and the pre-flight result with anything left unfixed. Skip the three beats below, because the caller owns the next move.

**What changed.** Report the components and pages written or edited, one line each, and the composition decisions (what was reused, what was extended, what was newly written and why).

**Where it landed.** Give the file paths, and the pre-flight result including anything left unfixed.

**Next.** **Repeat the design read verbatim in this hand-off.** It is the only durable record of why the UI looks the way it does, and repeating it here is what carries it into a PR body when this runs inside a pipeline. Then, if the project has no `DESIGN.md`, the crowned next move is **designkit** `init` when installed (otherwise write one by hand), because it derives the system from shipped UI, and there is now shipped UI to derive from. If a `DESIGN.md` already exists, the next move is committing the work with **commitkit** when installed, otherwise `git add` and commit. Changes are left unstaged either way; uikit does not commit. As a runner-up, look at the shipped screen with verifykit `show` when installed, otherwise open the app and look.
