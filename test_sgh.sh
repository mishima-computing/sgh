#!/usr/bin/env bash
set -euo pipefail

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
cd "$ROOT"
mkdir -p .leakguard
printf 'Acme Confidential\n' > .leakguard/denylist.txt

/home/terum/sgh/sgh --dry-run pr comment 1 --body "plain public update" >/tmp/sgh-ok.txt

EMAIL_FIXTURE="person""@""example.com"
if /home/terum/sgh/sgh --dry-run pr comment 1 --body "mail me at ${EMAIL_FIXTURE}" >/tmp/sgh-email.txt 2>&1; then
  echo "expected email block" >&2
  exit 1
fi

if /home/terum/sgh/sgh --dry-run pr comment 1 --body "Acme Confidential should not leave" >/tmp/sgh-deny.txt 2>&1; then
  echo "expected denylist block" >&2
  exit 1
fi

/home/terum/sgh/sgh --llm-packet pr comment 1 --body "meeting notes about customer onboarding" >/tmp/sgh-llm.json
python3 -m json.tool /tmp/sgh-llm.json >/dev/null

echo "sgh tests passed"
