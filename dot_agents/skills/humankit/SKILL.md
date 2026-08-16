---
name: humankit
description: >-
  Strip the tells of AI-generated writing from prose so it reads like a person wrote it. Use when asked to humanize text, remove AI-isms, make writing sound less like ChatGPT, edit out "AI slop," or review a draft for robotic phrasing — covers em-dash overuse, rule-of-three cadence, promotional puffery, filler, hedging, and the AI vocabulary words.
license: MIT
allowed-tools: Read, Edit, Write
metadata:
  internal: false
---

# humankit

Rewrite text so it stops sounding like a language model produced it. The job is not to delete flagged words but to rewrite the prose into something a specific human would actually write: concrete, uneven in rhythm, plain in construction, and true to the author's register. Keep every claim the original makes, but not its shape: compress the dull stretches, dwell where a person would, merge or split paragraphs freely. Uniform structure is itself a tell, so mirroring the original's paragraph count preserves the thing you came to remove. When coverage and structure pull against each other, coverage wins — a five-paragraph source may land in four, but it never becomes a summary.

**Never invent facts.** The rewrite carries no fact, name, number, date, quote, or citation that isn't in the source or supplied by the user. This is the failure mode the rest of the skill invites: told to replace *nestled in the heart of a vibrant region* with something concrete, the tempting move is to supply the concrete detail yourself. Concreteness comes from the source or it doesn't come at all — where the source offers nothing specific, cut to the plain version and leave it plain. Opinions, reactions, and mixed feelings are voice rather than fact; add those where the register allows, but never a factual claim to make the prose feel human. Fiction is the exception, where inventing detail is the job. This governs everything else.

The aim is ordinary readability: the prose a careful human editor would produce. This is copy-editing to make writing read well, not a way to disguise machine-written work as human where honesty is required — academic submissions, disclosure-bound, or attributed writing. Edit for the reader, not to game any automated check.

## When this fires

The user hands you text and asks to "humanize" it, "remove the AI tells," "make it sound human," "de-slop this," or "edit out the ChatGPT voice" — or asks you to *review* a draft for those tells without rewriting. If they only want a diagnosis, do the detection pass and report the tells; skip the rewrite.

How you were reached decides what you deliver:

