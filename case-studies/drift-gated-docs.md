# Documentation That Cannot Go Stale

*Replacing a hand-written "what is running" doc — found 100% wrong — with an
hourly, drift-gated generated block that AI agents can actually trust.*

**Timeline:** mid 2026 · **Stack:** Python, systemd, Tailscale · **Status:** running

## Context

A single-operator AI infrastructure host runs a few dozen systemd services and
timers across user and system scope: memory substrate, agent fleet, backup and
audit jobs, tailnet-exposed web surfaces. Coding agents (Claude Code sessions)
work on this host constantly, and their context file describes the environment
— including a section listing what is currently running, so an agent knows
which services are live, which are retired, and which ports mean what.

That section was hand-maintained prose, updated whenever someone remembered.

## Problem

An infrastructure audit checked the context file's service list against
`systemd` reality. Every one of the 16 units it named was `not-found` or
`disabled`. Not partially stale — **100% wrong**.

For human readers, stale docs are an annoyance. For an LLM agent they are
worse than no docs: the agent treats the context file as ground truth and
confidently acts on ghosts — probing dead ports, "restarting" retired
services, referring the operator to dashboards that stopped serving months
ago. The failure mode compounds because the doc *looks* authoritative; nothing
about hand-written prose signals its own staleness.

## Design

A small generator runs hourly from a systemd timer and rewrites one region of
the context file from live introspection (`systemctl list-units`,
`list-timers`, `systemctl show`, `tailscale serve status`). Three decisions
carry the design:

**Single writer per region, not per file.** The generated block sits between
HTML-comment markers. The script owns only the text between them and refuses
to run if the markers are missing; everything outside stays hand-maintained.
Judgment and narrative remain human; enumerable facts become machine-owned.
The block opens by declaring its own generator, so any reader — human or
agent — knows edits there are futile and where the truth comes from.

**Drift-gated writes.** The block is re-rendered every run but written only if
it differs from what is on disk. An hourly rewrite that always touches the
file would bury real changes in noise (mtime churn, meaningless diffs in
backups); with the gate, the file changes exactly when reality changes.

**Exclude volatile fields.** The drift gate only works if the rendering is
deterministic over unchanged reality. Timers are reported by their *schedule
expression*, never their next-fire time — a next-fire timestamp differs every
run and would make the gate fire uselessly forever. Monotonic timers
(`OnUnitActiveSec`) need the same care, since systemd reports them alongside a
volatile `next_elapse`:

```python
def timers(user: bool) -> list[tuple[str, str]]:
    """Return (name, schedule). Schedule is the OnCalendar EXPRESSION, never the
    next-fire time — a volatile field would make the drift gate fire every run."""
    scope = ["--user"] if user else []
    out = run(["systemctl", *scope, "list-timers", "--all", "--no-pager",
               "--no-legend", "--plain"])
    rows = []
    for line in out.splitlines():
        m = re.search(r"(\S+\.timer)\s+\S+\.service\s*$", line)
        if not m:
            continue
        unit = m.group(1)
        name = unit.removesuffix(".timer")
        if not KEEP.match(name):
            continue
        cal = run(["systemctl", *scope, "show", unit, "-p", "TimersCalendar",
                   "--value"]).strip()
        c = re.search(r"OnCalendar=([^;]+?)\s*;", cal + " ;")
        if c:
            rows.append((name, c.group(1).strip()))
            continue
        # Monotonic timers (OnUnitActiveSec / OnBootSec) carry no OnCalendar.
        # The value is a human duration string ("15min"), never a number, and
        # each entry also carries a volatile next_elapse that must be dropped.
        mono = run(["systemctl", *scope, "show", unit, "-p", "TimersMonotonic",
                    "--value"]).strip()
        specs = re.findall(r"(On\w+)USec=([^\s;]+)", mono)
        if specs:
            rows.append((name, ", ".join(f"{k.removeprefix('On')} {v}"
                                         for k, v in specs)))
        else:
            rows.append((name, "(no schedule)"))
    return sorted(rows)
```

The write path is the whole gate — marker check, splice, compare, and a write
only on real drift:

```python
def main() -> int:
    if not TARGET.exists():
        print(f"absent: {TARGET}", file=sys.stderr)
        return 1
    text = TARGET.read_text()
    block = render()
    if START not in text or END not in text:
        print("markers absent — refusing to guess a location", file=sys.stderr)
        return 1
    new = re.sub(re.escape(START) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S)
    if new == text:
        print("no drift")
        return 0
    TARGET.write_text(new)
    print("updated")
    return 0
```

### Alternatives considered

- **Generate the whole doc.** Rejected: the valuable parts of a context file
  are judgment — warnings, history, "this looks live but is a trap" — which
  introspection cannot produce. Owning one region keeps both kinds of content
  in the one file agents actually read.
- **Have the agent query live state on demand.** Rejected as the primary
  mechanism: it spends tokens every session on questions that rarely change,
  and an agent that doesn't think to check inherits the stale prose anyway.
  Generated context makes the default path correct.
- **A separate machine-status file.** Rejected: adjacency matters. The
  hand-written prose immediately above the block says *trust this block, not
  older prose* — that instruction only works if they travel together.

## What made it hard

Nothing in the code is difficult; the discipline is in what to leave out.
Every volatile field admitted into the rendering silently destroys the drift
gate, and the failure looks like success — the block is always "fresh" while
its diffs become meaningless. Getting to a rendering that is byte-stable
across unchanged reality (sorted unit lists, filtered desktop noise, schedule
expressions only) was the actual work.

## Outcome

- The block has regenerated hourly since deployment; the file itself changes
  only on real drift, so its git history reads as a changelog of the
  infrastructure.
- Staleness of the "what is running" section went from *unbounded* (measured:
  100% wrong) to *at most one hour*.
- The failed-units line turned out to be a free passive monitor: it surfaced a
  broken nightly backup service in an agent session the morning after it
  first failed.
- The pattern was reused twice on the same host — a fleet-visibility catalog
  and a memory-index grouping are now generated the same way (machine-owned
  facts, hand-written annotations preserved across regenerations). The second
  instance is what made it a pattern rather than a script.

## Retrospective

The generator is itself unmonitored: if its timer dies, the block freezes
while still *declaring* itself live — exactly the trustworthy-looking
staleness this design exists to kill. The honest fix is a rendered timestamp
outside the drift comparison, or a watchdog on the timer; that gap is known
and open. It is a useful reminder that any freshness guarantee is only as good
as the thing that regenerates it.
