# Nix / Home Manager Exploration

Conversation transcript: 2026-05-04. Explores Nix and Home Manager as
alternatives or complements to Chezmoi for dotfiles and package management.
No decisions recorded yet — this document captures the research conversation
so we can revisit without re-deriving.

---

## Motivation

Chezmoi has been working well but some aspects are awkward or nonintuitive.
The dependency-management-architecture.md doc captures ongoing work to
consolidate the `run_onchange_install-*.sh.tmpl` proliferation. A
parallel question: is there a better foundation based on Nix or Cue?

---

## Nix-Based Alternatives

**Home Manager** — the dominant option. Declarative user-environment manager
built on Nix. Manages dotfiles *and* the packages that consume them in a
single config. Modules for hundreds of programs generate dotfiles from
type-checked options. Works standalone on any Linux/macOS with Nix installed;
does not require NixOS.

**nix-darwin** — macOS system config; usually paired with Home Manager.

**Flakes** — not a dotfiles tool, but the modern way to pin and share Nix
configs reproducibly across machines.

## Cue-Based Alternatives

No mature, widely-adopted Cue-based dotfiles manager exists. Cue is used
heavily for Kubernetes/config validation but the dotfiles ecosystem hasn't
coalesced around it. Using Cue for dotfiles means maintaining a custom
schema + generator script. Viable but you're the maintainer.

---

## Chezmoi vs. Home Manager — Trade-off Table

