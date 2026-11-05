#!/bin/bash
# Starts the relay on every start of the codespace, with the keys the app saved as the user's codespace secrets.
# The app makes port 8080 public; until then the relay keeps retrying its own address.
set -u
if [ -z "${MT_RELAY_AUTH_KEY:-}" ] || [ -z "${MT_RELAY_NODE_KEY:-}" ]; then
  echo "No relay keys: set them up from the Mailbox Tunnel app."
  exit 0
fi
# postStartCommand does not always see the codespace's variables, so they are read from the file Codespaces keeps them in.
if [ -z "${CODESPACE_NAME:-}" ]; then
  variables=/workspaces/.codespaces/shared/environment-variables.json
  CODESPACE_NAME=$(sed -n 's/.*"CODESPACE_NAME": *"\([^"]*\)".*/\1/p' "$variables")
  GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=$(sed -n 's/.*"GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN": *"\([^"]*\)".*/\1/p' "$variables")
fi
domain=${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}
repo=${GITHUB_REPOSITORY:-$(git -C "$(dirname "$0")" config --get remote.origin.url | sed 's#.*github.com/##; s#\.git$##')}
binary=/tmp/mailbox-tunnel
# The newest release that has the Linux binary; app releases in the same repository may not.
url=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=30" | grep -o '"browser_download_url": *"[^"]*/mailbox-tunnel-linux-amd64"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
for attempt in 1 2 3; do
  curl -fsSL -o "$binary" "$url" && break
  sleep 10
done
chmod +x "$binary"
pkill -x mailbox-tunnel
MAILBOX_AUTH_KEY=$MT_RELAY_AUTH_KEY MAILBOX_NODE_KEY=$MT_RELAY_NODE_KEY \
  setsid nohup "$binary" -mode relay -listen :8080 -deployment "$CODESPACE_NAME-8080.$domain" > /tmp/relay.log 2>&1 < /dev/null &
echo "Relay started at $CODESPACE_NAME-8080.$domain."
