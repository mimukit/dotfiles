# motionkit trigger cases

Run each prompt in a fresh session and record whether motionkit fired, and which mode. A near-miss that fires means the description is too broad; a should-fire case that stays quiet means a branch has no trigger.

## Should fire

**build**

- "Animate this dropdown so it opens from the button"
- "Add a press effect to the primary buttons"
- "Make the settings drawer slide in from the right"

**review**

- "This modal animation feels off, can you check it?"
- "Review the toast animation in this diff"

**review, sweep scale**

- "Audit the animations in this app"
- "What should animate in the onboarding flow?"
- "Make the app feel alive"

**perf**

- "This sidebar transition is janky on my phone"
- "The drawer stutters once it holds more than 20 items"
- "Fix the jank in the tab indicator during navigation"

**lookup**

- "What's it called when an element slides in and settles?"
- "What's the name for the iOS thing where scrolling resists past the edge?"

## Should not fire

**Near build**

- "Build the pricing page" (page build: uikit)
- "Animate this screen in React Native with Reanimated" (native: out of scope)

**Near review**

- "Review my changes before I open the PR" (code review: reviewkit)
- "This dashboard looks AI-generated, fix it" (visual taste: uikit)

**Near review, sweep scale**

- "Audit our UI for slop" (UI audit: uikit)
- "Check the agent's work on the auth refactor" (code review: reviewkit)

**Near perf**

- "This page got slower after the upgrade" (no motion angle: debugkit)
- "The API call stutters under load" (backend latency: debugkit)

**Near lookup**

- "What's it called when a function calls itself?" (not motion)
- "Why is this test flaky?" (debugging: debugkit)
