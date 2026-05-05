# Home Manager Bootstrap Experiment

A scoped experiment to install Nix + Home Manager on the current WSL2
Ubuntu machine alongside the existing Chezmoi setup, migrate a handful of
representative files and packages, and evaluate fit before committing to
further migration.

**Status:** not started  
**Estimated time:** 2–3 hours for phases 1–3; phase 4 is open-ended

---

## Goals

1. Confirm Nix + Home Manager installs cleanly on this WSL2 machine.
2. Establish a working `flake.nix`-based HM config with version-pinned inputs.
3. Migrate a representative sample of: one module-managed program, a few
   opaque dotfiles, and a few packages currently in `packages.yaml`.
4. Validate the edit→apply workflow and rollback story.
5. Make an informed go/no-go decision on broader migration.

## Non-goals for this experiment

- Migrating all dotfiles or all packages.
- NixOS-WSL (out of scope unless phase 1 fails badly).
- Secrets management (sops-nix / agenix) — evaluate separately.
- Windows package management.

---

## Phase 1 — Install Nix

**Steps:**

```bash
# 1a. Confirm systemd is enabled (needed for nix-daemon service)
cat /etc/wsl.conf
# Expected: [boot] section with systemd=true
# If absent: add it, then `wsl --shutdown` from PowerShell and relaunch.

# 1b. Install Nix via Determinate Systems installer
curl -sSf -L https://install.determinate.systems/nix | sh -s -- install
# Follow prompts; no special flags needed on WSL2.

# 1c. Open a new shell (installer modifies shell profile)
# Verify:
nix --version
nix run nixpkgs#hello
```

**Acceptance criteria:**
- `nix --version` returns a version string.
- `nix run nixpkgs#hello` prints "Hello, world!"
- No errors about the daemon or `/nix` store.

**Rollback if needed:** the Determinate installer provides
`/nix/nix-installer uninstall` — fully removes `/nix` and shell profile
changes.

---

## Phase 2 — Scaffold a Flake-based Home Manager Config

Using flakes from the start avoids migrating later. The config will live at
`~/.config/home-manager/` (HM's default location, separate from the Chezmoi
repo — intentional for now, can be merged later).

```bash
# 2a. Bootstrap the flake
mkdir -p ~/.config/home-manager
cd ~/.config/home-manager
nix run home-manager/master -- init
# Creates flake.nix and home.nix
```

Edit `flake.nix` to pin inputs explicitly (the generated file already does
this with `inputs.home-manager.follows`; verify it looks like the template
below).

**Target `flake.nix` shape:**
```nix
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."hactar" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
```

**Target minimal `home.nix`:**
```nix
{ config, pkgs, ... }: {
  home.username = "hactar";
  home.homeDirectory = "/home/hactar";
  home.stateVersion = "24.11";  # set once, never change
  programs.home-manager.enable = true;
}
```

```bash
# 2b. Apply the empty profile
home-manager switch --flake ~/.config/home-manager#hactar

# 2c. Verify generation exists
home-manager generations
```

**Acceptance criteria:**
- `home-manager switch` completes without errors.
- `home-manager generations` shows one entry.
- `~/.nix-profile/` exists and is a symlink into the store.

---

## Phase 3 — Migrate a Representative Sample

### 3a. One module-managed program: git

The goal is to verify that HM modules work and that the generated file
matches what Chezmoi currently produces.

In `home.nix`, add:
```nix
programs.git = {
  enable = true;
  userName = "Michael Haynes";
  userEmail = "mhaynes@boldorange.com";
  # extraConfig for anything not covered by module options
  extraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
  };
};
```

Before applying:
```bash
# Save current .gitconfig for diff
cp ~/.gitconfig /tmp/gitconfig-before
chezmoi forget ~/.gitconfig   # tell Chezmoi to stop managing it
rm ~/.gitconfig               # remove the real file (now orphaned from Chezmoi)
home-manager switch --flake ~/.config/home-manager#hactar
diff /tmp/gitconfig-before ~/.gitconfig
```

**Acceptance criteria:**
- `~/.gitconfig` is now a symlink into `/nix/store/`.
- Diff shows only expected differences (formatting, section order).
- `git config --list` shows correct values.
- `chezmoi status` does not list `.gitconfig` as managed.

### 3b. Two or three opaque dotfiles via `home.file`

Pick files that are self-contained and low-risk. Good candidates:
- `~/.config/bat/config` (bat theming)
- `~/.tmux.conf` or similar

For each:
```nix
home.file.".config/bat/config".source = ./dotfiles/bat/config;
```

