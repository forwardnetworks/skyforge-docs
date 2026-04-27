---
harness_kind: active-exec-plan
status: active
legacy_source: components/docs/plans/teams-forward-integration.md
converted_at: 2026-04-27
title: Teams Forward Integration Checklist
current_truth: verify against current code and environment before execution
---

# Teams Forward Integration Checklist

## Summary

Build a Skyforge-side Teams bridge that gives Teams-like interaction with Forward
without modifying Forward source. Skyforge owns:

- global admin bridge configuration
- per-user Teams binding
- inbound command execution
- outbound webhook delivery
- audit and portal workflow

This is intentionally a **Skyforge bridge**, not an official Microsoft Teams app
implementation.

## Current v1 scope

- [x] Add encrypted global Teams config storage in Skyforge
- [x] Add per-user Teams binding storage in Skyforge
- [x] Add admin APIs for global Teams config
- [x] Add user APIs for Teams binding
- [x] Add outbound test-send APIs
- [x] Add public bridge callback endpoint
- [x] Add Forward path-search command execution
- [x] Add Teams user page in the portal
- [x] Add Teams admin settings card in the portal
- [x] Add Teams sidebar entry under Forward

## Global admin config

- [x] enabled flag
- [x] display name
- [x] public base URL
- [x] inbound shared secret
- [x] callback URL derivation
- [x] admin test send with supplied webhook URL

## Per-user binding

- [x] Teams user reference
- [x] outbound webhook URL
- [x] Forward credential set
- [x] default Forward network selection from saved Forward networks
- [x] enabled flag
- [x] audit on save
- [x] user test send

## Bridge command contract

- [x] `help`
- [x] `path <srcIp> <dstIp>`
- [x] optional `from=`, `sport=`, `dport=`, `proto=`, `intent=`
- [x] result formatting with hop summary
- [x] deep link passthrough from Forward `queryUrl`

## Security

- [x] encrypt global shared secret at rest
- [x] encrypt per-user outbound webhook URL at rest
- [x] validate shared secret on inbound bridge request
- [x] require `X-Skyforge-Teams-Secret` header on inbound bridge requests
- [x] resolve Teams user to Skyforge user server-side
- [x] resolve Forward credentials server-side

## Follow-up work

- [ ] add richer Teams card/message formatting
- [ ] add explicit per-user custom command aliases
- [ ] add targeted server tests for command parsing and path formatting
- [ ] add targeted portal tests for Teams settings flows
- [ ] document bridge payload examples for demo/test tenant setup
