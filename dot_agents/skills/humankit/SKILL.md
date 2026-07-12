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

Rewrite text so it stops sounding like a language model produced it. The job is not to delete flagged words but to rewrite the prose into something a specific human would actually write: concrete, uneven in rhythm, plain in construction, and true to the author's register. Cover everything the original covers — a five-paragraph source becomes a five-paragraph rewrite, not a summary.

## When this fires

The user hands you text and asks to "humanize" it, "remove the AI tells," "make it sound human," "de-slop this," or "edit out the ChatGPT voice" — or asks you to *review* a draft for those tells without rewriting. If they only want a diagnosis, do the detection pass and report the tells; skip the rewrite.

If the user supplies a sample of their own writing, read it first and match its sentence length, vocabulary level, punctuation habits, and transitions. Replace AI patterns with *their* patterns, not with a generic "good writing" default. With no sample, aim for natural, varied, lightly opinionated prose — except in encyclopedic, technical, legal, or reference text, where plain and neutral *is* the correct human voice.

## The tells

Scan for these. They matter in **clusters**, not in isolation — one em dash or one "however" proves nothing; em dashes plus rule-of-three plus "vibrant tapestry" plus a "Conclusion" section is a confession.

**Inflated significance.** Puffing arbitrary facts into history: *stands as a testament to, marks a pivotal moment, reflects a broader, plays a crucial role, setting the stage for, evolving landscape, leaves an indelible mark.* Cut the editorializing; state the fact.

**Promotional tone.** Travel-brochure adjectives: *nestled, in the heart of, vibrant, rich cultural heritage, breathtaking, boasts a, must-visit, renowned, stunning.* Replace with what the thing concretely is or does.

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

The finished rewrite contains **no em dashes (—) and no en dashes (–)**. This is the single most reliable AI tell, so treat it as a hard constraint, not a preference. Replace each one, in rough order of preference: a period, a comma, a colon, parentheses, or a restructured sentence. Catch spaced em dashes (` — `) and double hyphens (` -- `) used the same way. Before delivering, search the draft for `—` and `–`; any hit means it isn't done.

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
3. Ask yourself: *what still makes this read as AI-generated?* Answer in a few blunt bullets.
4. Revise into a **final rewrite** that fixes those, carrying no em or en dashes.

## Output

Deliver, in order: the **final rewrite** (the main artifact), a short **"what still read as AI"** note listing the tells you caught in step 3, and a one-line **summary of changes**. When a writable filesystem is available and the source came from a file, write the rewrite back (or beside it) and report the path; otherwise print the rewrite in a fenced code block so it copies cleanly. If the user asked only for a review, skip the rewrite and report the located tells with line references instead.

## Reference

The pattern catalog derives from [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), maintained by WikiProject AI Cleanup.
