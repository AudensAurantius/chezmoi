# Dependency Management Architecture

A reference document capturing several design proposals for consolidating
the chezmoi repo's dependency management. **No part of this document
describes current implementation** — the active state remains the
scattered per-tool pattern (one `run_onchange_install-<tool>.sh.tmpl` plus
one `.chezmoidata/<tool>.yaml` per managed repo). This file exists to
preserve the design conversation so we can revisit it without rederiving.

Tracking bead: **J121-?** (filed alongside this document; see
`bd show` for current status).

## Background

As of this document's creation (2026-04-30), the repo manages tools via:

- `home/.chezmoidata/packages.yaml` — apt packages (debian-only) and mise
  tool versions
- `home/.chezmoidata/<tool>.yaml` — one file per cloned-and-installed tool
  (bd-timew, graph-send-mail, formerly wsl-vpn-namespace, etc.)
- `home/run_onchange_install-<tool>.sh.tmpl` — one installer per tool,
  each ~40 lines doing roughly the same thing: clone if missing, fetch
  + checkout pinned ref, run install command (pipx-install, make-install,
  asset download + extract)
- `home/.chezmoiexternal.toml.tmpl` — chezmoi-managed clones of repos
  that are used in-place (zinit, kitty kittens, getnf, formerly pyenv/asdf)

The pattern works but accumulates duplication: each new tool means a new
data file + a new run_onchange script that's 90% the same as the last
one. As the count grows (~10 such installers as of writing), the
consolidation conversation became worth having.

## Proposal A — Simple `repositories.yaml` + dispatcher

Original consolidation proposal. Single data file lists git-cloned
tools; single dispatcher script iterates. Chezmoi externals handle the
clone step; the dispatcher only runs the install command.

```yaml
# .chezmoidata/repositories.yaml
repositories:
  - name: bd-timew
    url: git@github.com:AudensAurantius/bd-timew
    ref: v0.1.0
    install: pipx-editable

  - name: graph-send-mail
    url: git@github.com:AudensAurantius/graph-send-mail
    ref: v0.2.3
    install: pipx-editable

  - name: namespaced-openvpn
    url: https://github.com/slingamn/namespaced-openvpn
    ref: master   # or a pinned commit
    install: make
```

Dispatcher (sketch):

```bash
# run_onchange_after_install-repositories.sh.tmpl
# `after_` prefix sequences this AFTER chezmoi externals are applied.
{{- range .repositories }}
  case "{{ .install }}" in
    pipx-editable) pipx install -e "$HOME/.local/src/{{ .name }}" ;;
    make)          (cd "$HOME/.local/src/{{ .name }}" && sudo make install) ;;
    cargo)         (cd "$HOME/.local/src/{{ .name }}" && cargo install --path .) ;;
    *)             echo "unknown install method: {{ .install }}" >&2; exit 1 ;;
  esac
{{- end }}
```

The corresponding `.chezmoiexternal.yaml.tmpl` (templated from the same
data) emits one external per entry, ensuring chezmoi handles the clone
before the dispatcher runs the install.

**Scope:** subsumes git-cloned tools only. Apt, mise, asset downloads,
and pipx tools (the non-editable kind) remain in their existing files.

**Status:** approved in principle but deferred — see
"Recommended path forward" below.

## Proposal B — `pipx:` section in `packages.yaml`

Smaller-scope companion to Proposal A. Pipx tools that aren't editable
git installs (e.g., system tools like `pdm`, `yq`-via-pipx) get a flat
list parallel to the existing `debian:` section in `packages.yaml`,
with optional version pins:

```yaml
packages:
  debian:
    - openssl
    # ...
  pipx:
    - name: pdm
    - name: yq
      install_if_exists: false   # skip if already in apt
    - name: some-tool
      version: "1.2.3"
```

Tracked in **J121-fp6** as a small follow-up to whatever consolidation
shape lands.

**Status:** approved as a small standalone improvement. Does not
require Proposal A first.

## Proposal C — Unified dependency configuration

