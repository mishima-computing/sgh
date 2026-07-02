# sgh

`sgh` is a secure wrapper for `gh`.

It scans high-risk GitHub publish surfaces before calling the real `gh` binary:

- `gh pr create|edit|comment|review`
- `gh issue create|edit|comment`
- `gh release create|edit`
- `gh repo create|edit`
- `gh gist create|edit`
- common `gh api -f/-F/--field/--raw-field` body/title/description fields

## Usage

```sh
/home/terum/sgh/sgh pr comment 123 --body "Looks good"
/home/terum/sgh/sgh --dry-run pr create --title "Example" --body "Example body"
/home/terum/sgh/sgh --llm-packet pr comment 123 --body "meeting notes about customer X"
```

To use it as `sgh`:

```sh
export PATH="/home/terum/sgh:$PATH"
sgh pr comment 123 --body "Looks good"
```

## Policy Files

In a repository, create:

```text
.leakguard/denylist.txt
.leakguard/allowlist.txt
```

`denylist.txt` contains exact people, client, vendor, project, or case names that must not be published.
`allowlist.txt` contains public-safe terms.

`sgh` also blocks likely email addresses, phone numbers, contact handles, and raw-data filenames such as `*minutes*`, `*transcript*`, `*議事録*`, and `*.jsonl`.

## LLM Review Packet

`--llm-packet` prints structured JSON for an AI agent to judge semantic risk:

```sh
sgh --llm-packet pr comment 123 --body "customer call notes ..."
```

The packet asks the LLM to return:

```json
{"decision":"allow|block|redact","findings":[],"suggested_redactions":[]}
```

The MVP does not call an LLM itself. It returns the judgement packet so an agent can decide whether to allow, block, or redact.
