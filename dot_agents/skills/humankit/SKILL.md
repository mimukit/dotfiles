---
name: humankit
description: >-
  Strip the tells of AI-generated writing from prose so it reads like a person wrote it. Use when asked to humanize text, remove AI-isms, make writing sound less like ChatGPT, edit out "AI slop," or review a draft for robotic phrasing without rewriting it. Covers em-dash overuse, puffery, filler, and the AI vocabulary words.
license: MIT
allowed-tools: Read, Edit, Write
metadata:
  internal: false
---

# humankit

Rewrite text so it stops sounding like a language model produced it. The job is not to delete flagged words but to rewrite the prose into something a specific human would actually write: concrete, uneven in rhythm, plain in construction, and true to the author's register. Keep every claim the original makes, but not its shape: compress the dull stretches, dwell where a person would, merge or split paragraphs freely. Uniform structure is itself a tell, so mirroring the original's paragraph count preserves the thing you came to remove. When coverage and structure pull against each other, coverage wins. A five-paragraph source may land in four, but it never becomes a summary.

**Never invent facts.** The rewrite carries no fact, name, number, date, quote, or citation that isn't in the source or supplied by the user. This is the failure mode the rest of the skill invites: told to replace *nestled in the heart of a vibrant region* with something concrete, the tempting move is to supply the concrete detail yourself. Concreteness comes from the source or it doesn't come at all. Where the source offers nothing specific, cut to the plain version and leave it plain. Opinions, reactions, and mixed feelings are voice rather than fact; add those where the register allows, but never a factual claim to make the prose feel human. Fiction is the exception, where inventing detail is the job. This governs everything else.

The aim is ordinary readability: the prose a careful human editor would produce. This is copy-editing to make writing read well, not a way to disguise machine-written work as human where honesty is required, as in academic submissions, disclosure-bound, or attributed writing. Edit for the reader, not to game any automated check.

## When this fires

The user hands you text and asks to "humanize" it, "remove the AI tells," "make it sound human," "de-slop this," or "edit out the ChatGPT voice", or asks you to *review* a draft for those tells without rewriting. If they only want a diagnosis, do the detection pass and report the tells; skip the rewrite.

**Prose for a person, not instructions for a model.** A `SKILL.md`, an agent instruction file (`CLAUDE.md`, an `AGENTS`-style guide, `.cursorrules`), a system prompt, a rules file: every tell below is a lever in that text. A metaphor noun the document defines and reuses anchors a region of behavior in one token, boldface marks the load-bearing rule among the ones that aren't, and a formula repeated verbatim is what makes the behavior repeat. Say the file is out of scope and name the pass that owns it (**promptkit** for a prompt, **skillkit** for a skill, when either is installed) rather than rewriting it. Documentation, a README, release notes, a PR body, and UI copy stay in scope, because a person reads those.

