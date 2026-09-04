# AI Systems Portfolio

Selected case studies from several years of building personal AI infrastructure:
agentic systems, governed memory substrates, security architecture for
LLM-driven agents, and the operational discipline that keeps them trustworthy.

Each case study covers the problem, the constraints, the design and its
alternatives, what made it hard, and the measured outcome — with short,
illustrative code excerpts where they earn their place. These are writeups of
real, running systems; the working repositories are private.

## Case studies

<!-- Index updated as case studies land. -->

| Case study | Theme | Year |
|---|---|---|
| [Security an Agent Cannot Forget to Call](case-studies/structural-security.md) | Agent security · structural enforcement | 2026 |
| [Documentation That Cannot Go Stale](case-studies/drift-gated-docs.md) | Operational rigor · agent context | 2026 |

## Projects

Presentation builds of systems that run for real; each is held to
[STANDARDS.md](STANDARDS.md).

| Project | What it is | Themes |
|---|---|---|
| [TBR Shelf](https://github.com/rh-pro-git/tbr-shelf) | Self-hosted reading tracker: three-catalog metadata resolution with human-in-the-loop verification, a rendered bookshelf, and an optional local-LLM librarian whose memory is gated on operator review. v1.1 took a 760-book page from 74 MB to 0.3 MB by deferring each tile's detail and serving right-sized derivatives while never re-encoding a source. | Optional-by-structure AI · governed learning loop · measured performance work · single-file ops |

## Themes

- **Structural security over judgment-based guards** — enforcement as what an
  agent can *reach* (DB roles, network isolation, dropped toolsets), not
  classifiers that fail open.
- **Governed memory** — proposal/promotion gates, provenance, decay, and
  auditable lifecycle for long-lived agent memory.
- **Operational rigor** — drift-gated generated docs, conformance audits,
  encrypted DR with restore proofs, checks that actually assert values.

## About

Maintained by Ryan Hill. Contact: github@hillemails.org.
