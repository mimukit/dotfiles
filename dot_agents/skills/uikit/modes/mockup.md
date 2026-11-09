# Mode `mockup`: show a screen as an image

A mockup is a picture a person looks at to compare or approve a screen before the real build. **The output is an image.** Code appears only when the user asks for code ("as code", "the HTML", "the component"), and that ask is a [`build`](build.md).

Options belong here too. "Show me a few options", "three directions", and "mock up three versions" mean one mockup run with N options, each from a different design read. N is at most 4, because more images shrink until a reader cannot compare them. A request for more gets four, with the cap said in one line.

No code ships from this mode, so the stack layer, the mobile layer, and the accessibility floor do not apply. The catalog and the design read do.

### 1. Ground it

Walk [the ladder](../SKILL.md#the-precedence-ladder) and name the rung that matched. When a `DESIGN.md` exists, read it, because its tokens are the palette, type, spacing, and radii of every option. List every screen the request names, and set the option count. State [the design read](../SKILL.md#the-design-read) once per option, with a different signature in each.

**Done when** the rung, the screen list, the option count, and one design read per option are named, and no two options share a signature.

### 2. Pick the image path

Probe what the session has, in this order:

1. An image-generation tool in the current tool list.
2. A CLI browser driver on `PATH` that writes a screenshot, for example `playwright-cli`.

**Take the generator first.** One word from the user moves a single screen to the render when a driver exists: "exact", "match the real layout", or "use the real copy". Two generators in the list means ask once which to use. A non-interactive run takes the first.

With neither path, say what is missing, offer to write the HTML file and give its path, then stop. Raw HTML is never the mockup, and a path to it is a fallback the user chose.

**Done when** one line names the path and the reason, or the fallback is stated and the run has stopped.

### 3. Produce it

**Generator path.** Write one prompt per option. Each carries the design read, the screen's real copy, the `DESIGN.md` tokens as values (hex codes, face names, radii), and the surface. Show the options labeled A to D in one reply.

**Render path.** Write one throwaway HTML file outside the repo tree, with all options in a row on one page. Edit that file for every change. Screenshot it once, and show the PNG by path when the tool accepts a path.

Both paths follow the [catalog](../SKILL.md#the-anti-slop-catalog) rule on content: real copy, or the real empty state, never invented names, metrics, or logos.

**Collect every fix before you resend.** A resend of the whole image for one small fix is the expensive path. Several screens or four options is a large run. Run it in a subagent that returns the image paths and a one-line summary, so the pixels stay out of this context.

**Done when** every option exists as an image and the user has seen all of them in one reply.

### 4. Check

Look at each option against [the catalog](../SKILL.md#the-anti-slop-catalog), filtered to the declared surface. Check that each option has exactly one signature. Take one decoration out of each option that has one to spare. Report what you fixed and what you leave, with a reason. Never claim a check that did not happen: an image you could not open is unchecked, and you say so.

**Done when** each option has a catalog result and a signature result.

### 5. Hand off

**Called by a build skill** (implementkit, afkkit, or another kit that runs uikit as a step)? Return the image paths and the design read of each option, then stop.

**What changed.** List the image files created. Name the throwaway HTML file when the render path made one. Say that no repository source changed.

**Where it landed.** Give the image paths, and the design read of each option verbatim.

**Next.** Crown one move: the user picks an option or sends every fix at once. After the user approves an option, the next move is [`build`](build.md) with that option's design read, built from scratch. The mockup is never promoted to production code. A plan that settles how the screen looks records the approval as a Design decisions row with the date, so name that as the runner-up when a plan exists. Delete the throwaway HTML file once the user approves.