**Procedural text takes the subtraction only.** A runbook, QA steps, a handoff, install instructions: run the tells and [the two cut tests](#two-cut-tests), then skip [Removing tells is half the job](#removing-tells-is-half-the-job). Uniform short sentences and a repeated sentence shape are the correct register there, not a tell to remove.

How you were reached decides what you deliver:

- **Text in the conversation.** This is the default. Run the whole loop and deliver the three parts described under [Hand off](#hand-off).
- **A file path.** Read it, run the loop internally, and write the final rewrite back. Humanize the prose only: leave code blocks, frontmatter, tables, data, and link targets exactly as they are. Report a summary and the path rather than pasting the rewrite into chat.
- **Another skill or agent calling you** as one step of a larger job (a PR body, a commit message, a docs pass). Run the loop internally and output the final text alone. No draft, no audit bullets, no summary. The caller wants prose, not ceremony.

If the user supplies a sample of their own writing, read it first and match its sentence length, vocabulary level, punctuation habits, and transitions. Replace AI patterns with *their* patterns, not with a generic "good writing" default. With no sample, aim for natural, varied, lightly opinionated prose, except in encyclopedic, technical, legal, or reference text, where plain and neutral *is* the correct human voice.

A sample outranks every style rule here, including [the em-dash rule](#the-em-dash-rule): if the author uses em dashes, keep them at roughly the sample's frequency. Matching the author beats scrubbing the tell.

## The tells

Scan for these. They matter in **clusters**, not in isolation. One em dash or one "however" proves nothing; em dashes plus rule-of-three plus "vibrant tapestry" plus a "Conclusion" section is a confession.

**Inflated significance.** Puffing arbitrary facts into history: *stands as a testament to, marks a pivotal moment, reflects a broader, plays a crucial role, setting the stage for, evolving landscape, leaves an indelible mark.* Cut the editorializing; state the fact.

**Promotional tone.** Travel-brochure adjectives: *nestled, in the heart of, vibrant, rich cultural heritage, breathtaking, boasts a, must-visit, renowned, stunning.* Replace with what the source says the thing is or does. When the source offers nothing concrete, the bare fact is the rewrite; do not supply a market, a founding date, or an 18th-century church to fill the hole.

**Superficial -ing tails.** Present-participle clauses bolted on for fake depth: *…, highlighting its importance,* *…, reflecting the community's connection,* *…, ensuring seamless integration.* Delete or fold the real content into a plain clause.

**AI vocabulary.** Words that spiked after 2023 and tend to co-occur: *delve, crucial, pivotal, underscore, showcase, tapestry, testament, intricate, enduring, foster, garner, interplay, landscape (abstract), leverage, seamless, robust, realm.* Swap for ordinary words.

**Abstract metaphor nouns.** Words that sound technical and carry less than a plain one would: *substrate, wedge, vector, locus, nexus, vantage, primitive (as a noun), harness, surface (as in "API surface"), bedrock, scaffolding, modality, paradigm, flywheel, north star, endgame, ratchet, gold-plating, evacuate (for moving code).* Reach for the concrete word: *substrate* → *base*, *vector* → *way*, *gold-plating* → *more than the job needs*, *evacuate* → *move out*. The test is use, not the word. A term the text defines and then reuses for the same thing is doing work and stays; a term dropped in once for texture is decoration and goes.

**Elevated synonyms.** *Utilize* → *use*, *facilitate* → *help*, *numerous* → *many*, *prior to* → *before*, *in the event that* → *if*. The fancier synonym is rarely the clearer one.

**Copula avoidance.** Dodging *is/are*: *serves as, functions as, represents, boasts, features.* Prefer "X is Y."

**Passive voice and propped-up verbs.** *Queries are validated* hides who does it; write *the compiler validates queries.* Passive is right only when the actor is unknown or genuinely doesn't matter. An adverb holding up a weak verb means the verb is wrong: *runs quickly* → *is fast*, or the measured number; *significantly improves* → the delta itself.

**Rule of three.** Forcing ideas into triads to sound complete: *innovation, inspiration, and industry insights.* Break the rhythm; keep only the items that carry weight.

**Synonym cycling.** Rotating through *protagonist, main character, central figure, hero* in one passage to avoid repeating a word. Pick one term and repeat it.

**False ranges.** *From X to Y* where X and Y sit on no shared scale: *from onboarding to enterprise security.* List the items instead.

**Negative parallelism.** *Not only… but also…,* *It's not just X, it's Y,* and clipped tailing negations tacked on as fragments: *…, no guessing,* *…, no wasted motion.* Write the real clause instead.

**Filler and hedging.** *In order to* → *to*; *due to the fact that* → *because*; *at this point in time* → *now*; *has the ability to* → *can*; *it is important to note that.* Strip the padding. Cut stacked qualifiers: *could potentially possibly* → *may.*

**Signposting and chatbot residue.** *Let's dive in, here's what you need to know, without further ado,* and pasted correspondence: *I hope this helps, Certainly!, You're absolutely right!, Would you like me to…, let me know.* Do the thing instead of announcing it; delete the chat framing.

**Persuasive-authority and aphorism formulas.** *The real question is, at its core, what really matters, fundamentally;* and *X is the language of Y, X becomes a trap.* These dress an ordinary claim in ceremony. Replace with the concrete claim underneath.

**Vague attribution.** *Experts argue, observers have noted, industry reports suggest* with no source named. Name the source or cut the claim. Watch too for knowledge-cutoff disclaimers (*as of my last update, while specific details are limited*) and speculative gap-fill (*likely grew up, it is believed that, maintains a low profile*). Say what isn't known, don't invent plausible filler.

**Colon as a connector.** A colon earns its place before a list or an example. Welded into the middle of a sentence it implies a relationship the clause never establishes: *If you're coming from traditional automation: instead of registering handlers, you describe conditions.* Rewrite so the point stands without the framing.

**Formatting tells.** Mechanical **boldface** on key phrases; inline-header bullet lists (`- **Performance:** …`); Title Case In Every Heading; decorative emojis; curly quotes where straight ones belong; generic upbeat conclusions (*the future looks bright, exciting times lie ahead*).

## Two cut tests

The catalog above names patterns. These two judge a sentence that trips none of them and still reads as machine-written. Both are falsifiable, and both end in a deletion.

**Does it name a mechanism, or a feeling?** *The database stays close at hand,* *SQL you can read,* *types that follow your schema* all describe a sensation the reader is supposed to have. The fix names what actually happens: *`.toSQL()` returns the exact string sent to the database,* *a column rename fails the build.* Ask what the sentence tells the reader to do or know, then write that. If it can't be restated as a concrete instruction, fact, or number, cut it. Where the source supplies no mechanism, cutting is the only move available: never invent one to pass this test.

**Could it appear unchanged in another project's documentation?** Then it says nothing about this project, and it goes.

## The em-dash rule

The finished rewrite contains **no em dashes (—)** and uses **no en dashes (–) as sentence punctuation**. Replace those marks, in rough order of preference, with a period, comma, parentheses, or a restructured sentence. A colon works too, but only where it introduces a list or an example, per the colon tell above; swapping an em dash for a mid-sentence colon trades one tell for another. Preserve legitimate numeric/date/page ranges by using a hyphen or writing "to" (`1914-1918`, `pp. 10 to 12`). Catch spaced em dashes (` — `) and double hyphens (` -- `) used the same way. Before delivering, search the draft for `—` and `–`; any remaining en dash must be a legitimate range, and any em dash means the rewrite is not done. One exception: a user-supplied writing sample that uses em dashes overrides this rule, and then the mark is matched to the sample's frequency rather than banned.

## What not to flag

Clean human writing trips several of these on its own. Do not gut legitimate prose:

- Polish, formal vocabulary, or consistent style, because professionals and edited writers exist.
- A single em dash, one *however*, one clipped emphatic sentence, or curly quotes alone. Editors and word processors produce all of these.
- Bland or dry prose without the *specific* tells above, because dry is not the same as AI.
- Quoted text, titles, proper names, or a phrase being discussed rather than used. Never rewrite inside those.

Lean toward leaving prose alone when you see hard-to-fake specifics (a real address, an odd quote), mixed or unresolved feelings, era-bound slang, genuine asides or self-corrections, and real variety in sentence length. Those are the fingerprints of a person.

## Removing tells is half the job

Prose with every tell stripped out and nothing put back reads as sterile, and sterile is its own signature. The catalog is the subtraction. This is what fills the space:

- **Take a position.** React to a fact rather than weighing its pros and cons at equal length.
- **Vary the rhythm.** A short sentence. Then a longer one that takes its time and earns the room. Uniform sentence length is a tell by itself.
- **Let it be uneven.** Sections of matching length and paragraphs of matching shape look manufactured, because they are.
- **Use *I* where the register allows.** First person is not unprofessional.
- **Say the specific thing.** Not *this is concerning* but the concrete version the source already supports.
- **Allow mixed feelings.** *Impressive, and a little unsettling* beats *impressive.*

None of this loosens the never-invent-facts rule at the top. Opinion, reaction, and unresolved feeling are voice, and you may add them. A name, number, date, or claim is fact, and you may not. In encyclopedic, technical, legal, or reference text, plain and neutral *is* the human voice, and this section barely applies.

## Process

1. Read the input and mark every instance of the tells above, then run [the two cut tests](#two-cut-tests) over what survives.
2. Write a **draft rewrite**: read it aloud in your head, vary sentence length, prefer concrete detail and plain constructions (*is/are/has*), hold the original's register and coverage, and give it the voice described in [Removing tells is half the job](#removing-tells-is-half-the-job).
3. Ask three questions: *what still makes this read as AI-generated?*, *does the draft state any fact, name, number, date, quote, or citation that isn't in the source?*, and *has the de-slopping left it sterile?* Answer all three in a few blunt bullets. A fabrication is a defect even when it reads more human than the vague original it replaced.
4. Revise into a **final rewrite** that fixes all three, carrying no em or en dashes.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

This is the hand-off for text pasted into the conversation. Called by another skill or agent, none of it applies: deliver the final text alone and stop. Working from a file, deliver the summary and the path, not the rewrite itself.

**What changed.** Deliver, in order: the **final rewrite** (the main artifact), a short **"what still read as AI"** note listing the tells you caught when you asked *what still reads as AI-generated*, and a one-line **summary of changes**. Say so plainly if the audit turned up a fabrication you had to pull back out. If the user asked only for a review, skip the rewrite and report the located tells with line references instead.

**Where it landed.** When a writable filesystem is available and the source came from a file, write the rewrite back (or beside it), leaving code blocks, frontmatter, tables, data, and link targets untouched, and report the path; otherwise print the rewrite in a fenced code block so it copies cleanly.

**Next.** Name one move and stop. Rewritten a file in a repo? The change is uncommitted prose: offer to commit it (**commitkit** when installed, otherwise a plain commit). Reviewed rather than rewrote? The move is to apply the tells you listed, so re-run humankit on the draft once they've decided which to take. Rewrote text that came from the chat rather than a file? There's nothing to route to; say the draft is theirs to paste back and stop rather than inventing a next step.

## Reference

The pattern catalog derives from [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), maintained by WikiProject AI Cleanup. The abstract-metaphor-noun list, the colon-as-connector tell, the two cut tests, and the voice section come from [pstack's `unslop` skill](https://github.com/cursor/plugins/blob/main/pstack/skills/unslop/SKILL.md).
