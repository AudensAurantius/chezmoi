# WSL2 Setup Considerations

This document captures Windows-side configuration that matters for WSL2
development on this system. Most of it is one-time setup that persists
across reboots, but worth documenting for new machines and post-Windows-Update
verification.

## Disable Large Send Offload (LSO) on the WSL adapter

### Symptom

Long-running TCP sends from WSL stall after the handshake completes — for
example:

- `git push` to GitHub appears to make no network progress despite the
  connection being ESTABLISHED. `ss -tnpi 'dport = :22'` shows
  `bytes_sent` frozen at handshake-size (~5 KB), `lastsnd` climbing into
  hundreds of seconds.
- `dolt push` (or `bd dolt push`) hangs for many minutes with the local
  `dolt` and `dolt sql-server` processes consuming CPU at glacial rates
  (sub-1 KB/s `wchar` in `/proc/<pid>/io`) but the underlying SSH
  connection idle.
- Other long SSH-tunneled bulk transfers (rsync, scp) exhibit the same
  pattern.

### Root cause

Large Send Offload v2 (LSOv2) on the `vEthernet (WSL ...)` adapter
interacts badly with the Hyper-V virtual switch's segmentation. The
adapter advertises support, but for certain TCP flows the segmentation
breaks silently — the kernel hands a 64 KB block to the virtual NIC
expecting hardware segmentation, which then drops or stalls. Path-MTU
discovery falls back to the IPv6 minimum (1280 bytes) and the connection
appears alive but transmits nothing.

This is documented across multiple WSL GitHub issues; the canonical
mitigation is to disable LSOv2 on the WSL adapter so the kernel does the
segmentation itself.

### One-time fix (Administrator PowerShell)

```powershell
# Verify current state (should report Enabled before fix)
Get-NetAdapterAdvancedProperty -Name "vEthernet (WSL*)" -DisplayName "*Large*"

# Disable LSO v2 on both IPv4 and IPv6
Disable-NetAdapterLso -Name "vEthernet (WSL*)" -IPv4 -IPv6

# Confirm
Get-NetAdapterLso -Name "vEthernet (WSL*)"
# Expected: V1IPv4Enabled=False, IPv4Enabled=False, IPv6Enabled=False
```

The setting is registry-persistent and survives `wsl --shutdown` and
Windows reboots. **Verify after major Windows feature updates** —
networking stack resets have been observed.

### Why a GUI walk-through doesn't work

The vEthernet (WSL) adapter is a Hyper-V virtual switch endpoint, not a
physical NIC. Its driver-level Advanced settings are not exposed via the
adapter's Properties dialog (the "Configure" button is greyed out).
PowerShell is the only practical interface.

### Performance trade-off

Disabling LSO costs <5% extra CPU on a single core during sustained
bulk network transfers and is unmeasurable for typical developer
workloads (git, ssh, IDE traffic, web). Production Linux servers on
bonded/virtualized NICs frequently disable LSO for the same reliability
reasons. Net win.

### Apply-time check

`home/run_once_check-wsl-lso.sh.tmpl` queries the LSO state on chezmoi
apply (read-only — no admin needed). It writes a sentinel at
`~/.cache/chezmoi-sentinels/wsl-lso-disabled` recording the verified
state, and prints a loud warning with the fix command if LSO is still
enabled. Re-run via:

```bash
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

if you need to force a re-check (e.g., after a Windows Update).

## Alternative: WSL2 mirrored networking mode

A different mitigation for the same underlying issue (and a few related
WSL networking quirks) is to switch WSL2 to **mirrored mode**, which
bypasses the `vEthernet (WSL)` adapter entirely. WSL traffic then uses
the Windows host's network stack directly.

In `%UserProfile%\.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
```

`wsl --shutdown` from PowerShell, then re-open the WSL session.

**Trade-offs**:
- Requires Windows 11 22H2 or later
- Localhost between Windows and WSL works without port forwarding
- Some VPN clients are incompatible — verify the BOCO VPN setup still
  works before committing
- Some firewall edge cases differ

Not currently in use here; the LSO disable is sufficient for our needs.
This is documented as the escape-hatch alternative if the LSO mitigation
ever proves insufficient.