| Dimension | Chezmoi | Home Manager (Nix) |
|---|---|---|
| Install footprint | Single Go binary, ~15MB | Nix store, GBs; non-trivial bootstrap |
| Scope | Files only (+ scripts) | Files **and** packages, services, fonts, shells |
| Templating | Go templates — ad hoc, stringly-typed | Nix language — typed, lazy, composable |
| Reproducibility | Source tree + machine state; templates can drift | Pinned inputs → bit-identical rebuild |
| Secrets | First-class (age, 1Password, Bitwarden, …) | Possible (sops-nix, agenix) but more setup |
| Per-host variation | `.chezmoi.toml` data + `{{ if eq .chezmoi.hostname … }}` | Modules + `lib.mkIf`, cleaner at scale |
| Learning curve | Low — it's just files with templates | Steep — Nix language + module system |
| Editing a dotfile | Edit the file, `chezmoi apply` | Edit Nix expr, `home-manager switch` (rebuild) |
| Escape hatch for upstream-shaped config | Trivial (it's the file) | Awkward when no HM module exists |
| Works without OS buy-in | Yes, anywhere | Requires Nix; corp/locked-down machines often a no-go |
| Rollback | Git revert + apply | `home-manager generations` + atomic switch |

The "awkward or nonintuitive" parts of Chezmoi (Go template gymnastics,
`chezmoi edit` vs editing in place, source-state vs target-state confusion,
the worktree-vs-canonical pitfall) do not go away with Cue, and only
partially go away with Nix — Nix trades them for a different, larger set
of awkward parts (the language, IFD, evaluation errors, the rebuild cycle).

**Home Manager is genuinely better than Chezmoi if:**
- You also want package/service management unified with dotfiles, AND
- You're willing to invest time in Nix (acceptable for this user).

---

## Detailed Q&A

### Bootstrap on WSL — how nontrivial?

Very tractable on WSL2. ~20 minutes start-to-working.

**Recommended installer:** Determinate Systems
(`curl -sSf -L https://install.determinate.systems/nix | sh -s -- install`).
Handles WSL detection, enables flakes by default, sets up daemon correctly,
provides clean uninstaller. Prefer over upstream installer.

**WSL2 caveats:**
- Installer wants `nix-daemon` as a systemd service. Requires
  `/etc/wsl.conf` to have `[boot]\nsystemd=true`. If absent, falls back to
  socket-activation mode (works fine).
- `/nix` lives on the ext4 WSL disk. Plan for 5–10 GB once a real HM
  profile is installed. `nix store gc` reclaims space.
- No conflict with Chezmoi or anything else; purely additive until config
  is written.

**After install:** `nix run home-manager/master -- init --switch` scaffolds
`~/.config/home-manager/home.nix` and applies an empty profile.

### Edit-target-then-import workflow

Home Manager has two modes that can be mixed per-file:

**Mode A — opaque file management (the Chezmoi-equivalent path):**
```nix
home.file.".config/kitty/kitty.conf".source = ./dotfiles/kitty.conf;
xdg.configFile."nvim/init.lua".source = ./dotfiles/nvim/init.lua;
home.file.".gitconfig".text = ''
  [user]
    email = mhaynes@boldorange.com
'';
```
Retroactive import: copy the file into the Nix repo, add a `home.file` line,
run `home-manager switch -b backup` (backs up the existing file as `*.backup`,
then symlinks).

**Mode B — typed modules:**
```nix
programs.git.enable = true;
programs.git.userEmail = "mhaynes@boldorange.com";
```
HM generates the file from typed options. Edit the Nix expression, not the
target file.

You don't have to pick one. Common pattern: use modules for things with good
HM coverage (git, ssh, zsh, tmux, kitty, neovim), use `home.file` for
everything else.

### Custom modules / non-nixpkgs installs

**Writing a HM module** (adding `programs.myThing.*` typed options): 50–150
lines of Nix, medium effort. Almost never needed for personal dotfiles —
`home.file` is sufficient.

**Installing software not in nixpkgs** — three escape hatches:

1. **Check nixpkgs first.** ~100k packages. Most dev tools are there
   (timewarrior, taskwarrior, chezmoi, mise, pipx, etc.).

2. **Write a derivation.** For a Go tool: ~10 lines. For "clone and make
   install": ~15 lines of `stdenv.mkDerivation`. Output goes in the Nix
   store, symlinked into your profile.
   ```nix
   pkgs.stdenv.mkDerivation {
     name = "my-tool";
     src = pkgs.fetchFromGitHub { owner = "…"; repo = "…"; rev = "v1.0"; sha256 = "…"; };
     buildPhase = "make";
     installPhase = "make install PREFIX=$out";
   }
   ```

3. **`home.activation` scripts** — arbitrary bash after every
   `home-manager switch`. Equivalent to `run_onchange_install-*.sh.tmpl`.
   Functional but opts out of Nix's reproducibility guarantees.
   ```nix
   home.activation.installBdTimew = lib.hm.dag.entryAfter ["writeBoundary"] ''
     if [ ! -d $HOME/.local/src/bd-timew ]; then
       git clone … $HOME/.local/src/bd-timew
     fi
     (cd $HOME/.local/src/bd-timew && pipx install -e .)
   '';
   ```

**Implication for dependency-management-architecture.md:**
Proposal C is roughly "reinvent a small Nix in YAML+Bash." If Nix is the
eventual destination, the consolidation work may be partly throwaway:
- `git:` section → `fetchFromGitHub` derivations or flake inputs
- `assets:` section → `fetchurl { url = "…"; sha256 = "…"; }`
- `pipx:/package_manager:/mise:` sections → largely dissolve into `home.packages`
- DAG ordering → disappears (Nix derivation `buildInputs` is the DAG)

### Generational rollback

Each `home-manager switch`:
1. Builds a new generation in `/nix/store/<hash>-home-manager-generation/`
2. Atomically swaps `~/.local/state/nix/profiles/home-manager` symlink
3. Symlinks in `$HOME` update to point at new store paths

Old generations are kept until garbage-collected. Rollback:
```
home-manager generations             # list timestamps + store paths
/nix/store/<hash>/activate           # activate a specific old generation
```
The switch is all-or-nothing: if the new generation fails to build, `$HOME`
is untouched. Stronger guarantee than Chezmoi's apply (which can fail
partway through).

### Parallel Chezmoi + Nix during migration

Fully viable. They only conflict if both claim the same path.

**Mechanics:**
- For each migrated file: `chezmoi forget` + delete from source, add `home.file`
  line, run `home-manager switch -b backup`.
- **Rule:** own each file from exactly one tool.
- Audit: `chezmoi managed | sort` vs. `ls -la ~ ~/.config | grep '/nix/store'`

