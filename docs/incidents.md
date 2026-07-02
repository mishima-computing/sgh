# GitHub Leak Incident Patterns

This document collects public incident patterns that inform `sgh` design.

The goal is not to duplicate secret scanners. The goal is to identify publication surfaces and workflow mistakes that are easy for humans and AI agents to miss.

## Patterns

### 1. `.gitignore` added after the file is already tracked

Failure mode:

- A sensitive file is committed.
- A developer later adds the file to `.gitignore`.
- The developer assumes the file is now protected.
- Git keeps tracking the file because ignore rules do not affect already tracked paths.

Why it matters:

- `.gitignore` only protects intentionally untracked files.
- The old content remains in Git history.
- If pushed, cleanup requires history rewriting plus credential rotation.

Sources:

- Git's `gitignore` documentation states that files already tracked by Git are not affected by ignore rules: <https://git-scm.com/docs/gitignore>
- GitHub's ignoring-files documentation says an already checked-in file must be untracked with `git rm --cached`: <https://docs.github.com/articles/ignoring-files>
- GitHub's sensitive-data removal documentation emphasizes prevention and cleanup complexity: <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository>

`sgh` response:

- `sgh git push` blocks when `git ls-files -ci --exclude-standard` reports tracked files that match current ignore rules.
- This catches the common "I added it to `.gitignore`, so it is safe" mistake before push.

### 2. `.env` and local config files pushed before ignore rules exist

Failure mode:

- A developer starts a project without a complete `.gitignore`.
- `.env`, credentials, local config, database dumps, or test fixtures are committed.
- A later `.gitignore` change does not remove the historical leak.

Public examples and discussion:

- GitHub Community and developer forums repeatedly document accidental `.env` pushes and the need to rotate credentials and rewrite history.
- Anecdotal reports describe automated cloud compromise shortly after public `.env` exposure.

Sources:

- GitHub Community discussion about removing `.env` from history: <https://github.com/orgs/community/discussions/177497>
- GitHub Docs on removing sensitive data: <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository>
- Reddit report of AWS compromise after `.env` push: <https://www.reddit.com/r/github/comments/jxsuqm/accidentally_pushed_my_env_file/>

`sgh` response:

- Block tracked ignored files.
- Block high-risk filenames in push args and outgoing changed filenames, such as `*.jsonl`, `*minutes*`, and `*transcript*`.
- Roadmap: starter ignore templates and pre-commit integration.

### 3. Commit history is harder to clean than people expect

Failure mode:

- A secret is committed and pushed.
- The file is deleted in a later commit.
- The original content remains reachable in history, forks, clones, caches, or copied logs.

Sources:

- GitHub Docs describe sensitive-data removal as history rewriting with coordination costs: <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository>
- Truffle Security's research on "oops commits" discusses why deleted commits can still be discoverable: <https://trufflesecurity.com/blog/guest-post-how-i-scanned-all-of-github-s-oops-commits-for-leaked-secrets>

`sgh` response:

- Prefer pre-publication blocking over remediation.
- Make `sgh git push` a first-class path.
- Scan each commit's added lines in the outgoing push range, not only the final diff, because a later commit can remove text that still remains in earlier commit history.

Dogfood note:

- An early public README version mentioned a personal test repository namespace.
- A later commit removed it from the current README, but the earlier commits still contained the namespace.
- This demonstrated that final-diff scanning is insufficient; push protection must scan each outgoing commit before publication.

### 4. GitHub Actions logs, summaries, and artifacts can leak secrets

Failure mode:

- CI scripts print environment variables, debug dumps, credentials, or generated summaries.
- GitHub's masking helps for registered secrets, but generated or transformed values may still leak.
- Artifacts and logs can be copied outside the repository boundary.

Sources:

- GitHub Docs recommend masking sensitive information that is not already a GitHub secret: <https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions>
- Research and tooling vendors have demonstrated secret scanning in GitHub Actions logs.
- StepSecurity describes log scanning for exposed secrets: <https://www.stepsecurity.io/blog/scan-github-actions-build-logs-for-secrets-with-stepsecuritys-new-feature>

`sgh` response:

- Roadmap: Actions guard for `$GITHUB_STEP_SUMMARY`, artifact names/content, and bot-comment commands.

### 5. Push protection is necessary but not sufficient

Failure mode:

- GitHub push protection blocks many known credential patterns.
- Semantic PII, client names, meeting notes, personal GitHub namespaces, and issue/PR comments are outside the main secret-pattern model.

