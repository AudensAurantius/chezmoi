# TODO

- [ ] Add `mono` and deps to installation scripts
  - [ ] `Azure.Artifacts.CredentialProvider`
  - [link to download page](https://www.mono-project.com/download/stable/)
- [ ] Templatize LSP `mono` LSP config
- [ ] Figure out better way to sync /etc/ files
  - [ ] enumerate all relevant /etc/ files
- [ ] Add `wslu` repo and package installation to run_onchange script
- [ ] Refine firenvim setup
  - [ ] resolve `noice` errors
  - [ ] set ft depending on site
  - [ ] configure site blacklist / whitelist
- [ ] Bookmark / knowledge base extensions?

## OpenVPN on WSL2 (2026-04-14)

Goal: run VPN inside WSL2 network namespace so only specific CLI commands
(e.g., `snow`) use the tunnel. Windows VPN client stays off for daily work.

### Static /etc/resolv.conf (DNS race condition fix)
- [ ] Add `[network] generateResolvConf = false` to `/etc/wsl.conf`
- [ ] Create static `/etc/resolv.conf`:
      ```
      nameserver 10.255.255.254
      nameserver 8.8.8.8
      search boldorange.local greatclips.loc
      ```
      First nameserver is BOCO DNS (works when Windows VPN is on or when
      WSL2 namespace VPN is on). Second is Google fallback (covers the case
      where BOCO DNS is unreachable — e.g., VPN off, or the NAT race
      condition after reboot). Tradeoff: ~5s timeout on first nameserver
      when VPN is completely off before falling back to Google.
- [ ] Manage via chezmoi (template or exact file) — needs `root` ownership,
      so may require a `run_once` script rather than a direct chezmoi target
- [ ] Test: `wsl --shutdown`, relaunch, verify resolv.conf persists and DNS
      works with VPN both on and off

### Install packages
- [ ] `sudo apt install openvpn resolvconf oath-toolkit dnsutils`
- [ ] Add to chezmoi `run_once_before_install.sh` or equivalent

### Copy and secure .ovpn profile
- [ ] `mkdir -p ~/.config/openvpn && chmod 700 ~/.config/openvpn`
- [ ] Copy from `/mnt/c/Users/mhaynes/AppData/Roaming/OpenVPN Connect/profiles/1718981523912.ovpn`
      to `~/.config/openvpn/boco.ovpn`, `chmod 600`
- [ ] Decide: manage via chezmoi (encrypted) or keep out-of-band?

### Store VPN credentials in pass
- [ ] Choose pass entry path (e.g., `work/boco/vpn`)
- [ ] Store: password (line 1), `user: mhaynes`, `otp: <base32 TOTP seed>`
- [ ] To get TOTP seed: log into https://connect.boldorange.com, re-enroll
      MFA, capture the secret (QR code or manual key) before scanning with
      phone authenticator
- [ ] Verify: `oathtool --totp --base32 $(pass show work/boco/vpn | grep otp | cut -d' ' -f2)`
      should produce a valid 6-digit code

### Auth automation script
- [ ] Write `~/.local/bin/vpn-auth-helper` (or integrate into main script):
      1. Read username, password, OTP seed from `pass`
      2. Generate TOTP via `oathtool --totp --base32 <seed>`
      3. Construct SCRV1 string: `SCRV1:<base64(password)>:<base64(otp)>`
      4. Write temp auth file (mktemp, chmod 600): line 1 = username, line 2 = SCRV1 string
      5. Return path to temp file (caller is responsible for shredding)
- [ ] SCRV1 format is how OpenVPN encodes static-challenge responses — not a
      hack, it's the protocol. Avoids need for `expect`.
- [ ] Test SCRV1 auth against BOCO Access Server before building namespace script

### Network namespace setup script
- [ ] Write `~/.local/bin/vpn-connect` (run as root or via sudo):
      1. Create namespace: `ip netns add vpn`
      2. Create veth pair: `ip link add veth-vpn type veth peer name veth-vpn-br`
         - veth = "virtual ethernet", always created in pairs, what goes in one
           end comes out the other — it's a cable connecting two namespaces
      3. Move one end into namespace: `ip link set veth-vpn-br netns vpn`
      4. Assign IPs (e.g., host=10.200.0.1/24, ns=10.200.0.2/24), bring up
      5. Set default route inside namespace: `ip route add default via 10.200.0.1`
      6. Enable IP forwarding: `sysctl -w net.ipv4.ip_forward=1`
         - Tells kernel to forward packets between interfaces (default: drop).
           Non-persistent (reverts on reboot). Minimal risk in WSL2 since eth0
           only connects to Windows host's virtual NAT — no real second network
           to leak to. Watch for Docker bridge interactions if concerned.
      7. Enable NAT: `iptables -t nat -A POSTROUTING -s 10.200.0.0/24 -o eth0 -j MASQUERADE`
         - Rewrites source IP of namespace packets to host's eth0 IP so replies
           can find their way back. Same thing a home router does. Non-persistent.
           Scoped to 10.200.0.0/24 only — verify this range doesn't collide
           (`ip route` to check).
      8. Copy resolv.conf into namespace: namespace has its own `/etc/resolv.conf`
         context via `mount --bind`
      9. Start OpenVPN inside namespace:
         `ip netns exec vpn openvpn --config ~/.config/openvpn/boco.ovpn --auth-user-pass <authfile> --script-security 2 --up /etc/openvpn/update-resolv-conf --down /etc/openvpn/update-resolv-conf`
      10. OpenVPN's `--up` / `--down` scripts handle DNS inside the namespace:
          `update-resolv-conf` rewrites `/etc/resolv.conf` with server-pushed
          DNS when tunnel comes up, restores original when tunnel goes down.
          Needs `resolvconf` package installed.
- [ ] Write `~/.local/bin/vpn-disconnect` (cleanup):
      1. Kill OpenVPN process
      2. Remove iptables NAT rule
      3. Disable IP forwarding: `sysctl -w net.ipv4.ip_forward=0`
      4. Delete namespace: `ip netns del vpn` (also removes veth pair)
      5. Shred auth temp file if still present
- [ ] Write `~/.local/bin/vpn-exec` convenience wrapper:
      `sudo ip netns exec vpn sudo -u $USER "$@"`
      Usage: `vpn-exec snow connection test -c J121-prod`
- [ ] Manage scripts via chezmoi (`exact_dot_local/bin/` or similar)

### DNS inside the namespace
- [ ] The `update-resolv-conf` script (from `openvpn` package, lives at
      `/etc/openvpn/update-resolv-conf`) uses `resolvconf` to apply server-pushed
      DNS settings. It runs inside the namespace context, so it only affects
      DNS resolution for processes in that namespace.
- [ ] Alternatively, write a simpler `--up` script that just writes a
      namespace-specific resolv.conf via bind mount (avoids resolvconf dependency)
- [ ] Test: `vpn-exec dig google.com` should resolve; `dig google.com` (outside
      namespace) should also resolve but via different nameserver

### Split tunneling on Windows (for reference, not a TODO)
Decision: NOT pursuing Windows-side split tunneling. Reasons:
- Windows has no source-based routing (can't exempt WSL2 traffic when VPN is on)
- Per-destination split tunnel requires server-side config (BOCO VPN admin) or
  client-side `route-nopull` + manual routes (fragile for Snowflake: dynamic IPs)
- Per-application routing requires third-party software (Proxifier, commercial)
- Simpler workflow: use Windows VPN only when browser needs Snowflake Web UI;
  use WSL2 namespace VPN for CLI tools. Rarely need both simultaneously.
- When Windows VPN IS on, WSL2 traffic goes through it too (NAT'd by WinNAT,
  indistinguishable from Windows-native traffic). Minor extra latency, not a
  functional problem — especially with the static resolv.conf DNS fix in place.

### Dual VPN sessions (for reference)
- Windows VPN + WSL2 namespace VPN are independent TLS sessions
- BOCO Access Server may limit one concurrent session per user — second
  connection could kick the first. Test before relying on both simultaneously.
- If concurrent sessions work, traffic is VPN-inside-VPN (wasteful, extra
  latency, but functional). Better to just use Windows VPN for both in that case.
