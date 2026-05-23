# Review Signal — Intern Guide

This guide explains what Review Signal is, how it works, and how to work on it. It is written for someone new to the project.

## What is Review Signal?

**Review Signal** is a small Ruby tool that posts a **review brief** as a comment on GitHub pull requests.

Think of it as a **checklist generator for human reviewers**, not a robot that replaces code review.

When someone opens or updates a PR, Review Signal looks at:

- which files changed
- what kind of changes they are (models, migrations, frontend, and so on)
- whether the diff matches known risky patterns

Then it posts **one structured comment** on the PR with guidance like: “This PR touches a migration — check rollback,” or “This diff has a possible SQL injection — look at this exact line.”

## What problem does it solve?

Code review takes time. Reviewers often spend the first few minutes figuring out:

- What areas did this PR touch?
- Is there a migration, auth change, or API change?
- Are there obvious security red flags?
- Did the author add tests?

Review Signal tries to save **2–5 minutes per PR** by surfacing that upfront in a consistent format.

## What it is not

| Review Signal is… | Review Signal is **not**… |
| --- | --- |
| A deterministic rules engine | An AI code reviewer |
| A PR comment bot | A linter (RuboCop, ESLint) |
| A reviewer **assistant** | A replacement for human review |
| API-only (reads GitHub metadata) | Something that runs or checks out your app code |

**No AI is involved.** No ChatGPT, no LLM summaries, no “smart” guessing. Every flag comes from **explicit rules** you can read in YAML files.

## High-level architecture

Review Signal has two parts:

```text
┌─────────────────────┐
│   Ruby gem          │  ← the brain (analysis + markdown)
│   (review_signal)   │
└─────────┬───────────┘
          │
┌─────────▼───────────┐
│   GitHub Action     │  ← the trigger (runs on PR events)
│   (action.yml)      │
└─────────┬───────────┘
          │
┌─────────▼───────────┐
│   GitHub API        │  ← reads PR data, posts comment
└─────────────────────┘
```

1. **Ruby gem** — does all the analysis and builds the markdown comment.
2. **GitHub Action** — a wrapper that runs the gem when a PR is opened or updated.
3. **No web server** — nothing to host; it runs inside GitHub Actions.

## How a review brief is generated (step by step, no AI)

Here is the full pipeline when a PR triggers the action.

### Step 1: GitHub tells us a PR changed

The workflow runs on events like:

- PR opened
- new commits pushed (`synchronize`)
- PR marked ready for review

### Step 2: Fetch data from GitHub API only

Review Signal calls the GitHub REST API (via the **Octokit** gem). It **does not** clone the repo or run the app.

It fetches:

- PR title, base branch SHA, head SHA
- list of changed files (with diff patches)
- existing PR comments (to update the same comment later)

### Step 3: Classify files by area

**AreaClassifier** buckets paths into categories:

| Bucket | Example paths |
| --- | --- |
| migrations | `db/migrate/**` |
| models | `app/models/**` |
| controllers | `app/controllers/**` |
| client / frontend | `client/**`, `frontend/**` |
| specs | `spec/**`, `test/**` |
| config | `config/**`, `Gemfile` |

This powers the **What changed** section.

### Step 4: Run YAML rules (the core logic)

**Rules::Engine** loads rules from preset YAML files and checks each rule against the PR.

Rules match in two ways:

**A) Path rules (`any_path`)** — “Did this PR touch a file matching this pattern?”

```yaml
- id: migration
  when:
    any_path: "db/migrate/**"
  severity: high
  message: "Schema change detected..."
```

**B) Patch rules (`any_patch`)** — “Does the diff text match this regex?”

```yaml
- id: sql_interpolation
  when:
    any_patch: 'LIKE ''%#\{'
  severity: critical
  message: "Possible SQL interpolation detected..."
```

When a rule matches, Review Signal records **evidence**:

- the **file path**
- the **exact line from the diff** (the added code snippet)

Example output:

```markdown
- `app/controllers/api/v1/task_assignees_controller.rb` — `TaskAssignee.where("email LIKE '%#{query}%'")`
```

**No AI** — just pattern matching on paths and diff text.

### Step 5: Check test signal

**TestSignal** is a simple heuristic:

- If you changed `app/models/foo.rb`, it expects `spec/models/foo_spec.rb` to also change.
- If app code changed but no matching spec file changed, it adds a note under **Test signal**.

It does **not** prove tests are missing. It only flags that no obvious spec file changed in the same PR.

### Step 6: Render markdown

**MarkdownBrief** assembles a fixed template:

1. **Summary** — file count, areas touched, high-risk flag count
2. **What changed** — area breakdown
3. **Risk flags** — severity, message, file, and snippet evidence
4. **Review focus** — checklist bullets from matched rules and test signal
5. **Test signal** — spec pairing notes
6. **Footer** — static version (for example `Generated by Review Signal v0.1.5`)

Design choices:

- **No timestamps** — reruns should not churn the comment
- **No checkboxes** — human ticks would be overwritten on the next run
- **Stable output** — same input produces the same comment

### Step 7: Upsert one PR comment

**UpsertComment**:

1. Searches all PR comments for a hidden marker: `<!-- review-signal:v1 -->`
2. If found and body is identical → do nothing
3. If found and body changed → update that comment
4. If not found → create a new comment

Each PR gets **one** Review Signal comment that updates on new pushes.

## Project layout