Counter-proposal expanding scope to **every** dependency mechanism.
Single data file, dispatcher routes to per-method handlers, full
templating support for dynamic values, optional dependency-ordering
metadata.

```yaml
install:
  package_manager:
    - name: adduser
      packages:
        apt: adduser
        dnf: adduser
    - name: apt   # debian-only
      packages:
        apt: [apt, apt-utils]
        # absence of dnf block → skipped on dnf-based distros

  mise:
    builtin:
      python: [3.11.9]
    # rest of existing mise block

  pipx:
    - name: pdm
    - name: yq
      install_if_exists: false
      options: []

  cargo:
    - name: tree-sitter-cli
      # versioning strategy TBD — see open questions

  go:
    - name: beads
      # similar versioning strategy TBD

  assets:
    - name: beadsViewer
      constants:
        version:
          value: "0.15.2"
        platform:
          template:
            path: .chezmoitemplates/platform.yml.tmpl
            arg_scope: global   # global | local | constants
      url:
        printf:
          format_string: "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v%s/bv_%s_%s.tar.gz"
          args: [version, platform, platform]
      checksums:
        linux_amd64: "467c7dee72c599e915d638eb22335a91eb842171eddc2e7baf43129058a7664e"

  git:
    - name: bd-timew
      needs: ["timew", "bd"]   # required executables
      ref:
        tag: v0.1.0
      url: "git@github.com:AudensAurantius/bd-timew"
      clone:
        dest:
          template:
            path: .chezmoitemplates/local-source-dir.yaml.tmpl
            arg_scope: local
        opts: []
      install:
        template:
          path: .chezmoitemplates/pipx-install-editable.sh.tmpl
          arg_scope: local

    - name: zinit
      needs: ["zsh"]
      url: "https://github.com/zdharma-continuum/zinit.git"
      clone:
        dest:
          template:
            path: .chezmoitemplates/zsh-config.yaml.tmpl
            arg_scope: global
```

### Strengths
- **One source of truth** across install methods. Cross-cutting
  reasoning ("which version of X am I running?") becomes a single `yq`
  query.
- **Cross-distro support** via per-package-manager keys —
  future-proofs for eventual Fedora / macOS use.
- **`install_if_exists: false`** solves the deduplication problem
  cleanly (yq-via-apt vs. yq-via-pipx).
- **Templated values** handle version / platform / URL substitution
  declaratively rather than via per-tool installer scripts.
- **`needs:` declarations** make implicit dependencies explicit; could
  enable DAG-based install ordering or pre-flight checks.

### Concerns raised in review

1. **Scope creep.** The original goal was "consolidate
   `run_onchange_install-*` scripts." This expands to "unify every
   dependency mechanism." Each section beyond `git:` is independently
   valuable but doubles the implementation cost. Suggested
   incrementalism: build sections in this order, validating each
   before adding the next:

   1. `git:` (subsumes existing bd-timew/graph-send-mail/wsl-vpn-namespace/getnf/zinit/kitty externals)
   2. `pipx:` (J121-fp6)
   3. `assets:` (subsumes beads_viewer/cheat/cht-sh/dnote/etc — ~10 entries)
   4. Defer `package_manager:` (cross-distro) until non-Debian use
   5. Defer `cargo:` / `go:` until ≥3 entries each — premature
      consolidation otherwise

2. **The dispatcher will outgrow Bash.** With templated value
   resolution (each field can be static OR a Chezmoi-template-as-function),
   multiple `install_if_exists` semantics, DAG ordering, and several
   installer types each with quirks, we're building a small package
   manager. Two viable paths: **(a)** keep dispatcher in Bash by
   constraining templates to "this whole field is a template string"
   (no recursive `template:` blocks); **(b)** rewrite dispatcher in
   Python and bless the complexity.

