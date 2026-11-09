# qakit: worst-case data checks

Read this file when the change renders data in a UI and a browser driver is present, or when the user asks to try to break a component. Each section names the qakit step it extends. The root `SKILL.md` stays in force; this file adds to it.

These checks put worst-case values on the screen through the browser driver's request mocking, so nothing is written to the repo.

## Scope the feature: map the rendered fields

For each screen in scope, list every value it renders from data, with three columns: the field, its source (the request that returns it, or the server render), and its limit. Find the limit in the validation schema, the database column, the API type, or a `maxLength`. Write `unbounded` when none exists. A frontend limit shorter than the backend one goes in the map too, because a valid row then fails on this screen.

**A direct break ask.** "Try to break this component" has no diff to scope from. Map the named screen instead, and write a plan with one worst-case scenario only: the slug ends in `-worst-case`, and the Summary says the run covered the worst-case checks only.

This is done when every rendered field on every in-scope screen has a source and a limit or `unbounded`.

## Derive the test dimensions: the worst-case catalog

Under **Edge & boundary**, build one worst-case dataset per screen from the catalog below. Pick values from the schema limit first: a field capped at 80 gets an 80-character value. An `unbounded` field gets a long but believable value. Never use random strings. Spread the failures across the first rows, because those rows are on screen. Use `example.com` or `.test` domains for every email and URL.

**Names.** `Aleksandra Wiśniewska-Kowalczyk` (long, hyphen, diacritics) · `Christopher Alexander Montgomery III` (naive initials give `CI`) · `J` (one letter) · `Đặng Thị Ngọc Hân` (stacked diacritics, clipped by a tight `line-height`) · `王秀英` (CJK, no spaces) · `نور الهدى عبد الرحمن` (RTL, needs `dir="auto"`) · `🦊 Fox` (`.charAt(0)` returns half a surrogate pair) · `  Sam   Lee ` (extra spaces) · `dana` (initials still uppercase).

**Emails and identifiers.** `bartholomew.fitzgerald@northwind-industries-holdings.example.com` (unbroken, pushes siblings off the row) · `first.last+billing-notifications@example.com` (plus sign) · `a@b.co` (layout looks empty) · a long URL with a query string (end truncation hides the part that differs) · `9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f` (UUID) · `IMG_20250914_183022_HDR_portrait_edited_edited.HEIC` (file name, unbroken).

**Labels from data.** `Senior Product Design Engineer, Platform Infrastructure` (three lines in a secondary slot) · `Benachrichtigungseinstellungen` (30 characters, no space) · a long status badge such as `Invitation expired 12 days ago` · twelve tags on one item (needs a `+8` overflow) · one tag wider than its container · `<script>alert(1)</script>` and `&amp;` (must render as literal text) · an embedded newline · a 2,000-character description · an empty or whitespace-only title.

**Numbers and money.** `0` (zero state, division by zero in a percentage) · `1` (plural form) · `1284` (needs `1,284`) · `1000000` (badge width) · `12345678.9` as currency (totals column overflow) · `-42.5` (sign and colour logic) · `142%` (meter past its bound) · `0.1 + 0.2` rendered raw.

**Collections.** 0 items (does an empty state exist) · 1 item (a grid with one card, "1 of 1") · exactly the page size and the page size plus 1 (off-by-one in "Showing 40 of 40", an empty page 2) · a total count of 1,284 on a first page of 40 · items with identical names · every enum status in one list.

**Time.** now ("0 seconds ago") · a future date ("-3 days ago") · `1970-01-01` (a zero timestamp shown as a real date) · `2025-12-31T23:30:00-08:00` (a different day in UTC).

**Images and media.** an avatar URL that returns 404 (broken icon, no initials fallback) · a 4000×200 image as an avatar (distortion without `object-fit: cover`) · a 200×4000 image in a card.

**Missing optional fields.** Each optional field set to `null`, and each one left out of the object. Mix filled and missing fields in the same list, so misaligned rows show.

**Severity.** The case takes 🔴 when a control is hidden or unreachable, the screen crashes or goes blank, `undefined`, `null`, or `NaN` shows on screen, or a count is wrong. It takes 🟡 for text clipped with no ellipsis or title, a wrong plural, or a missing empty state. It takes 🟢 for a wrap that reads badly.

This is done when every field in the map has at least one catalog value, and every value names the break it tests.

## Run the automated checks yourself: mock, reload, assert

Run these under **Browser checks**, at each viewport width the root's Scope step chose. Overflow at 375 px is the most common break.

1. **Capture the real shape.** Log in, load the screen once, and record each list or detail request it makes, with its URL pattern and response body. When the dev server returns no rows, build the shape from the API types in the repo.
2. **Build a same-shape body.** Keep every key and type of the real response, and swap in the worst-case values. Mock the first page only, and set the total-count fields to the worst-case count.
3. **Mock reads only.** Mock `GET` requests, and a GraphQL `POST` whose operation is a query. Never mock a write, because the mock would hide a real save. Leave auth and session requests unmocked, and start the mocks after login.
4. **Serve it, then reload.** Use the driver's request mocking, and read its `--help` for the syntax (on `playwright-cli` it is `route <pattern> --body`). Reload the screen so the mock serves the first request.
5. **Assert, per viewport.** Check for horizontal overflow (`scrollWidth > clientWidth` on the page and on each row), text clipped with no ellipsis and no `title`, the plural form at 1, an empty state at 0, the literal text `undefined`, `null`, or `NaN` on screen, and console errors.
6. **Remove the mocks.** Clear every route before the next screen and before the run ends.

**Server-fetched data.** A browser mock cannot reach data the server fetches and renders, such as a Next.js server component or an SSR loader. Seed the worst-case rows on a declared disposable target under the root's disposable-target rules, and reset it after. With no disposable target, write a manual case that names the values to enter.

**Record each break** as one line, with the case tier first:

```markdown
- ❌ 🔴 <page> · <field> = <worst-case value> @ <viewport> via route <pattern> → <what the page showed>; expected <what it should show>; fix: <proposed fix>
```

Record each passed check as a ✅ line with the same page, field, viewport, and route. Propose the fix in the line, and apply none, because qakit writes no code.

This is done when every catalog value in the dataset has a ✅ or ❌ line at each viewport, or a manual case for server-fetched data, and no mock is still active.

Credit: the catalog values follow Emil Kowalski's `break-ui` skill (github.com/emilkowalski/skills, MIT, read at commit `2d22863`), rewritten for this skill.
