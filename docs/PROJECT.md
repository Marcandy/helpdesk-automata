# Project scope and evidence

Helpdesk Automata is an API for managing support tickets and automating support
workflows. It starts from rafsaf's MIT-licensed
[minimal-fastapi-postgres-template](https://github.com/rafsaf/minimal-fastapi-postgres-template).
Preserve the upstream license and distinguish inherited work from original work.

## Current boundary

The setup change adds project documentation and a repeatable baseline command.
It does not add models, migrations, routes, role policies, agent frameworks, or
LLM integrations. The inherited API contains authentication and probe endpoints.

## Next milestone: manual baseline

After setup is verified, implement Ticket and Comment models, create/list
endpoints, migration, factories, and meaningful tests by hand. Use the upstream
nine-step walkthrough as a guide, correcting its example test directory to match
the actual package you create. Decide ownership, access rules, and acceptance
criteria before coding.

Record the starting commit, UTC start/end timestamps, active work time, pauses,
tools used, assistance received, test commands/results, and resulting commit.
Keep setup time separate from implementation time. Do not present template code
or this assisted setup as your original manual implementation. No timer has
been started for that future milestone.

## Later scoped agent work

| Candidate | Acceptance questions to settle first |
| --- | --- |
| SLA deadline filtering and pagination | Which clock, response event, timezone, and boundary rules apply? |
| Customer/agent/admin access and audit history | Who may see or change each ticket? Which events must be recorded, and how is append-only behavior enforced? |
| Status workflow validation | Which transitions are allowed, and what counts as an agent reply before closure? |
| Structured AI triage | What labels, evaluation dataset, accuracy threshold, cost budget, and failure behavior apply? |

These are future candidates. Keep each feature small enough for a reviewer to
verify independently. Compare manual and assisted work only when task size and
verification effort are recorded; raw elapsed time alone is weak evidence.

For each assisted task, preserve its issue/brief, acceptance criteria, starting
commit, agent prompt and tools, relevant run evidence, human review findings,
test results, elapsed time, and final diff. Record failures and corrections as
well as successful runs. Keep secrets and private data out of evidence files.
