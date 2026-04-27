# Skyforge Harnesses

Harnesses are the agent-readable operating system for Skyforge. They turn repo
knowledge into a small map, durable docs, executable plans, and mechanical
checks so agents do not rediscover the same operational facts.

## Start here

- [core-beliefs.md](core-beliefs.md): operating principles adapted from OpenAI's Harness Engineering model.
- [agent-operating-model.md](agent-operating-model.md): how agents should plan, execute, review, and hand off work.
- [environment-contracts.md](environment-contracts.md): QA/prod routing, context guards, deploy safety, and live-target assumptions.
- [architecture-boundaries.md](architecture-boundaries.md): pointers to the active architecture and Netlab/KNE boundaries.
- [quality-score.md](quality-score.md): quality/debt tracker for domains and docs.
- [doc-gardening.md](doc-gardening.md): recurring cleanup loop for drift and stale knowledge.
- [legacy-conversion-index.md](legacy-conversion-index.md): conversion map from legacy handoffs and root docs.
- [archive/legacy/README.md](archive/legacy/README.md): historical evidence that has been folded into active docs.

## Artifact model

- `exec-plans/active/`: current execution plans that an agent can resume.
- `exec-plans/completed/`: compact completed-plan stubs with current-truth and archive pointers.
- `archive/legacy/`: archived handoff bodies and historical notes; evidence only, not active runbooks.
- `references/`: compact source references that should be easier to read than the upstream artifact.

Keep `AGENTS.md` short. If a rule needs explanation, examples, or history, it
belongs in this directory or the linked domain runbook.
