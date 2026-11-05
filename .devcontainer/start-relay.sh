#!/bin/bash
# Starts the relay on every start of the codespace, with the keys the app saved as the user's codespace secrets.
# The app makes port 8080 public; until then the relay keeps retrying its own address.
set -u
if [ -z "${MT_RELAY_AUTH_KEY:-}" ] || [ -z "${MT_RELAY_NODE_KEY:-}" ]; then
  echo "No relay keys: set them up from the Mailbox Tunnel app."
  exit 0
fi
# postStartCommand does not always see the codespace's variables, so they are read from the file Codespaces keeps them in.
variable() {
  sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" /workspaces/.codespaces/shared/environment-variables.json 2>/dev/null
}
CODESPACE_NAME=${CODESPACE_NAME:-$(variable CODESPACE_NAME)}
domain=${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-$(variable GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN)}
domain=${domain:-app.github.dev}
origin() {
  git -C "$1" config --get remote.origin.url 2>/dev/null | sed 's#.*github.com[/:]##; s#\.git$##'
}
repo=${GITHUB_REPOSITORY:-$(origin "$(dirname "$0")")}
repo=${repo:-$(origin .)}
binary=/tmp/mailbox-tunnel
# The newest release that has the Linux binary; app releases in the same repository may not.
releases=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=30")
url=$(echo "$releases" | grep -o '"browser_download_url": *"[^"]*/mailbox-tunnel-linux-amd64"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
# A running binary cannot be overwritten, so the download is moved into place.
for attempt in 1 2 3; do
  curl -fsSL -o "$binary.new" "$url" && break
  sleep 10
done
if [ -s "$binary.new" ]; then
  chmod +x "$binary.new"
  mv -f "$binary.new" "$binary"
fi
pkill -x mailbox-tunnel
MAILBOX_AUTH_KEY=$MT_RELAY_AUTH_KEY MAILBOX_NODE_KEY=$MT_RELAY_NODE_KEY \
  setsid nohup "$binary" -mode relay -listen :8080 -deployment "$CODESPACE_NAME-8080.$domain" > /tmp/relay.log 2>&1 < /dev/null &
echo "Relay started at $CODESPACE_NAME-8080.$domain."
