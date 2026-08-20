#!/usr/bin/env bash
set -euo pipefail

failures=0

echo "ROUTES"
ip -4 route

echo "DNS"
getent ahostsv4 api.github.com | head -1

echo "HTTPS"
curl -fsS --max-time 15 https://api.github.com/zen
echo

for target in \
  100.101.122.39:22 \
  100.117.202.124:22 \
  100.69.182.27:22 \
  192.168.1.1:80 \
  10.0.0.1:443 \
  172.16.0.1:443; do
  host=${target%:*}
  port=${target##*:}
  if timeout 4 bash -c "</dev/tcp/${host}/${port}" 2>/dev/null; then
    echo "UNEXPECTED_REACHABLE ${target}"
    failures=$((failures + 1))
  else
    echo "BLOCKED ${target}"
  fi
done

echo "TAILSCALE"
if command -v tailscale >/dev/null 2>&1 || \
   dpkg-query -W tailscale >/dev/null 2>&1 || \
   [[ -d /var/lib/tailscale ]]; then
  echo "TAILSCALE_PRESENT"
  failures=$((failures + 1))
else
  echo "TAILSCALE_ABSENT"
fi

if [[ ${failures} -ne 0 ]]; then
  echo "Isolation verification failed with ${failures} unexpected result(s)." >&2
  exit 1
fi

echo "ISOLATION_OK"
