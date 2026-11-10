#!/bin/sh
set -eu
cd "$(dirname "$0")"
command -v node >/dev/null 2>&1 || { echo 'Node.js 22.16+ required: https://nodejs.org/en/download'; exit 1; }
node -e "const v=process.versions.node.split('.').map(Number); if(v[0]<22||(v[0]===22&&v[1]<16))process.exit(1)"
echo 'Outside Windows, credentials are session-only. No plaintext fallback.'
exec node server.mjs