3. **The `template:` indirection is heavy.** Example:
   ```yaml
   platform:
     template:
       path: .chezmoitemplates/platform.yml.tmpl
       arg_scope: global
   ```
   …is doing the work that Chezmoi's own template engine does for free
   if you write the data file *as a template* (`dependencies.yaml.tmpl`
   with full Chezmoi context). Concretely:
   ```yaml
   # dependencies.yaml.tmpl
   {{- $platform := include ".chezmoitemplates/platform.tmpl" . -}}
   install:
     assets:
       - name: beadsViewer
         version: "0.15.2"
         url: "https://github.com/.../bv_{{ "{{" }} .version {{ "}}" }}_{{ $platform }}.tar.gz"
   ```
   Tradeoff: lose ability to defer template evaluation to dispatch-time.
   But platform/arch don't change between `chezmoi apply` invocations
   on the same machine, so the deferral isn't load-bearing.

4. **DAG ordering for `needs:`** — three options were enumerated:

   1. Auto-install missing deps (changes ordering semantics, breaks
      declarative model)
   2. Process types in declared order, list within type in declared
      order; trust user to declare deps before dependents
   3. Python-based DAG resolver

   Option 2 keeps the dispatcher simple AND keeps the data file
   readable (the order tells you the install order). Option 3 is
   right if cross-section dependencies grow to ≥10; until then it's
   complexity that doesn't pay off.

5. **Specific question answers:**

   - **Bash `printf` named args:** not supported. Skip `printf:` blocks
     entirely; write Go-template strings in the URL field directly.
   - **Cargo / Go versioning when tools need different toolchain versions:**
     don't manage in dependencies.yaml. Use mise (which is already in
     use) — `.tool-versions` files in each project pin the toolchain;
     mise auto-switches. For globally-installed tools, just use the
     system Rust/Go from mise's `latest`. Don't replicate mise's job.
   - **Beads as Go-installable vs. install-script:** beads is on Go;
     `go install github.com/steveyegge/beads/cmd/bd@latest` works.
     Use the Go path; skip the `script` install method for that case.
   - **Checksums varying by version:** no clean way around the manual
     update step. Hold a `checksums:` map keyed by version; bumping
     means adding a new entry. Don't fetch checksums at dispatch time
     — defeats the purpose of pinned hashes for security.

## Recommended path forward (decision: incremental)

The unified Proposal C is conceptually appealing but the implementation
cost — and ongoing maintenance burden of the dispatcher — exceeds the
savings at the current scale (~10 managed tools). Decision recorded
2026-04-30: **stay with the existing per-tool pattern for now**, with
unified consolidation tracked as a roadmap item.

When the consolidation is eventually built, the proposed sequencing:

1. **Phase 1 — `git:` consolidation only.** Implement Proposal A's
   minimal shape (no `template:` indirection, no `needs:`, no recursive
   resolution). Migrate bd-timew, graph-send-mail, getnf, zinit,
   kitty-* (post-cleanup), and add namespaced-openvpn. Validates the
   pattern with ~7 entries.
2. **Phase 2 — `pipx:` section** (J121-fp6).
3. **Phase 3 — `assets:` section.** Use templated `.tmpl` data file
   with `{{ }}` substitution rather than recursive template blocks.
4. **Phase 4 — re-evaluate.** At this point most of the value is
   captured. Defer `package_manager:` (cross-distro) until you actually
   use a non-Debian machine. Defer `cargo:` / `go:` until you have
   ≥3 entries each.

## Open questions for future work

- **Dispatcher language.** Bash for simplicity or Python for
  complexity? Probably Bash up through Phase 3; reconsider before
  adding cross-distro support.
- **Refresh semantics.** Chezmoi externals use `refresh_period` — if
  you bump a `ref:` but the period hasn't elapsed, the external won't
  re-clone. Options: set `refresh_period = "0"` on actively-pinned
  externals (always refresh; cost is one `git fetch` per `chezmoi apply`),
  or add a state-bucket flush when versions change.
- **`install_if_exists` semantics.** Skip-if-binary-on-PATH? Skip-if-
  package-installed-via-other-method? Probably the former — simpler.
- **DAG ordering.** Almost certainly not needed in practice. Declared
  order suffices if the user is reasonable.

## Decision log

- **2026-04-30:** Decided to stay with existing per-tool pattern.
  Captured Proposals A/B/C in this document. Filed bead for the
  overarching unification as a future project.
