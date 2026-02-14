#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0

# Disallow raw run artifacts and transient logs in docs repo.
if find . -type f \( -name '*.jsonl' -o -name 'e2e-*.json' -o -name '*.pcap' \) | grep -q .; then
  echo "[gate] found disallowed artifact files in docs repo"
  find . -type f \( -name '*.jsonl' -o -name 'e2e-*.json' -o -name '*.pcap' \) | sed 's#^#  - #' 
  fail=1
fi

# Disallow internal-only host/IP/path leaks.
PATTERNS=(
  'skyforge\.local\.forwardnetworks\.com'
  '\.svc\.cluster\.local'
  '\b100\.64\.[0-9]+\.[0-9]+\b'
  '/home/ubuntu/Projects/'
  'github\.token'
)

TARGETS="$(find . -type f \( -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) ! -path './.git/*')"
for p in "${PATTERNS[@]}"; do
  if grep -RInE "$p" $TARGETS >/tmp/docs_gate_hits.txt 2>/dev/null && [[ -s /tmp/docs_gate_hits.txt ]]; then
    echo "[gate] pattern '$p' found in docs content"
    sed 's#^#  - #' /tmp/docs_gate_hits.txt
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "[gate] public docs gate failed"
  exit 1
fi

echo "[gate] public docs gate passed"
