# Standards for public project repositories

This portfolio links to a small number of public repositories under the same
professional identity. Each one is a *presentation copy*: a clean build of
something that runs for real in a private working tree. This document is the
bar a project must clear before it gets a link from the portfolio README, and
the process for creating one.

The first project built to this standard was the reading tracker (TBR Shelf);
its repository is the reference example.

## 1. Provenance and identity (structural, non-negotiable)

- A **fresh repository with no shared history** with any working tree. Code
  is copied in and rebuilt; it is never `git filter-branch`ed out of a private
  repo, because history rewrites don't un-publish.
- Created with `tools/new-public-repo.sh`, which wires the fail-closed
  `.githooks/pre-commit` and `pre-push` gates (deny-list + gitleaks) and sets
  the professional git identity before the first commit.
- Pushed only over the dedicated SSH alias for the professional account
  (`IdentitiesOnly`), so the wrong key can never be offered.
- `tools/publish-check.sh <repo>` passes before the first push and before
  every release: identity set, hooks wired, full-history gitleaks clean,
  deny-list clean, and no infrastructure-shaped strings (tailnet hostnames,
  LAN addresses, home-directory paths, personal service ports).
- Nothing in the repo names the private project, the private repo, the host,
  the network, or any other online identity. Pick a **distinct project name**
  from the private working name when the private name could link the two.

## 2. The reader's first sixty seconds

The README is the product. A stranger with the relevant background must be
able to tell, without scrolling far:

- **What it is**, in one sentence, and who it is for.
- **What it looks like**: a hero screenshot from **demo data**, never from
  personal data, followed by a short screenshot tour of the distinctive parts.
- **How to run it** on a clean machine with a copy-paste quick start that was
  actually executed as written (pip and Docker paths both).
- **What it needs**: a configuration table, and a clear statement of which
  integrations are optional and what happens without them.
- **What it does not do**: an honest limitations section, including anything
  that was measured (scale limits, missing auth, prompt-only guardrails).

## 3. Code

- Formatter and linter clean, enforced in CI (`ruff format --check`,
  `ruff check`, or the language equivalent).
- Type hints on every function in Python; the file layout is `src/<package>/`
  with one module per concern and thin route modules.
- **No personal defaults.** Configuration comes from environment variables
  with a project prefix; the defaults are empty or generic. If it took a real
  hostname to work at home, it takes an env var in public.
- **Optional integrations degrade structurally.** A feature whose backend is
  unconfigured hides its UI and answers 503; it does not throw, and it does
  not require a mock server to run the app.
- Decision logic is factored into pure functions so the tests can hit it
  directly (the lookup verdict, candidate merging, import dedupe).
- No dead code, no commented-out blocks, no TODOs, no debug prints, no
  vendored personal scripts. Comments explain *why*, and only where the code
  can't.

## 4. Tests and CI

- A test suite that is **hermetic**: no real network (an autouse fixture that
  refuses outbound calls), a temp data directory per test, no dependence on
  the developer's machine beyond documented system packages (e.g. fonts).
- Coverage of the *contracts*: every API endpoint's success and validation
  paths, the concurrency rule (stale write → 409), migrations from an older
  schema, and each decision function's branches.
- CI on push and pull request runs lint, tests, and any front-end syntax
  check. The badge is optional; the green run is not.

## 5. Documentation

- `docs/architecture.md`: a text diagram, a module table, and the handful of
  decisions that shape the code with the alternatives they beat. Include the
  data directory layout and what needs backing up.
- Every API that an external process is expected to call (import, asset
  delivery, review loops) is documented with its contract.
- A `.env.example` that lists every variable with a one-line explanation.

## 6. Packaging and operations

- `pyproject.toml` (or equivalent) with pinned-minimum dependencies, an entry
  point, and `dev` / optional extras.
- A `Dockerfile` that builds from the repo and runs with one volume.
- An OSI license file (MIT unless there is a reason otherwise).
- Semantic version in the package; a `CHANGELOG.md` once there is a second
  release.

## 7. Portfolio linkage

- A row in the portfolio README's projects table: name, one-line description,
  themes, link.
- Optionally a case study, when the project carries a design story worth
  telling on its own (the portfolio template applies).

## Checklist (copy into the first-push PR or notes)

```
[ ] fresh repo via tools/new-public-repo.sh; hooks wired; identity set
[ ] distinct public name; no private names/hosts/paths anywhere
[ ] tools/publish-check.sh passes
[ ] README: pitch · hero screenshot (demo data) · quick start executed · config table · limitations
[ ] lint + format clean; CI green
[ ] tests hermetic; contracts covered; migrations covered
[ ] docs/architecture.md; .env.example; Dockerfile; LICENSE
[ ] optional integrations hidden/503 when unconfigured
[ ] portfolio README row added
```
