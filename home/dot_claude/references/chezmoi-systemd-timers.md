# Chezmoi systemd-user timer patterns

Reference for adding systemd-user service + timer units under Chezmoi management. The canonical examples live in `home/dot_config/systemd/user/timew-autostop.{service,timer}.tmpl` and `home/dot_config/systemd/user/timew-nudge.{service,timer}.tmpl`.

This doc codifies the conventions used there so new timers (e.g., `/reminder`, `/timebox`, other periodic housekeeping units) follow the same shape.

## File layout

```
home/dot_config/systemd/user/
  <name>.service.tmpl        # what to run
  <name>.timer.tmpl          # when to run it
home/dot_local/bin/
  executable_<name>.tmpl     # the actual script invoked by the service
home/run_onchange_after_reload-systemd-user.sh.tmpl
                             # reloads + enables timers after any change
```

## Template guards on dependencies

Every file should refuse to render on machines missing its runtime deps. Unit files guard on both the binary being invoked **and** its upstream tool if any:

```gotmpl
{{ if and (lookPath "timew") (lookPath "timew-autostop") -}}
[Unit]
Description=...
...
{{- end }}
```

Scripts guard on the top-level tool:

```gotmpl
{{ if lookPath "timew" -}}
#!/usr/bin/env bash
...
{{- end }}
```

If a guard fails, Chezmoi renders an empty file — which Chezmoi then treats as "unmanaged on this host" and skips. Don't add runtime `command -v` checks for dependencies that the template already guarded; only use runtime checks for truly optional components (see `.notifier` below).

## `%h` over `{{ .chezmoi.homeDir }}` in unit files

Use systemd's `%h` specifier for home-dir paths in unit files rather than baking `{{ .chezmoi.homeDir }}` at Chezmoi apply time:

```gotmpl
ExecStart=%h{{ trimPrefix .chezmoi.homeDir (lookPath "timew-autostop") }}
```

`%h` resolves at systemctl activation time. If the rendered unit is copied between users (or if `$HOME` changes), behavior stays correct. The `trimPrefix` makes `lookPath`'s absolute result home-relative so it composes with `%h`. Scripts themselves can use `$HOME` normally — the `%h` preference is specific to unit files.

## The `.notifier` abstraction

Desktop notifications differ by platform: `wsl-notify-send` on WSL, `notify-send` on native Linux. Don't branch inside every script — use the `.notifier` data variable defined in `.chezmoi.yml.tmpl`:

```gotmpl
if command -v {{ .notifier }} >/dev/null 2>&1; then
    {{ .notifier }} "title" "message"
fi
```

`.notifier` resolves by inspecting `.chezmoi.kernel.osrelease` and checking whether the WSL-specific wrapper source exists. The runtime `command -v` guard covers the corner case where the resolved tool isn't actually installed on the target.

## The reload script

`home/run_onchange_after_reload-systemd-user.sh.tmpl` reloads systemd and enables all timers after any change to files under `dot_config/systemd/user/`. It uses the `run_onchange_after_` prefix plus a hash-comments block at the top to make Chezmoi retrigger it when any source file changes:

```gotmpl
{{ range (glob (joinPath .chezmoi.sourceDir "dot_config/systemd/user/*")) -}}
# hash: {{ . }}: {{ include . | sha256sum }}
{{ end }}
```

The script is idempotent (`systemctl enable --now` is safe on already-enabled timers). It conditionally calls `loginctl enable-linger $USER` when the `enable_systemd_session_services` flag in `.chezmoi.yml.tmpl` is true for the current host.

**Known gap:** the reload script doesn't disable timers that were removed from source. If you delete a `.timer.tmpl` file, the enabled symlink in `~/.config/systemd/user/timers.target.wants/` will persist until manually removed with `systemctl --user disable <name>.timer`.

## Checklist for adding a new timer

1. Script at `home/dot_local/bin/executable_<name>.tmpl` with a `lookPath` template guard on the top-level tool it invokes. Scripts must be idempotent — they may fire before dependent state exists.
2. Service unit at `home/dot_config/systemd/user/<name>.service.tmpl`:
   - Guard on both the upstream tool and the script itself
   - `Type=oneshot` for periodic runs
   - `ExecStart=%h<home-relative-path>` using `trimPrefix` against `lookPath`
   - `Documentation=file://%h/.local/share/chezmoi/home/dot_local/bin/executable_<name>.tmpl` pointing at the source
3. Timer unit at `home/dot_config/systemd/user/<name>.timer.tmpl`:
   - Guard matches the service guard
   - `OnCalendar=...` or `OnBootSec=...` schedule
   - `Persistent=true` if the timer should fire on next login after a missed scheduled time
   - `WantedBy=timers.target` in `[Install]`
4. Run `chezmoi apply`. The `run_onchange_after_reload-systemd-user.sh.tmpl` script will daemon-reload, optionally enable lingering, and enable the new timer.
5. Verify: `systemctl --user list-timers | grep <name>`.
6. Commit in the Chezmoi repo with a conventional message scoped `timew`, `systemd`, or the domain of the timer.

## Lingering (`enable_systemd_session_services`)

`loginctl enable-linger $USER` lets user timers fire without an active login session — required for housekeeping that should run regardless of whether the user is logged in. The per-host flag in `.chezmoi.yml.tmpl` tracks which machines have this enabled; the reload script will try `sudo loginctl enable-linger` on hosts where the flag is true and lingering is not yet set. If sudo is non-interactive and unavailable, the script prints a hint rather than failing.

## Related

- Canonical examples: `home/dot_config/systemd/user/timew-autostop.{service,timer}.tmpl`, `home/dot_config/systemd/user/timew-nudge.{service,timer}.tmpl`
- Reload script: `home/run_onchange_after_reload-systemd-user.sh.tmpl`
- `.chezmoi.yml.tmpl` — hosts `.notifier`, `.enable_systemd_session_services`, and other cross-cutting data variables
- General Chezmoi patterns (`~/.local/bin` discipline, etc.): auto-memory `feedback-chezmoi-patterns.md` — to be migrated to `~/.claude/references/chezmoi-patterns.md` when the Chezmoi skill lands (J121-9kp.2.11)
