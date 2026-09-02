# Security an Agent Cannot Forget to Call

*Auditing a personal AI system's governance layer, finding that every guard
failed open on omission, and replacing "a function you must remember to call"
with boundaries the code cannot reach past.*

**Timeline:** mid 2026 · **Stack:** Python, PostgreSQL, Docker, MCP · **Status:** doctrine in force; applied to the successor system

## Context

A single-operator "personal cognitive architecture": a durable memory store
(facts, entities, provenance, audit trail) with LLM agents reading from it and
acting on the operator's behalf through tools — email, messaging, a browser,
GitHub, waking a GPU worker. Several agents from different frameworks shared
one tool server over the Model Context Protocol (MCP).

The system had a governance layer, and on paper it was the strictest pillar.
Every side effect was supposed to pass a policy gate: `evaluate_action()`
classified the action, consulted a policy file, and returned allow, deny, or
confirm-with-the-operator. Policy declared `fail_closed: true`. The
architecture document stated the invariant in one sentence: *the gate is the
only path to a side effect.*

The constraint set matters. One operator, no security team, LLM-assisted
development, and a codebase that had grown a new tool surface every few weeks.
Anything that depended on discipline at every call site was going to rot.

## Problem

An unrelated memory-integrity investigation had turned up a pattern: a check
that confirmed a mechanism *existed* rather than that it *held*. The question
was whether the pattern generalised. Governance was audited next, by
enumerating every side-effecting path and asking whether each one actually
reached the gate.

The gate itself was sound wherever it was called. It was not the only path.

- The HTTP router that exposed tools to agents contained **zero** calls to the
  gate. Its only guard was bearer-token auth. Of roughly 25 tool routes, 5
  were gated; the rest — including one that piped agent-authored code into a
  browser-automation subprocess, and two messaging routes that policy marked
  `confirm: true` — fired unconditionally with no audit row.
- The audit table proved it. Lifetime counts: the one gated email action had
  81 rows. Messaging sends, browser execution, worker wake, note deposits:
  **0 each**. Zero audit rows means the gate never saw them, not that they
  never ran.
- The MCP tool server had a correctly built default-deny capability tier, and
  one line that short-circuited it: connections presenting the *core* token
  skipped all write-tool checks, on the strength of a comment saying the core
  service wraps writes in its own gate. True for the core service. False for
  the chat brain and the agent fleet, which also held the core token. Net
  effect: whether an action was governed depended on which LLM served the
  turn.
- `fail_closed: true` was display-only. The evaluator had no exception
  handling; the declared "on error, deny" semantic did not exist. Per-service
  budget limits compared usage against a table nothing ever wrote to.
- **The tests defended the bypass.** A test asserted that ungated browser
  execution returned stdout — asserting that arbitrary code execution
  succeeds. Nothing in the suite was universally quantified: no assertion that
  every registered tool had a class, or that every side-effecting route called
  the gate.

Put together, one agent held all three legs of the lethal trifecta: it fetched
unscanned web content into its context, it held the core token, and through
the short-circuit it could reach 13 ungated GitHub write tools plus
notifications and contact lookups. No exploit was observed. None was needed to
call the design broken.

The common shape of every finding: the guards **failed closed on policy and
open on omission**. A function call is a boundary only for code that calls it.

## Design

The first instinct — a smarter guard, a classifier watching traffic, a
"sentinel" process judging every action — was researched before anything was
built, and the literature is unusually unanimous against it. *The Attacker
Moves Second* (arXiv 2510.09023) took 12 published prompt-injection defenses
whose papers reported near-zero attack success and broke most of them at over
90% under adaptive attack. The design-patterns paper from Invariant, ETH and
others (arXiv 2506.08837) calls detection defenses "fundamentally heuristic".
Ball et al. (arXiv 2507.07341) show that under standard cryptographic
assumptions no efficient filter exists for some models: a small classifier in
front of a big model is ruled out formally, not just empirically. And the
older theory says why: Anderson's 1972 reference-monitor criteria are
*tamperproof, always invoked, small enough to verify*. A frontier model reading
attacker-influenced text meets none of the three.