- **Text in the conversation** — the default. Run the whole loop and deliver the three parts described under [Hand off](#hand-off).
- **A file path** — read it, run the loop internally, and write the final rewrite back. Humanize the prose only: leave code blocks, frontmatter, tables, data, and link targets exactly as they are. Report a summary and the path rather than pasting the rewrite into chat.
- **Another skill or agent calling you** as one step of a larger job (a PR body, a commit message, a docs pass) — run the loop internally and output the final text alone. No draft, no audit bullets, no summary. The caller wants prose, not ceremony.

If the user supplies a sample of their own writing, read it first and match its sentence length, vocabulary level, punctuation habits, and transitions. Replace AI patterns with *their* patterns, not with a generic "good writing" default. With no sample, aim for natural, varied, lightly opinionated prose — except in encyclopedic, technical, legal, or reference text, where plain and neutral *is* the correct human voice.

A sample outranks every style rule here, including [the em-dash rule](#the-em-dash-rule): if the author uses em dashes, keep them at roughly the sample's frequency. Matching the author beats scrubbing the tell.

## The tells

Scan for these. They matter in **clusters**, not in isolation — one em dash or one "however" proves nothing; em dashes plus rule-of-three plus "vibrant tapestry" plus a "Conclusion" section is a confession.

**Inflated significance.** Puffing arbitrary facts into history: *stands as a testament to, marks a pivotal moment, reflects a broader, plays a crucial role, setting the stage for, evolving landscape, leaves an indelible mark.* Cut the editorializing; state the fact.

**Promotional tone.** Travel-brochure adjectives: *nestled, in the heart of, vibrant, rich cultural heritage, breathtaking, boasts a, must-visit, renowned, stunning.* Replace with what the source says the thing is or does. When the source offers nothing concrete, the bare fact is the rewrite; do not supply a market, a founding date, or an 18th-century church to fill the hole.

**Superficial -ing tails.** Present-participle clauses bolted on for fake depth: *…, highlighting its importance,* *…, reflecting the community's connection,* *…, ensuring seamless integration.* Delete or fold the real content into a plain clause.

**AI vocabulary.** Words that spiked after 2023 and tend to co-occur: *delve, crucial, pivotal, underscore, showcase, tapestry, testament, intricate, enduring, foster, garner, interplay, landscape (abstract), leverage, seamless, robust, realm.* Swap for ordinary words.

**Copula avoidance.** Dodging *is/are*: *serves as, functions as, represents, boasts, features.* Prefer "X is Y."

**Rule of three.** Forcing ideas into triads to sound complete: *innovation, inspiration, and industry insights.* Break the rhythm; keep only the items that carry weight.

**Negative parallelism.** *Not only… but also…,* *It's not just X, it's Y,* and clipped tailing negations tacked on as fragments: *…, no guessing,* *…, no wasted motion.* Write the real clause instead.

**Filler and hedging.** *In order to* → *to*; *due to the fact that* → *because*; *at this point in time* → *now*; *has the ability to* → *can*; *it is important to note that.* Strip the padding. Cut stacked qualifiers: *could potentially possibly* → *may.*

**Signposting and chatbot residue.** *Let's dive in, here's what you need to know, without further ado,* and pasted correspondence: *I hope this helps, Certainly!, You're absolutely right!, Would you like me to…, let me know.* Do the thing instead of announcing it; delete the chat framing.

**Persuasive-authority and aphorism formulas.** *The real question is, at its core, what really matters, fundamentally;* and *X is the language of Y, X becomes a trap.* These dress an ordinary claim in ceremony. Replace with the concrete claim underneath.

**Vague attribution.** *Experts argue, observers have noted, industry reports suggest* with no source named. Name the source or cut the claim. Watch too for knowledge-cutoff disclaimers (*as of my last update, while specific details are limited*) and speculative gap-fill (*likely grew up, it is believed that, maintains a low profile*) — say what isn't known, don't invent plausible filler.

**Formatting tells.** Mechanical **boldface** on key phrases; inline-header bullet lists (`- **Performance:** …`); Title Case In Every Heading; decorative emojis; curly quotes where straight ones belong; generic upbeat conclusions (*the future looks bright, exciting times lie ahead*).

## The em-dash rule

The finished rewrite contains **no em dashes (—)** and uses **no en dashes (–) as sentence punctuation**. Replace those marks, in rough order of preference, with a period, comma, colon, parentheses, or a restructured sentence. Preserve legitimate numeric/date/page ranges by using a hyphen or writing "to" (`1914-1918`, `pp. 10 to 12`). Catch spaced em dashes (` — `) and double hyphens (` -- `) used the same way. Before delivering, search the draft for `—` and `–`; any remaining en dash must be a legitimate range, and any em dash means the rewrite is not done. One exception: a user-supplied writing sample that uses em dashes overrides this rule, and then the mark is matched to the sample's frequency rather than banned.

## What not to flag

Clean human writing trips several of these on its own. Do not gut legitimate prose:

- Polish, formal vocabulary, or consistent style — professionals and edited writers exist.
- A single em dash, one *however*, one clipped emphatic sentence, curly quotes alone — editors and word processors produce all of these.
- Bland or dry prose without the *specific* tells above — dry is not the same as AI.
- Quoted text, titles, proper names, or a phrase being discussed rather than used — never rewrite inside those.

Lean toward leaving prose alone when you see hard-to-fake specifics (a real address, an odd quote), mixed or unresolved feelings, era-bound slang, genuine asides or self-corrections, and real variety in sentence length. Those are the fingerprints of a person.

## Process

1. Read the input and mark every instance of the tells above.
2. Write a **draft rewrite**: read it aloud in your head, vary sentence length, prefer concrete detail and plain constructions (*is/are/has*), hold the original's register and coverage.
3. Ask two questions: *what still makes this read as AI-generated?* and *does the draft state any fact, name, number, date, quote, or citation that isn't in the source?* Answer both in a few blunt bullets. A fabrication is a defect even when it reads more human than the vague original it replaced.
4. Revise into a **final rewrite** that fixes both, carrying no em or en dashes.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

This is the hand-off for text pasted into the conversation. Called by another skill or agent, none of it applies: deliver the final text alone and stop. Working from a file, deliver the summary and the path, not the rewrite itself.

**What changed** — deliver, in order: the **final rewrite** (the main artifact), a short **"what still read as AI"** note listing the tells you caught when you asked *what still reads as AI-generated*, and a one-line **summary of changes**. Say so plainly if the audit turned up a fabrication you had to pull back out. If the user asked only for a review, skip the rewrite and report the located tells with line references instead.

**Where it landed** — when a writable filesystem is available and the source came from a file, write the rewrite back (or beside it), leaving code blocks, frontmatter, tables, data, and link targets untouched, and report the path; otherwise print the rewrite in a fenced code block so it copies cleanly.

**Next** — name one move and stop. Rewritten a file in a repo? The change is uncommitted prose: offer to commit it (**commitkit** when installed, otherwise a plain commit). Reviewed rather than rewrote? The move is to apply the tells you listed — re-run humankit on the draft once they've decided which to take. Rewrote text that came from the chat rather than a file? There's nothing to route to; say the draft is theirs to paste back and stop rather than inventing a next step.

## Reference

The pattern catalog derives from [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), maintained by WikiProject AI Cleanup.