```text
review-signal/
├── lib/review_signal/
│   ├── cli.rb                    # CLI entrypoint
│   ├── client.rb                 # GitHub API wrapper (Octokit)
│   ├── config_loader.rb          # Loads preset + optional custom rules
│   ├── analyzers/
│   │   ├── area_classifier.rb    # File path bucketing
│   │   └── test_signal.rb        # App file → spec file heuristic
│   ├── rules/
│   │   ├── engine.rb             # Rule matching logic
│   │   ├── patch_evidence.rb     # Extracts file + snippet from diffs
│   │   ├── default_rules.yml     # Generic rules (Gemfile, .github, etc.)
│   │   └── rails_rules.yml       # Rails + security patch rules
│   ├── render/
│   │   └── markdown_brief.rb     # Builds the comment text
│   └── services/
│       └── upsert_comment.rb     # Create/update PR comment
├── bin/review-signal             # Executable CLI
├── action.yml                    # GitHub Action definition
├── docs/                         # Project documentation
└── spec/                         # RSpec tests
```

**Dependencies:** `octokit` plus Ruby stdlib (`yaml`, and so on). No Rails app, no AI SDKs.

## Presets (built-in rule sets)

| Preset | When to use |
| --- | --- |
| `default` | Any repo — flags dependency files, GitHub workflow changes |
| `rails` | Rails-shaped apps — migrations, API controllers, security patch rules |

The `rails` preset merges **default** and **rails-specific** rules.

### Examples of rails rules

**Path-based:**

- Migration touched → schema safety warning
- API controller touched → check auth and validation
- Policy or ability files → authorization review

**Patch-based (reads diff content):**

- Hardcoded secrets (`ADMIN_TOKEN`, `API_KEY`, and so on)
- SQL string interpolation (`LIKE '%#{...}'`)
- Unsafe mass assignment (`build(params[:...])`)
- XSS (`dangerouslySetInnerHTML`)
- Token in URL query string
- Unscoped `find(params[:id])` (possible IDOR)
- Validation left as `# TODO`
- `save` then `render json` without error handling
- `/tasks/0/` placeholder IDs
- Possible N+1 (`.map { ... .task.` patterns)
- Logging `params.inspect`

## How it runs in a consumer repo

Example workflow:

```yaml
name: Review Signal

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  brief:
    runs-on: ubuntu-latest
    steps:
      - uses: rashmiee/review-signal@v0.1.5
        with:
          preset: rails
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

When a PR is opened or updated, the Action runs, the gem analyzes the PR, and the comment appears on GitHub.

**Security note:** The Action runs from its own code (`github.action_path`). It does **not** checkout the PR branch, so it never executes untrusted PR code.

## Custom rules (optional)

Teams can add a file like `.github/review_signal.yml` in their repo with extra rules.

In Action mode, that file is fetched via GitHub Contents API from the **base branch** (trusted), not from the PR head (untrusted).

Rules with the same `id` override built-in ones. New ids are appended.

Example:

```yaml
rules:
  - id: migration
    when:
      any_path: "db/migrate/**"
    severity: high
    message: "Schema change detected. Verify migration safety, rollback, and data backfill."
    review_focus:
      - "Confirm rollback path."
      - "Check for NOT NULL columns without a backfill."
```

## What it can and cannot catch

**Good at:**

- Obvious security patterns in the diff (secrets, SQL interpolation, XSS)
- Structural signals (migration, API controller, missing spec file in PR)
- Pointing reviewers to exact file and line

**Not good at (by design):**

- Cross-file logic (for example controller uses an association but model lacks `has_many`)
- CI failures, test results, Codacy findings
- Subtle business logic bugs
- Understanding intent

It is a **brief**, not a full audit.

## Local development

```bash
cd ~/Projects/review-signal
bundle install
bundle exec rspec

# Preview a brief without posting
GITHUB_TOKEN=$(gh auth token) \
  bundle exec bin/review-signal \
  --repo OWNER/REPO \
  --pr 123 \
  --preset rails \
  --dry-run
```

`--dry-run` prints the markdown to your terminal instead of posting to GitHub.

To test against a real PR with posting:

```bash
GITHUB_TOKEN=$(gh auth token) \
  bundle exec bin/review-signal \
  --repo rashmiee/testingGitlabels \
  --pr 17 \
  --preset rails
```

## Where to extend the project

| Goal | Start here |
| --- | --- |
| Add a new risk flag | `lib/review_signal/rules/rails_rules.yml` |
| Change file bucketing | `lib/review_signal/analyzers/area_classifier.rb` |
| Improve spec detection | `lib/review_signal/analyzers/test_signal.rb` |
| Change comment format | `lib/review_signal/render/markdown_brief.rb` |
| Add tests first (TDD) | `spec/` |

Workflow for new rules:

1. Write a failing spec in `spec/review_signal/rules/engine_spec.rb`
2. Add the rule to YAML
3. Run `bundle exec rspec`
4. Test with `--dry-run` against a real PR

## One-sentence summary

> **Review Signal is a rule-based GitHub bot that reads what changed in a PR (file paths and diff text), matches those changes against a YAML checklist of known risks, and posts a structured review brief with exact file locations — no AI, no code execution, just fast, repeatable reviewer guidance.**

## Further reading

- [README](../README.md) — install, Action usage, security model
- [GitHub Developer Program](https://docs.github.com/en/integrations/concepts/github-developer-program) — if publishing as a public integration