The rule that came out of the research, and that now gates every new tool,
channel, or input surface:

> **Enforcement must be structural — what the agent can *reach* — never
> judgmental. A guard that is a function call fails open on omission.**

"Structural" means the control is a boundary the code cannot forget to invoke:
a database role, a network namespace, a dropped toolset, an allowlist of one.
Decisions are made on syntactic facts (which role, which host, which tool),
never on a model's opinion of whether content looks harmful — Rice's theorem
puts the latter outside the decidable class anyway. LLM-based scanning was
kept, demoted to telemetry: it raises attacker cost and produces evidence, and
nothing depends on it.

Applied to the audited system, in order:

1. **Close the omission, then make omission impossible.** Every side-effecting
   route was wired to the gate, and a single universally-quantified test now
   enumerates the router: every route must be listed as read-only or gated, and
   every gated one must return 403 under a deny decision. A new route that is
   not classified fails CI. `fail_closed` became real — the evaluator wraps
   evaluation and denies on any exception.
2. **Take the core token away from everything that is not the core.** The
   pattern already existed in-tree: hand ungoverned components a *read-only*
   token, so the tool server's own tier checks bind them. A regression test
   asserts the core token can never reach the chat brain's configuration.
3. **Move the write boundary into the database.** In the successor system the
   agent-facing write tool connects as a dedicated PostgreSQL role that can
   read, and can `INSERT` into a staging table, and can do nothing else: it
   cannot write facts, cannot `UPDATE` the staging table (so it can never
   promote its own proposal), cannot `DELETE`. Promotion is a separate
   operator-run step. A prompt-injection-compromised agent process can only
   propose. The quarantine is enforced by the database engine, which does not
   have a code path that forgets.
4. **Governance runs with no network.** The gate and promotion tooling execute
   in a container started with `--network none`. Exfiltration from inside the
   governance step is not filtered; it is unreachable.

```
 untrusted content ──► agent process ──► MCP write tool
                                              │ connects as: proposer role
                                              ▼
                              ┌──────────────────────────────┐
                              │ staging table   INSERT only  │
                              │ facts           SELECT only  │   ◄── DB grants,
                              │ staging UPDATE  no grant     │       not code
                              └──────────────────────────────┘
                                              │
                            operator promote (separate role, --network none)
                                              ▼
                                         facts table
```

### Alternatives considered

- **An LLM "sentinel" judging every action.** Rejected on the evidence above.
  It also fails Thompson's diverse-double-compiling test: a guard from the same
  model family as the agent shares its failure modes, and guardrail models
  empirically fall to the same attacks as the models they guard.
- **Extend injection scanning to the unscanned paths** (web fetch, MCP results,
  transcripts). This was my own earlier recommendation and was withdrawn. The
  system already ran regex plus a classifier on inbound email; adding the same
  control to more paths adds coverage of a control with near-total adaptive
  false-negative rate. Kept as telemetry, not a barrier.
- **A time-based hold window** (execute unless cancelled within N minutes).
  Rejected twice. As a security mechanism it is fail-open by construction — the
  exact weakness being fixed, rebuilt. As an operator-recourse mechanism, the
  human-factors literature kills the rationale: doubling a confirmation delay
  gave no benefit (Bravo-Lillo, SOUPS 2013), while forced engagement with the
  *specific* field at commit time moved catch rates from 14% to 74%. Time is
  not the variable; specificity and rarity are.
- **Buffered, transactional effects** (an effect outbox with compensation).
  Genuinely stronger in theory — edit automata enforce strictly more than
  halt-only monitors — and an active research area, but it is not what was
  broken here. Noted as the next step, not adopted.

## What made it hard

**Believing the audit.** A system with a policy file, an evaluator, an audit
log, and a document declaring the invariant *looks* governed, and every
individual piece worked. The finding only appears when you enumerate the
whole surface and ask of each path "show me the call". The dominant defect
class across this system's incidents was the same: checks that appear to
verify but don't — a test that asserts a mechanism exists, an audit query that
cannot distinguish "gate approved" from "code wrote an allow row".

