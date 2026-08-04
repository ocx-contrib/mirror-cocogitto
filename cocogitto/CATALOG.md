---
title: Cocogitto
description: The conventional commits toolbox — verify, log, changelog and version-bump a Git history
keywords: cocogitto,cog,conventional-commits,semver,changelog,git,release,versioning,rust,cli
---

# Cocogitto

[Cocogitto](https://github.com/cocogitto/cocogitto) is a command-line toolbox
for the [Conventional Commits](https://www.conventionalcommits.org) and
[SemVer](https://semver.org) specifications. It reads a repository's history
directly, parses every commit message against the specification, and drives
the release chores that follow from it — changelog generation, semver
inference and tagging.

The whole tool ships as one binary called `cog`. It embeds libgit2, so it
reads and writes Git objects itself rather than shelling out to `git`.

`cog check` verifies that every commit in a range conforms to the
specification; `cog verify` checks a single message before it is committed.
`cog commit` and `cog install-hook` keep new commits conforming in the first
place. `cog changelog` renders the history into a changelog, `cog get-version`
infers the current version from the tag history, and `cog bump` combines the
two — computing the next semver from the commit types since the last tag,
writing the changelog and creating the tag. Monorepos are supported through
per-package tags and configuration, and everything is configured from a single
`cog.toml`.

## What's included

- **cog** — the whole toolbox. `cog check` verifies a commit range against the
  conventional-commit specification and exits non-zero on the first
  non-conforming message; `cog verify "<message>"` checks one message without a
  repository; `cog commit <type> <message>` creates a conforming commit;
  `cog changelog` renders the history; `cog get-version` reports the version
  inferred from tags; `cog bump` computes the next semver, writes the changelog
  and tags; `cog init` scaffolds `cog.toml`; `cog install-hook` installs the
  Git hooks; `cog generate-completions` emits shell completions.

The release archive contains this executable and the upstream `LICENSE`.

No `git` executable is required — `cog` links libgit2 statically and performs
its own repository access.

## Links

- [Cocogitto on GitHub](https://github.com/cocogitto/cocogitto)
- [Documentation site](https://docs.cocogitto.io)
- [Conventional Commits specification](https://www.conventionalcommits.org)