Sources:

- GitHub push protection is designed for hardcoded credentials: <https://docs.github.com/en/code-security/concepts/secret-security/push-protection>
- GitHub's supported secret scanning patterns are explicitly pattern/type based: <https://docs.github.com/en/code-security/reference/secret-security/supported-secret-scanning-patterns>

`sgh` response:

- Add context-aware checks around GitHub CLI publication surfaces.
- Emit `--llm-packet` for semantic judgement.

### 6. Personal repositories and personal namespaces can expose organizational context

Failure mode:

- A developer creates or references a personal repository while working in an organizational context.
- Public documentation, PR text, or issue comments mention an individual's GitHub namespace.
- The namespace itself becomes identifying metadata.

Sources:

- Aqua Security research describes corporate data exposure through employee personal repositories: <https://www.aquasec.com/blog/github-repos-expose-azure-and-red-hat-secrets/>
- Public forums contain recurring reports about accidental publication under personal accounts.

`sgh` response:

- Allow a personal namespace when it is the direct target of a personal `repo create`.
- Block cross-namespace personal references when an organization repository's publishable text mentions the authenticated personal namespace.

### 7. AI assistants increase publication volume and context echo

Failure mode:

- AI agents generate PR bodies, comments, reviews, branch names, summaries, and tests.
- They may echo prompt context: customer names, personal names, internal notes, transcripts, or sanitized-looking but identifying summaries.

Sources:

- Samsung engineers reportedly leaked source code and meeting notes through ChatGPT use, showing how AI tool context can become a leak surface: <https://incidentdatabase.ai/cite/768/>
- GitGuardian reporting has described AI-assisted development as increasing secret-sprawl risk on GitHub.

`sgh` response:

- Treat GitHub comments, PR descriptions, review bodies, and generated summaries as publication surfaces.
- Provide an LLM review packet to make semantic risk explicit before posting.

### 8. Internal attribution and embarrassing context leak through comments

Failure mode:

- Source comments, PR bodies, or GitHub discussion comments explain *who* requested a change or *why* an exception exists.
- The text may not contain a credential or a private email address, but it can expose internal decision-making, customer-specific handling, legal/sales pressure, employee names, codenames, Slack channels, or just embarrassing context.
- AI agents make this worse because they tend to write polished explanations from all available context.

Observed public patterns:

- During discussion of a GitHub source-code leak, commenters noted that internal "funny" comments were being paraded publicly and that comments written for coworkers should be treated as public once code leaks.
- Claude Code leak analysis reported internal codenames and an "undercover" mode intended to prevent internal names, Slack channels, and product names from escaping into external repositories.
- A public GitHub Discussion contains a direct "Legal said..." / "that's why I requested it" attribution. That example is not necessarily a leak, but it shows the exact language pattern `sgh` should send to LLM review when it appears in an organization repo or generated PR/comment text.
- Dropbox's GitHub-related source-code incident reportedly exposed not just code and API keys, but data about employees, customers, vendors, and sales leads.

Sources:

- Reddit discussion of exposed source comments becoming public: <https://www.reddit.com/r/programming/comments/joa39m/github_source_code_leaked_online/>
- Claude Code leak analysis describing internal codenames and suppression of internal names/channels in external repos: <https://read.engineerscodex.com/p/diving-into-claude-codes-source-code>
- Public GitHub Discussion with "Legal said..." attribution language: <https://github.com/open-webui/open-webui/discussions/13818>
- Dropbox GitHub-source incident summary mentioning employees, customers, vendors, and sales leads: <https://www.skyhighsecurity.com/about/resources/intelligence-digest/dropped-out-of-the-box-dropbox.html>

`sgh` response:

- Treat role/person attribution phrases as semantic-risk triggers, not deterministic blocks.
- Include `internal-attribution`, `internal-politics`, and `customer-specific-exception` categories in the LLM review instruction.
- Prefer neutral implementation rationale such as "Preserve compatibility for configured deployments" over "Added this because a named manager requested it."

## Design Requirements From These Incidents

- Block tracked files that match current ignore rules.
- Treat `.gitignore` as advisory, not as proof of safety.
- Scan push ranges before remote publication.
- Scan GitHub CLI text surfaces before posting.
- Keep deterministic blocks for high-confidence cases.
- Use LLM judgement for semantic PII and case-data risk.
- Use LLM judgement for internal attribution, office-politics language, and customer-specific exceptions.
- Prefer prevention over cleanup.
