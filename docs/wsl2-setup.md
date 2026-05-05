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
mitigation is to disable LSOv2 so the kernel does the segmentation
itself.

### Critical: disable on BOTH the virtual AND physical adapters

WSL traffic egresses through the `vEthernet (WSL ...)` adapter AND then
through the physical NIC (e.g., `Ethernet 7`, `Ethernet`, `Wi-Fi`).
**LSO must be disabled on both** — a broken offload on either one
poisons the connection. Disabling only the virtual adapter reduces the
stall but does not eliminate it; verified empirically 2026-05-05 (dolt
push still hit retransmit storm with `bytes_retrans/bytes_sent ≈ 59%`
until the physical adapter's LSO was also disabled).

### One-time fix (Administrator PowerShell)

```powershell
# 1. Identify your physical adapter(s) — the non-virtual ones
Get-NetAdapter | Where-Object Virtual -eq $false |
  Select Name, InterfaceDescription, Status

# 2. Verify current LSO state across all adapters
Get-NetAdapterLso

# 3. Disable LSO on the WSL virtual adapter
Disable-NetAdapterLso -Name "vEthernet (WSL*)" -IPv4 -IPv6

# 4. Disable LSO on the physical adapter(s) carrying outbound traffic.
#    Substitute the actual name(s) from step 1.
Disable-NetAdapterLso -Name "Ethernet 7" -IPv4 -IPv6
# If you also use Wi-Fi:
# Disable-NetAdapterLso -Name "Wi-Fi" -IPv4 -IPv6

# 5. Confirm — every adapter you use should report all False
Get-NetAdapterLso
```

The settings are registry-persistent per adapter and survive
`wsl --shutdown` and Windows reboots. **Verify after major Windows
feature updates** — networking stack resets have been observed.

If you switch between Ethernet and Wi-Fi (e.g., dock vs. mobile), make
sure LSO is disabled on every physical adapter you use, not just the
currently-active one.

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
