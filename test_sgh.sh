#!/usr/bin/env bash
set -euo pipefail

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
cd "$ROOT"

init_test_repo() {
  rm -rf .git .gitignore .env historical-leak.txt
  git init -q
  git config user.name sgh-test
  git config user.email "sgh-test""@""users.noreply.github.com"
}

init_test_repo
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
rg -q "internal-attribution" /tmp/sgh-llm.json

if ! /home/terum/sgh/sgh --dry-run pr comment 1 --body "Added this feature because a named manager requested it." >/tmp/sgh-internal.txt 2>&1; then
  echo "expected internal attribution hint to pass without deterministic block" >&2
  exit 1
fi
rg -q "semantic-risk hint" /tmp/sgh-internal.txt

if ! /home/terum/sgh/sgh --dry-run pr comment 1 --body "法务要求 temporary compatibility path." >/tmp/sgh-multilingual.txt 2>&1; then
  echo "expected multilingual internal attribution hint to pass without deterministic block" >&2
  exit 1
fi
rg -q "semantic-risk hint" /tmp/sgh-multilingual.txt

HISTORY_FIXTURE="history-person""@""example.com"
printf 'Contact: %s\n' "$HISTORY_FIXTURE" > historical-leak.txt
git add historical-leak.txt
git commit -q -m 'Add historical fixture'
git rm -q historical-leak.txt
git commit -q -m 'Remove historical fixture'

if /home/terum/sgh/sgh --dry-run git push >/tmp/sgh-history.txt 2>&1; then
  echo "expected per-commit history block" >&2
  exit 1
fi

init_test_repo

printf 'fixture\n' > .env
git add .env
git commit -q -m 'Track env fixture'
printf '.env\n' > .gitignore
git add .gitignore
git commit -q -m 'Ignore env fixture'

if /home/terum/sgh/sgh --dry-run git push >/tmp/sgh-ignore.txt 2>&1; then
  echo "expected tracked ignored file block" >&2
  exit 1
fi

echo "sgh tests passed"
