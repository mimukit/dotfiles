## A worked `task` run

One example, because the five parts are faster to recognize than to describe. This is the default mode doing its ordinary job, with no questions asked, because the tree answered them.

**In.** What the user pasted:

> fix the login bug, the session thing is broken. make sure tests pass and don't break anything else

**Grounding.** Three reads, no questions. A search for the session helper lands on `src/lib/session.ts` and the function that actually holds the bug; `package.json` gives the real commands; the repo's agent instruction file already mandates the error-handling convention, so the prompt points at that file instead of restating it.

**Out.** The prompt, ready to paste:

```
Fix the session expiry bug in `src/lib/session.ts`: `refreshSession()` returns the stale
token when the refresh call fails, so an expired session reads as valid downstream.

Scope: `src/lib/session.ts` and its test file. Do not touch `src/middleware/auth.ts`,
because the routing there is correct and deliberately out of scope for this fix.

Constraints: follow the conventions in the repo's agent instruction file. Keep
`refreshSession()`'s signature, since three call sites depend on it.

Done when `pnpm test src/lib/session.test.ts` passes with a new case covering the
failed-refresh path, and `pnpm typecheck` is clean.

Stop there. Do not refactor the surrounding token helpers, and do not commit.
```

**What changed.** The ledger:

```
resolved "the session thing" → src/lib/session.ts, refreshSession()
resolved "make sure tests pass" → pnpm test <file> && pnpm typecheck
resolved "don't break anything else" → named auth.ts as explicitly out of scope
assumed the bug is the stale-token return path; stated in the prompt, correct it if wrong
```

Read the two together and the mechanism is visible. Every vague phrase in the input has a row; the one thing the tree couldn't settle is a row too, and it names the assumption rather than hiding it, so a wrong guess costs one correction instead of a wasted run. Note also what the prompt *doesn't* say: nothing about error handling, because the instruction file covers it, and one pointer line is cheaper than a restatement that can contradict it.
