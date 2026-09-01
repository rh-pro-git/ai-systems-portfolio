# Publishing Policy

This repository is public. Everything in it is treated as permanent the moment
it is committed — history rewrites don't un-publish. The rails below are
structural where possible: this repo has no remotes to, no submodules of, and
no shared history with any working repository, and code enters only by hand or
through `tools/import-excerpt.sh`.

## Never published

- Secret values of any kind: tokens, keys, passwords, connection strings —
  including in code excerpts, logs, screenshots, and example output.
- Network identity: hostnames, tailnet names, LAN/public IPs, ports tied to
  real services, domain names of private infrastructure.
- Personal data: real file-system paths, email addresses, account handles,
  device names, financial or calendar data, meeting content.
- Anything linking this professional identity to other online identities.

## Rewrite before publishing

- Real host/service names → generic role names ("the hub", "the GPU worker").
- Real paths → illustrative paths (`/opt/app`, `~/project`).
- Timestamps/log lines from real systems → trimmed or synthesized equivalents.
- Project codenames are allowed only if they don't appear anywhere else online
  in connection with other identities. When in doubt, use a descriptive name.

## Enforcement layers

1. **Structure** — no remotes or history shared with working repos; the
   allowlist import script is the only sanctioned path for code.
2. **Pre-commit gate** (`.githooks/pre-commit`, wired via `core.hooksPath`) —
   fail-closed: blocks if the deny-list file is missing, if the repo's git
   identity is unset or matches the deny-list, on any gitleaks hit in the
   staged diff, or on any deny-listed string in staged files. The deny-list
   lives outside the repo so its contents are never published.
3. **Pre-push review** — before every push: `gitleaks git --redact` over full
   history, plus a human read of the diff being published.

A fresh clone does not inherit `core.hooksPath`; run
`git config core.hooksPath .githooks` after cloning. The hook is a backstop,
not the guarantee — the guarantee is layers 1 and 3.