**The method trap while researching the fix.** Four literature queries
returned zero results and appeared to confirm that a proposed direction was
novel. A control query on a term with hundreds of known papers also returned
zero: the client was following a redirect wrongly. Four false nulls, all
flattering the hypothesis. The rule now is that no negative result is
accepted without a known-positive control, and the novelty claim was
retracted once the corrected search found the prior work.

**Policy authoring is a standing tax.** Structural controls need per-tool,
per-flow policy that someone has to write and maintain. For one operator this
is the most likely thing to rot, which is why the universally-quantified test
matters more than any single grant: it converts "did anyone remember" into a
CI failure.

## Selected code

The database role that makes the successor's write path structural. Lightly
renamed; the shape is exact.

```sql
-- The least-privilege role the agent-facing write tool connects as.
-- It can read, and it can STAGE proposals. It cannot write facts, cannot
-- UPDATE the staging table (so it can never self-promote), cannot DELETE.
-- Even a prompt-injection-compromised agent process can only propose.
CREATE ROLE agent_proposer WITH LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB
  NOBYPASSRLS NOREPLICATION INHERIT;
GRANT CONNECT ON DATABASE memory TO agent_proposer;
GRANT USAGE ON SCHEMA public TO agent_proposer;
GRANT SELECT ON public.facts, public.entities, public.embeddings,
  public.pending_ingestion TO agent_proposer;
GRANT INSERT ON public.pending_ingestion TO agent_proposer;
-- No other grants. Promotion runs as a different role, in a different process.
```

The test that makes omission a CI failure. Every route in the tool router must
be enumerated as read-only or gated; every gated route must call the evaluator
exactly once and honour a deny:

```python
def test_every_side_effecting_route_is_gated(client, monkeypatch) -> None:
    import api.routers.tools as tools_mod

    paths = {route.path for route in tools_mod.router.routes}
    assert paths == _READ_ONLY_ROUTES | set(_GATED_ROUTES), (
        "every /tools route must be enumerated here as read-only or gated"
    )

    _forbid_side_effects(monkeypatch)
    evaluated: list[str] = []

    def deny(*, channel, action, parameters, **kw) -> PolicyDecision:
        evaluated.append(action)
        return PolicyDecision(decision="deny", reason="universal deny",
                              channel=channel, action=action)

    monkeypatch.setattr(tools_mod, "evaluate_action", deny)

    for path, (action, body) in _GATED_ROUTES.items():
        evaluated.clear()
        r = client.post(path, json=body, headers=_auth())
        assert r.status_code == 403, f"{path}: {r.status_code} {r.text}"
        assert evaluated == [action], path
        assert r.json()["decision"] == "deny", path
```

## Outcome

- All 21 side-effecting tool routes gated, with the enumeration test guarding
  the set; the core token confined to the core service; `fail_closed`
  implemented rather than declared.
- The doctrine is now a gate item applied before any new surface is added.
  Its later applications were direct: an inbound-content channel designed
  around reach rather than scanning, and an egress broker's scope widened
  because "it has zero call sites" was recognised as the same finding.
- The successor system was built on the database-role model from day one. Its
  agent write path has never held a grant that could write a fact.
- The two best controls found during the audit were already the right shape —
  a deterministic, out-of-process conservation check over row counts, and a
  privacy sentinel with its own canary — and were left alone. Recognising what
  *not* to touch was part of the result.

Honest limitations: none of this addresses **memory poisoning by plausible
false content**. The proposer role stops an agent from writing facts; it does
not stop an operator from promoting a well-crafted lie. Text-to-text attacks
remain unsolved by every architectural pattern in the literature, and the
evidence that the memory half of the problem can be enforced at all — rather
than only detected — is thin.

## Retrospective

Two things would be done differently.

Write the universally-quantified test *first*, before the first tool route
exists. Every per-route guard in this system was added correctly and then
undermined by the next route that wasn't. The enumeration test costs an hour
and would have made the whole audit unnecessary.

And distrust convergence. The original governance design was reviewed by two
independent models and both approved it; so did the tests. Agreement raised
confidence without touching correctness, because every reviewer was checking
that the mechanism existed. The only review that found anything was the one
that enumerated paths and counted audit rows — evidence from the running
system, not opinions about its design.
