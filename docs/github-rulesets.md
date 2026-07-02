# GitHub Rulesets for sgh

GitHub rulesets and push protection should handle the platform-enforced part of `sgh`.

`sgh` can stop local `gh` operations before publication, but local wrappers are bypassable. GitHub rulesets provide a server-side baseline for file/path hygiene. They do not replace semantic scanning, but they are good at blocking obvious high-risk files.

## Recommended Push Ruleset

Use a push ruleset named:

```text
sgh push hygiene
```

Target:

```text
push
```

Enforcement:

```text
active
```

Rules:

- Restrict file extensions:
  - `env`
  - `pem`
  - `key`
  - `p12`
  - `pfx`
  - `crt`
  - `cer`
  - `sqlite`
  - `db`
  - `dump`
  - `sql`
  - `bak`
  - `jsonl`
  - `zip`
  - `tar`
  - `gz`
  - `7z`
- Restrict file paths:
  - `.env`
  - `.env.*`
  - `**/.env`
  - `**/.env.*`
  - `**/*secret*`
  - `**/*credential*`
  - `**/*token*`
  - `**/*private-key*`
  - `**/*people*`
  - `**/*transcript*`
  - `**/*minutes*`
  - `**/*hearing*`
  - `**/*never-record*`
  - `**/*議事録*`
- Maximum file size:
  - `5 MB`
- Maximum file path length:
  - `180`

These are intentionally blunt. Keep semantic checks in `sgh`; keep obvious file hygiene in GitHub rulesets.

## Generate JSON

```sh
sgh ruleset-template
```

Use `evaluate` first on Enterprise if you want to observe impact before enforcement:

```sh
sgh ruleset-template --enforcement evaluate
```

## Apply to a Repository

```sh
sgh ruleset-template --repo OWNER/REPO --apply
```

This calls:

```sh
gh api repos/OWNER/REPO/rulesets --method POST --input -
```

The authenticated token needs repository administration write permission.

Availability note: GitHub may require a paid plan or a public repository for repository rulesets, depending on owner/repository type. If the API returns `Upgrade to GitHub Pro or make this repository public to enable this feature`, the payload reached GitHub but the repository is not eligible for rulesets under its current plan/visibility.

## Verify

```sh
gh ruleset list --repo OWNER/REPO
gh ruleset view --repo OWNER/REPO --web
```

The installed `gh` CLI can list and view rulesets, but creating them currently requires the REST API.

## Push Protection

Enable GitHub Secret Protection / push protection separately. It handles known credential patterns and custom regex patterns. `sgh` does not try to replace it.

Recommended custom patterns:

- organization-specific API keys
- internal token prefixes
- private registry tokens
- internal hostnames only if false positives are acceptable

Do not try to encode semantic PII or office-politics phrases as GitHub custom secret patterns. Use `sgh` and LLM review for those.

## Limits

Rulesets cannot understand context like:

- "this was requested by a named manager"
- "this exception is for a specific customer"
- "this PR body mentions an individual's personal GitHub namespace"
- "this issue comment contains meeting notes"

Those are `sgh` semantic-review territory.
