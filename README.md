# mirror-cocogitto

OCX mirror for [Cocogitto](https://github.com/cocogitto/cocogitto), the
conventional-commits and SemVer toolbox. One repository, one spec directory per
package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [Cocogitto](https://github.com/cocogitto/cocogitto) | [`cocogitto/mirror.yml`](cocogitto/mirror.yml) | `ghcr.io/ocx-contrib/cocogitto/cocogitto` | [`ocx.sh/cocogitto/cocogitto`](https://index.ocx.sh/cocogitto/cocogitto) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

The binary is `cog`; the package is `cocogitto`. The package segment is the
name the project publishes under, not the command you type — the same
relationship as `github/cli` shipping `gh`.

## Layout

```
mirror-base.yml         repo-wide policy the spec inherits via `extends:`
cocogitto/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. The logo is **not** — it sits
beside the spec, because a repo-root `logo.*` sits in no workflow's `paths:`
filter, so replacing it would publish nothing until some unrelated edit
happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. `cocogitto/mirror.yml` does
not restate `platforms:` at all; the measured matrix lives in `mirror-base.yml`.

## Tags: two schemes share this repository, one carries the releases

`gh api repos/cocogitto/cocogitto/tags` returns three shapes:

```
7.0.0, 6.5.0, 6.4.0, …               bare semver — THESE carry the releases
cocogitto-7.0.0, cocogitto-6.5.0     a dead twin scheme, zero release objects
cocogitto-dependency-resolver-0.1.0  an unrelated internal crate
```

`tag_pattern` is therefore anchored on the bare form, `^(?P<version>\d+\.\d+\.\d+)$`.
A looser pattern that also admitted the `cocogitto-` prefix would resolve tags
with no assets behind them, and the mirror would publish nothing while staying
green.

## Platforms

Two platform entries today (Linux only, pass 1 of the staged rollout); darwin
and windows are pre-written and commented out in both `assets:` and
`platforms:`, uncommented one pass at a time. Commenting **both** halves is
deliberate — a platform declared with no matching asset still boots a real
macOS or Windows runner, self-skips, and reports SUCCESS having tested nothing.

**Upstream's Linux coverage is asymmetric, so each arch was measured on its
own.** `os.features` states what an artifact requires *of the host*, never how
it was built:

| Key | Asset | Measured (6.4.0, 6.5.0 and 7.0.0 — identical) |
|---|---|---|
| `linux/amd64` | `…-x86_64-unknown-linux-musl.tar.gz` | `static-pie linked`, `INTERP` **0**, `DT_NEEDED` **0**, no `GLIBC_*` symbol versions → **bare** |
| `linux/arm64+libc.glibc` | `…-aarch64-unknown-linux-gnu.tar.gz` | `interpreter /lib/ld-linux-aarch64.so.1`, 5 × `DT_NEEDED`, newest `GLIBC_2.18` → **`+libc.glibc`** |

x86_64 ships musl **only** and aarch64 ships gnu **only** — there is no second
build to choose between on either arch, and neither arch's verdict could have
been inferred from the other's. The UPX gate was run first, because a packed
asset defeats `readelf` entirely: `strings -a … | grep -c '^UPX'` is 0 and no
artifact reports `section headers: 0`, so the measurements are real.

The `alpine:3.20` leg on `linux/amd64` is what turns that bare key's
universality claim into evidence. `linux/arm64+libc.glibc` runs `ubuntu:24.04`
and `fedora:40` only (both glibc 2.39, clearing the 2.18 floor); an alpine leg
there would red with a loader error, which is the honest answer but not a
useful test.

### Deliberately not carried

- `cocogitto-<V>-armv7-unknown-linux-musleabihf.tar.gz` — 32-bit ARM has no OCX
  platform key at all. The `Architecture` enum is amd64 + arm64 only, so this
  is inexpressible rather than missing.
- **`windows/arm64` — upstream ships no `aarch64-pc-windows-msvc` asset.**
  6.4.0, 6.5.0 and 7.0.0 carry exactly six assets each, re-listed per tag, and
  the only Windows target among them is `x86_64-pc-windows-msvc`.

⚠️ **The Windows asset is a `.tar.gz`, not the usual `.zip`** — unusual for an
msvc target, and a `\.zip$` pattern would match zero assets and be *silently
skipped*.

## Archive layout and the binaries claim

`tar tvf` on every declared asset of 6.4.0 and 7.0.0 — all six are the same
two-entry shape:

```
cocogitto-<V>-<triple>.tar.gz  →  <triple>/LICENSE   -rw-r--r--  1071 B
                                  <triple>/cog       -rwxr-xr-x  (cog.exe on windows)
```

So `strip_components: 1` uniformly, Windows included, because its asset is a
tarball with the same wrapper rather than a flat zip. The wrapper name embeds
the target triple, so keeping it would need a different metadata file per
platform for no gain. After the strip the content root holds `cog` beside
upstream's own `LICENSE` — which is how the MIT notice-retention condition is
satisfied by the shipped bytes rather than only by this repository.

The bundle's only PATH entry is therefore a bare `${installPath}`. `bin_scan`
only looks *below* an `${installPath}/<dir>` entry, so `auto`/`verify` is
rejected at spec load with exit 65 (*the verification would inspect no file and
pass green whatever the archive contains*). `cocogitto/mirror.yml` sets
`bin_scan: "off"` and `cocogitto/metadata.json` hand-lists `binaries: ["cog"]`
— the blessed shape for this layout, and `cog` is the archive's only
executable at both ends of the range.

## `git` is NOT a runtime dependency — and that was measured

Cocogitto looks like a tool that must shell out to `git`, and it does not. It
links **libgit2 statically** (`git2 0.20.4` / `libgit2-sys 0.18.3+1.9.2` in
upstream's `Cargo.lock`) and performs its own repository access. Verified
inside a bare `alpine:3.20` where `command -v git` returns nothing:

```
$ cog init          → exit 0, "Empty git repository initialized in \".\""
$ cog check         → exit 0, "No errored commits"
$ cog changelog     → "## Unreleased (c8f8d19..c8f8d19)" — short OIDs it
                      computed from the object database
$ cog check         → in a non-repository: exit 1,
                      "class=Repository (6); code=NotFound (-3)"  ← libgit2's own
```

`mirror-base.yml` therefore carries **no** `containers[].setup`, unlike the
fleet's genuinely git-shelling mirrors (prek, lefthook). That is not an
omission: bare images make the stronger and true claim that this artifact needs
nothing of the host beyond its libc, and installing git would have proved less.

The one thing `cog` does need for a *write* operation is a committer identity,
which libgit2 reads from the global git config only — it honours no
`GIT_AUTHOR_*` environment variables. The smoke test supplies one by pinning
`HOME` into the scratch sandbox and writing a `.gitconfig` there.

## The smoke test

`cocogitto/tests/smoke.star` is hermetic and offline, and asserts computed
values rather than prose or a bare exit 0:

- version **shape** (`\d+\.\d+\.\d+`), not the banner;
- `cog verify` on a valid message → exit 0 with the decomposed `Type: feat` /
  `Scope: scope` fields on **stderr** (stdout asserted empty — measured);
- a **negative control**: `cog verify "this is not conventional"` → exit 1, and
  the assertion is not the exit code but the `--> 1:5` position cog *computed*
  for the offending span plus the grammar rule it names
  (`expected scope or type_separator`). Neither string appears in the script's
  inputs;
- `cog init` → a real repository built by the vendored libgit2, with
  `cog.toml`'s own serialised defaults read back;
- `cog check` → exit 0 over that history, paired with `cog check` in a
  *non*-repository → exit 1 carrying libgit2's `class=Repository` diagnosis, so
  an empty walk cannot green;
- `cog changelog` → the `#### Miscellaneous Chores` heading cog **mapped** from
  the commit's `chore` type (the word appears nowhere in the repository), a
  7-hex short-OID range nothing in the script can predict, and the author read
  back out of the commit it created;
- `cog get-version` on a tagless repository → exit 1 `No version yet`, the
  computed answer to a real tag walk.

`cog log` is deliberately **not** used: it pipes through a pager and busybox
`less` in `alpine:3.20` rejects the `--RAW-CONTROL-CHARS` cog passes it.

The whole sequence was run locally against real 6.4.0, 6.5.0 **and** 7.0.0
bundles — every in-range version, because a flag surface can drift inside a
range even when the binary set does not — and re-run inside bare
`ubuntu:24.04`, `alpine:3.20` and `fedora:40` containers before anything was
pushed.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `cocogitto/mirror.yml` | hand | yes — see below |
| `cocogitto/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `cocogitto/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec cocogitto/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
