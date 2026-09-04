## Mode: `audit`

**Read-only. Writes nothing, ever.** It reports, and routes to [`update`](./update.md) or [`init`](./init.md) for the fixing. Reporting a problem and fixing it are separate invocations, deliberately.

Three checks per page, cheapest first:

- **Recency.** The page's stamp against the commits touching the code it documents, diffing from the stamped SHA while it is reachable and falling back to the date when it isn't. Grep-cheap, so it runs over **every** page. It is a prefilter, not a verdict: a stale stamp on an unchanged concept is fine.
- **Claim verification.** The load-bearing one. Every command, path, env var, flag, and endpoint on the page checked against the repo, with the allowlisted probes available on consent. A command that no longer exists is **broken**; a described behavior that changed is **stale**. This pass is budgeted and spends **highest-risk-first**, ordered by the recency prefilter.
- **Coverage.** Documentable surface with no page at all: an undocumented CLI command, a deploy path with no runbook, a public entry point missing from the architecture page.

### The report

A table per page with a verdict, plus quoted evidence for anything that isn't `current`:

| Verdict | Means |
|---|---|
| `current` | claims check out against the code |
| `stale` | a described behavior changed |
| `broken` | a command, path, or var on the page no longer exists |
| `unverified` | an adopted page wikikit has never claim-checked, **distinct from stale** |
| `missing` | documentable surface with no page |

Add a **manifest-drift row** from the reconcile pass, and crown one next move.

Every report **opens** with a mandatory coverage line, because an audit that silently covered 12% reads exactly like a clean bill of health:

```
Recency: 312/312 · Claims verified: 40/312 (highest-risk first) · Not claim-checked: 272 (listed below)
```

The not-claim-checked pages are listed, not summarized as a count. A scope argument (`audit how-to/`) narrows the run explicitly; the coverage line reports the narrowing either way.

### Hand off

**What changed.** Nothing. Say that outright; `audit` is read-only and a reader should never have to wonder.

**Where it landed.** Inline in this reply. Offer to save it only if asked; there is no audit artifact by default.

**Next.** Crown the single most-broken page and route it to [`update`](./update.md), or to [`init`](./init.md) when the gap is a missing page rather than a wrong one. **Nothing to fix is a valid, stated result**, so say the set is current and stop.
