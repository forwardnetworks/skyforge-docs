# Core Beliefs

These are the Skyforge defaults for agent-first engineering. They are adapted
from OpenAI's Harness Engineering article and grounded in this repo's existing
Skyforge operating assumptions.

## Humans steer; agents execute

Humans define intent, constraints, and acceptance criteria. Agents inspect the
repo and live environment, implement changes, run verification, and preserve the
result as repository-local knowledge.

## Repository knowledge is the system of record

Facts that matter to future work must live in the repo. Chat history, terminal
scrollback, and one-off root handoffs are not durable enough unless converted
into indexed Harness artifacts.

## Give agents a map, not a manual

`AGENTS.md` is a small routing layer. It points to focused docs and checks. It
must not become a monolithic policy archive.

## Agent legibility beats prose volume

Prefer typed APIs, explicit file boundaries, deterministic scripts, structured
plans, and small indexes over narrative-only guidance. If a fact can be checked
mechanically, add a guard instead of repeating it in prose.

## Enforce invariants, not taste commentary

Architecture and operating rules should be validated by scripts, CI, tests, or
small checklists with clear failure messages. Agents should know what to fix
from the guard output.

## Garbage collect continuously

Stale docs are a production risk. Convert useful legacy knowledge into Harness
artifacts, archive historical notes, update the quality score, and keep cleanup
small enough to run frequently.
