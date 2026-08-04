# NOTICE

This repository packages and redistributes upstream software published by the
[Cocogitto](https://github.com/cocogitto/cocogitto) project. The Apache-2.0
license in [`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It
does **not** cover any upstream-derived asset — the redistributed bytes carry
their own license, recorded below.

The package logo is upstream's own mark
([`docs/logo/COCOGITTO_LOGO_web_72dpi.png`](https://github.com/cocogitto/cocogitto/blob/main/docs/logo/COCOGITTO_LOGO_web_72dpi.png),
designed by Arnaud Perrot per upstream's `docs/logo/Logo.md`), re-encoded to
512×512 for catalog identification only. No endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `cocogitto` | `ghcr.io/ocx-contrib/cocogitto/cocogitto` | `MIT` |

---

## `cocogitto`

Upstream: <https://github.com/cocogitto/cocogitto>
Published to `ghcr.io/ocx-contrib/cocogitto/cocogitto`.

| Component | SPDX | Holder |
|---|---|---|
| Cocogitto (`cog`) | **MIT** | Paul Delafosse |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/cocogitto/cocogitto/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"MIT"}
```

MIT is permissive and grants redistribution of the compiled binary subject to
its notice-retention condition — and here that condition is satisfied by
upstream itself: **every release archive ships the MIT `LICENSE` beside the
`cog` executable** (verified with `tar tvf` on all six assets of 6.4.0 and
7.0.0 — two entries each, `<target-triple>/LICENSE` at 1071 bytes and
`<target-triple>/cog`), and `strip_components: 1` keeps both at the bundle's
content root. The notice therefore travels with the binary rather than being
reproduced only here. The canonical text is
<https://github.com/cocogitto/cocogitto/blob/main/LICENSE>, and every published
manifest carries an `org.opencontainers.image.source` annotation pointing at
this repository alongside `org.opencontainers.image.licenses: MIT`.

The published binaries are Rust builds that vendor their third-party crates
statically; the closure is enumerated in upstream's `Cargo.lock` and is
permissive with one deliberate exception worth recording here. Cocogitto 7.0.0
pins `git2 0.20.4` / `libgit2-sys 0.18.3+1.9.2`, so **libgit2 1.9.2 is linked
into every published `cog`**. libgit2's own
[`COPYING`](https://github.com/libgit2/libgit2/blob/main/COPYING) is GPL
version 2 *"and no other version"* carrying an explicit **LINKING EXCEPTION**
— the same construction the Git ecosystem relies on, which permits
distributing a work linked against libgit2 under that work's own license.
(GitHub's license API reports `NOASSERTION` for libgit2 because its detector
does not classify the exception; the COPYING file above is the authority.) The
MIT grant therefore governs the redistributed binary, and upstream's source
remains available at the URL above for every version this mirror publishes.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
