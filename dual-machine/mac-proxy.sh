#!/usr/bin/env bash
set -euo pipefail

# Source this file in shells that need Clash/Mihomo from the Mac.
# Usage:
#   source /path/to/mac-proxy.sh on
#   source /path/to/mac-proxy.sh off

PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${PROXY_PORT:-7897}"

case "${1:-on}" in
  on)
    export HTTP_PROXY="http://${PROXY_HOST}:${PROXY_PORT}"
    export HTTPS_PROXY="http://${PROXY_HOST}:${PROXY_PORT}"
    export ALL_PROXY="socks5://${PROXY_HOST}:${PROXY_PORT}"
    export http_proxy="${HTTP_PROXY}"
    export https_proxy="${HTTPS_PROXY}"
    export all_proxy="${ALL_PROXY}"
    git config --global http.proxy "${HTTP_PROXY}"
    git config --global https.proxy "${HTTPS_PROXY}"
    echo "Proxy enabled for this shell and global Git: ${HTTP_PROXY}"
    ;;
  off)
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true
    echo "Proxy disabled for this shell and global Git."
    ;;
  *)
    echo "Usage: source mac-proxy.sh [on|off]" >&2
    return 2 2>/dev/null || exit 2
    ;;
esac
