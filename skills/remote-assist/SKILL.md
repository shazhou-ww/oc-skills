---
name: remote-assist
description: "Remote SSH assistance via Cloudflare Quick Tunnel. One-command workflow to establish temporary SSH access to a remote machine for troubleshooting. Usage: /remote-assist [tunnel-host] [--user username]. Without args, guides the remote user through bootstrap. With tunnel host, connects immediately."
user-invocable: true
---

# Remote Assist

Establish temporary SSH access to a remote machine via Cloudflare Quick Tunnel for troubleshooting.

## Flow

### Phase 1: Bootstrap (no args or just `/remote-assist`)

1. Send the remote user the universal bootstrap command:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/shazhou-ww/oc-bootstrap/main/bootstrap.sh)
   ```
2. Also send your SSH public key for them to add manually if the bootstrap script doesn't include it:
   ```bash
   # Read from ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub
   ```
3. Wait for the user to reply with:
   - **Tunnel hostname** (e.g. `abc-def-ghi.trycloudflare.com`)
   - **Username** (e.g. `azureuser`)

### Phase 2: Connect (`/remote-assist <tunnel-host> --user <username>`)

1. Kill any existing cloudflared proxy on port 2222:
   ```bash
   pkill -f "cloudflared access tcp.*localhost:2222" 2>/dev/null || true
   ```

2. Start local proxy (background):
   ```bash
   cloudflared access tcp --hostname <tunnel-host> --url localhost:2222 &
   ```

3. Wait 3 seconds, then test SSH:
   ```bash
   ssh -p 2222 -o StrictHostKeyChecking=no -o ConnectTimeout=10 <user>@localhost "echo OK; hostname; uname -a"
   ```

4. If SSH fails with `Permission denied (publickey)`:
   - Ask the remote user to add your public key:
     ```bash
     echo "<your-pubkey>" >> ~/.ssh/authorized_keys
     ```
   - Retry SSH after they confirm

5. Once connected, report success and begin troubleshooting.

### Phase 3: Troubleshoot

Common checks to run on the remote machine:

```bash
# OpenClaw status
~/.openclaw/bin/openclaw gateway status 2>&1
~/.openclaw/bin/openclaw status 2>&1

# Recent logs
tail -50 /tmp/openclaw/openclaw-$(date -u +%Y-%m-%d).log

# Service status
systemctl --user status openclaw-gateway
systemctl --user status copilot-api

# Model connectivity
curl -s http://127.0.0.1:4141/v1/models | head -5
```

### Phase 4: Cleanup

After troubleshooting:
- Kill the local cloudflared proxy: `pkill -f "cloudflared access tcp.*localhost:2222"`
- Inform the remote user they can close their tunnel (Ctrl+C)
- Note: SSH public key remains in their authorized_keys for future sessions

## Prerequisites

- `cloudflared` installed locally
- SSH key pair (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)

## Bootstrap Script Repo

https://github.com/shazhou-ww/oc-bootstrap

Supported platforms:
- macOS (Intel + Apple Silicon)
- Ubuntu / Debian / WSL2
- Universal router: auto-detects OS

## Important

- **Always ask the remote user's OS** before sending a specific script
- Each machine should use its own credentials (GitHub, API keys) — never share keys across machines
- Quick Tunnel URLs are temporary — they die when the process stops
- The bootstrap script injects KUMA's public key by default; you may need to add your own key separately