Workflow:
```bash
# Copy current file into HM repo
mkdir -p ~/.config/home-manager/dotfiles/bat
cp ~/.config/bat/config ~/.config/home-manager/dotfiles/bat/config

# Remove from Chezmoi
chezmoi forget ~/.config/bat/config
rm ~/.config/bat/config

# Apply
home-manager switch --flake ~/.config/home-manager#hactar -b backup
# -b backup: backs up any conflicting files as *.backup
```

**Test retroactive edit workflow:**
```bash
# Edit the file directly in the HM repo (this is the "source state")
vim ~/.config/home-manager/dotfiles/bat/config
home-manager switch --flake ~/.config/home-manager#hactar
# Verify change is visible at ~/.config/bat/config
```

**Acceptance criteria:**
- Target file is a symlink into `/nix/store/`.
- Edit-in-repo → switch → change visible at target path.
- `chezmoi status` does not list the file.

### 3c. A few packages from packages.yaml

Pick 3–5 packages currently managed via apt that are stable, non-system:
candidates include `bat`, `ripgrep`, `fd-find` (as `fd`), `jq`, `fzf`.

In `home.nix`:
```nix
home.packages = with pkgs; [
  bat
  ripgrep
  fd
  jq
  fzf
];
```

Before applying, note the current versions:
```bash
bat --version; rg --version; fd --version
```

For each migrated package, remove it from `home/.chezmoidata/packages.yaml`
(debian section). Apply both:
```bash
home-manager switch --flake ~/.config/home-manager#hactar
chezmoi apply   # should not reinstall; packages.yaml no longer lists them
```

**Acceptance criteria:**
- Tools are available and on PATH.
- `which bat` points into `~/.nix-profile/bin/` (or `~/.local/state/nix/...`).
- No version conflicts with anything apt-installed.

---

## Phase 4 — Evaluate and Decide

After phase 3, answer:

1. **Edit workflow:** is "edit source in `~/.config/home-manager/dotfiles/`,
   run switch" comparable in friction to "edit source in chezmoi, `chezmoi apply`"?

2. **Rebuild time:** how long does `home-manager switch` take on this machine
   for a small config? (First run downloads; subsequent runs should be fast
   due to store cache.)

3. **Package coverage:** are any packages in `packages.yaml` missing from
   nixpkgs? (`nix search nixpkgs <name>` for each.)

4. **Coexistence friction:** did any conflicts arise between Chezmoi and HM
   ownership? Are they easy to manage?

5. **`dependency-management-architecture.md` relevance:** given what you've
   seen, does the consolidation work still make sense, or does Nix replace it?

**Decision matrix:**

| Finding | Implication |
|---|---|
| Edit workflow comparable or better | Proceed with broader dotfile migration |
| Rebuild time < 30s for incremental | Acceptable; proceed |
| Rebuild time 1–2 min for incremental | Tolerable but noticeable; factor in |
| Package gaps for key tools | Note them; write derivations or use activation scripts |
| Significant coexistence friction | Slow down; migrate one section at a time |
| Proposal C consolidation still needed | Proceed with Chezmoi consolidation in parallel |
| Proposal C now clearly throwaway | Defer/cancel consolidation bead |

---

## Version Pinning and Repo Integration (future)

Once the experiment validates the approach, the HM config should be moved
into the Chezmoi repo and tracked in git alongside the rest of the dotfiles.
Two options:

**Option A — subdirectory in Chezmoi repo:**
```
home/.config/home-manager/
  flake.nix
  flake.lock
  home.nix
  dotfiles/
    bat/config
    …
```
Chezmoi manages `flake.nix`, `flake.lock`, and `home.nix` as plain files
(no templating needed unless per-host variation is required). `dotfiles/`
subdirectory is also Chezmoi-managed.

**Option B — separate git repo:**
`~/.config/home-manager/` is its own repo, separate from Chezmoi. Simpler
boundary; more repos to manage. Reasonable if HM config grows large.

Recommendation: start with Option A. The Chezmoi repo already tracks
`~/.config/` paths; adding a `home-manager/` subdirectory is natural.
`flake.lock` should be committed and updated deliberately (like
`package-lock.json`).

---

## Reference Commands

```bash
# Install / uninstall Nix
curl -sSf -L https://install.determinate.systems/nix | sh -s -- install
/nix/nix-installer uninstall

# Home Manager operations
home-manager switch --flake ~/.config/home-manager#hactar
home-manager switch --flake ~/.config/home-manager#hactar -b backup
home-manager generations
home-manager news --flake ~/.config/home-manager#hactar

# Update flake inputs (bump nixpkgs/HM versions)
nix flake update ~/.config/home-manager
# then: home-manager switch ...

# Garbage-collect old generations
home-manager expire-generations "-30 days"
nix store gc

# Search packages
nix search nixpkgs ripgrep
nix-env -qaP | grep ripgrep   # older-style search
```
