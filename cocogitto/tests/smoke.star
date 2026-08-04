# cocogitto/tests/smoke.star — stable across upstream cocogitto releases.
#
# Asserts the contract (exit codes, version SHAPE, the line:column a
# deliberately malformed commit message produces, the section heading cog
# DERIVED from a commit's type, and the short OIDs it read out of a real
# object database), never help/version prose.
#
# HERMETIC AND OFFLINE BY CONSTRUCTION, and it does not need `git` on PATH —
# cocogitto vendors libgit2 (the `git2` crate) statically and never execs the
# git binary. That was measured, not assumed: the whole sequence below runs
# green inside a bare `alpine:3.20` where `command -v git` returns nothing,
# and every error cog raises is libgit2's own, verbatim (`class=Repository
# (6); code=NotFound (-3)`). It is why ../../mirror-base.yml deliberately
# carries NO `containers[].setup` — the bare images are the stronger claim.
#
# The one thing cog does need is a committer identity, which libgit2 reads
# from the global git config only (it honours no GIT_AUTHOR_* env vars). So
# HOME is pinned into the scratch sandbox and a `.gitconfig` is written there
# — that keeps the run out of any real user config AND makes the test behave
# identically on a runner that happens to have one. USERPROFILE is set
# alongside it because libgit2's win32 global-config probe falls back to it.

COG = "cog.exe" if ocx.target_platform.os == ocx.os.Windows else "cog"

# `ocx.run(cwd=…)` resolves relative to scratch, so the repository lives in a
# subdirectory and the global config sits beside it rather than inside it.
ENV = {
    "HOME": ocx.scratch_root,
    "USERPROFILE": ocx.scratch_root,
}

ocx.write_file(".gitconfig", "[user]\n\tname = OCX Smoke\n\temail = smoke@ocx.invalid\n")
ocx.mkdir("repo")
ocx.mkdir("norepo")

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; the banner text is not. `cog 7.0.0` today, some
# other product name after a rebrand — the regex survives that, an
# `expect.contains(…, "cog")` would not.
r_version = ocx.run(COG, "--version", env = ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── Tier 3a: the conventional-commit PARSER, positive case ─────────────────
#
# `cog verify` is the one verb that needs no repository, and it exercises the
# same pest grammar `cog check` runs over history. cog writes the parse result
# to STDERR and leaves stdout empty — measured, and asserted here, because a
# tool that started writing to stdout instead would be a real interface change.
#
# `Type:` and `Scope:` are LABELS cog emits for fields it decomposed out of
# the message; the values beside them are the tokens it split. A passthrough
# that merely echoed its input would produce neither label — and Tier 3b below
# is the negative control that closes that gap properly.
#
# stdout is measured to be exactly one newline and nothing else, so `.strip()`
# rather than a bare "" — the contract being asserted is that the decomposition
# goes to STDERR and stdout carries no content, not the trailing byte.
r_ok = ocx.run(COG, "verify", "feat(scope): add a thing", env = ENV)
expect.ok(r_ok)
expect.eq(r_ok.stdout.strip(), "")
expect.contains(r_ok.stderr, "Type: feat")
expect.contains(r_ok.stderr, "Scope: scope")

# ─── Tier 3b: THE NEGATIVE CONTROL ──────────────────────────────────────────
#
# A parser that rubber-stamped its input would exit 0 here. Exit 1 alone is
# not the assertion: `1:5` is the line:column cog COMPUTED for the offending
# span (column 5 is where `is` starts, the first token that could not be a
# type separator), and `expected scope or type_separator` names the grammar
# rule it was in when it gave up. Neither string appears in this script's
# input, so emitting them is proof the grammar walked the message.
r_bad = ocx.run(COG, "verify", "this is not conventional", env = ENV)
expect.eq(r_bad.exit_code, 1)
expect.contains(r_bad.stderr, "expected scope or type_separator")
expect.matches(r_bad.stderr, r"--> 1:5")

# ─── Tier 3c: a real repository, created by the vendored libgit2 ────────────
#
# `cog init` writes cog.toml AND initialises a git repository with an initial
# commit. On a build where libgit2 were missing or broken this is the first
# thing that fails, and it fails loudly.
r_init = ocx.run(COG, "init", cwd = "repo", env = ENV)
expect.ok(r_init)

# cog.toml is cog's own serialisation of its default config — not a file this
# script wrote, and not a fixture copied from the archive. Two keys chosen
# from opposite ends of the struct so a truncated write would not pass.
cfg = ocx.read_file("repo/cog.toml")
expect.contains(cfg, "ignore_merge_commits = false")
expect.contains(cfg, "[changelog]")

# ─── Tier 3d: the history walk — cog check over the commit it just made ─────
#
# `check` opens the repository, walks every commit and parses each message.
# The initial commit cog wrote is conventional, so the verdict is exit 0 with
# `No errored commits` on stderr — stdout carries no content, same measured
# one-newline shape as `verify` above.
r_check = ocx.run(COG, "check", cwd = "repo", env = ENV)
expect.ok(r_check)
expect.eq(r_check.stdout.strip(), "")
expect.contains(r_check.stderr, "No errored commits")

# The other half of the same claim: `check` in a directory that is NOT a
# repository must fail, and fail with libgit2's own diagnosis rather than a
# generic one. A `check` that returned 0 for "no commits found" would green
# an empty walk, which is the failure this pair rules out.
r_norepo = ocx.run(COG, "check", cwd = "norepo", env = ENV)
expect.eq(r_norepo.exit_code, 1)
expect.contains(r_norepo.stderr, "could not find repository")
expect.contains(r_norepo.stderr, "class=Repository")

# ─── Tier 3e: the changelog engine — DERIVED output, not an echo ────────────
#
# `cog changelog` reads the object database and renders it. Three separate
# computations are asserted:
#
#   * `#### Miscellaneous Chores` — the section heading cog MAPPED from the
#     commit's `chore` type. The word "Miscellaneous" appears nowhere in the
#     repository; it exists only in cog's type→section table.
#   * `(<oid>..<oid>)` — a 7-hex-digit short OID range cog abbreviated from
#     the real commit hash. Nothing in this script can predict it, and a
#     renderer that never opened the ODB cannot produce it.
#   * `OCX Smoke` — the author, read back out of the commit cog created from
#     the .gitconfig written above. That closes the loop on the identity path.
#
# Output is plain (no SGR escapes) because cog only colourises `log`, which is
# deliberately not used here: it pipes through a pager, and busybox `less` in
# alpine:3.20 rejects the `--RAW-CONTROL-CHARS` cog passes it.
r_cl = ocx.run(COG, "changelog", cwd = "repo", env = ENV)
expect.ok(r_cl)
expect.contains(r_cl.stdout, "#### Miscellaneous Chores")
expect.matches(r_cl.stdout, r"\([0-9a-f]{7,}\.\.[0-9a-f]{7,}\)")
expect.contains(r_cl.stdout, "OCX Smoke")

# ─── Tier 3f: the tag walk answers from a real (empty) tag set ──────────────
#
# The repository has no tags, so `get-version` must say so rather than invent
# a version. Exit 1 with cog's own wording is the computed answer to "what is
# the latest semver tag here"; a stub returning 0.0.0 would pass a laxer test.
r_gv = ocx.run(COG, "get-version", cwd = "repo", env = ENV)
expect.eq(r_gv.exit_code, 1)
expect.contains(r_gv.stderr, "No version yet")

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