**Reasonable migration order:**
1. Bootstrap Nix + HM with empty profile. Verify nothing breaks.
2. Migrate one easy module-backed file (e.g., `programs.git`).
3. Migrate package installation — replace one apt package with
   `home.packages = [ pkgs.foo ]`, observe, repeat. This is where Chezmoi
   shrinks fastest.
4. Migrate dotfile bulk last (Chezmoi is best here, least urgent).
5. Retire `dependency-management-architecture.md` consolidation work — most
   of it becomes moot under Nix.

**Terminal state option:** "Chezmoi for dotfiles, Nix for packages" is a
valid non-transitional destination, not just a migration phase.

---

## System Files (/etc) Management

**On NixOS:** first-class, ergonomic:
```nix
environment.etc."hosts".text = ''…'';
environment.etc."ssh/sshd_config".source = ./sshd_config;
```
Generated atomically on `nixos-rebuild switch`, generational rollback
included. Genuinely better than Chezmoi's `run_onchange` + hash approach.

**On non-NixOS (current WSL Ubuntu) + Home Manager:** HM is `$HOME`-scoped
only. `/etc` management does not improve.

**NixOS-WSL option:** [nix-community/NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
replaces the Ubuntu WSL distro with NixOS. Full `configuration.nix`
including `environment.etc.*`. Bigger commitment than HM on Ubuntu; worth
considering if system-file management is a significant pain point.

**Font management note:** `sync-nfs` / Windows registry sync stays as-is
regardless of Nix migration — the awkwardness is on the Windows side
(HKCU registration, `cmd.exe` bridging), not the Linux side. HM can install
Nerd Fonts to `~/.local/share/fonts` cleanly:
```nix
fonts.fontconfig.enable = true;
home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
```
…but the WSL→Windows half of the workflow is unaffected.

---

## Windows Package Management

Nix offers no Windows package management. Three options:

**[Scoop](https://scoop.sh)** — closest to "developer package manager for
Windows":
- User-space install, no admin required, no UAC prompts
- `scoop export` / `scoop import packages.json` — clean Chezmoi integration
- Buckets (package repos) are git repos

**[winget](https://github.com/microsoft/winget-cli)** — built into Windows 11:
- Zero bootstrap: already present on fresh installs
- `winget export -o packages.json` / `winget import -i packages.json`

**[Chocolatey](https://chocolatey.org)** — older, more packages, requires
admin for most installs. Less appealing for personal use.

**Recommended:** use both Scoop and winget — complementary, not competing.
Winget for mainstream catalog items (VS Code, browsers); Scoop for
developer-specific/user-space installs.

### Chezmoi integration sketch

```
home/
  .chezmoidata/
    windows-packages.yaml
  run_once_install-windows.ps1.tmpl
```

```yaml
# windows-packages.yaml
scoop:
  buckets: [extras, nerd-fonts]
  packages:
    - git
    - neovim
    - ripgrep
    - "nerd-fonts/JetBrainsMono-NF"
winget:
  packages:
    - Microsoft.VisualStudioCode
    - 7zip.7zip
```

```powershell
# run_once_install-windows.ps1.tmpl
{{- if eq .chezmoi.os "windows" }}
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    irm get.scoop.sh | iex
}
{{ range .scoop.buckets -}}
scoop bucket add {{ . }}
{{ end -}}
{{ range .scoop.packages -}}
scoop install {{ . }}
{{ end -}}
{{ range .winget.packages -}}
winget install --id {{ . }} --silent --accept-package-agreements
{{ end -}}
{{- end }}
```

### Fresh-install workflow

```
winget install twpayne.chezmoi Git.Git
chezmoi init --apply <your-repo-url>
```

`chezmoi init --apply` clones the repo and runs all `run_once_` scripts in
one command — installs Scoop, installs both package lists, lays down all
dotfiles.

---

## Open Questions / Next Steps

- See `docs/home-manager-bootstrap-experiment.md` for a scoped
  install-and-validate experiment on the current WSL Ubuntu machine.
- Decision: if/when to pursue NixOS-WSL vs. staying on Ubuntu + HM.
- Decision: at what point (if ever) does the dependency-management
  consolidation work get abandoned in favor of Nix migration?
