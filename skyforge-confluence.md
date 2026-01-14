# Skyforge (TS Lab Automation Platform) — User Guide

Skyforge is an internal Technical Services lab automation platform for building and operating network labs (EVE-NG, Netlab/Containerlab, Terraform, etc.) with a consistent workflow: pick a blueprint, create a deployment, run it, and collect logs/artifacts/inventory.

This page is written to be pasted into Confluence as Markdown.

---

## What Skyforge does

Skyforge provides:

- A **portal UI** for browsing blueprints and managing deployments/runs.
- A **backend** that executes provider-specific automation (Netlab, LabPP, Terraform, etc.).
- A **toolchain** (Git, NetBox, Nautobot, DNS, Coder/code-server, webhook inbox, etc.) behind SSO to support lab workflows.

Skyforge is optimized for:

- **Day-0 lab creation** (repeatable deployments from blueprints)
- **Day-1 operations** (start/stop, status, logs)
- **Inventory export** (device name/IP/credentials for downstream ingestion when applicable)

---

## Core concepts

### Workspace
Your workspace is your scoped area in Skyforge:

- **Isolation:** deployments, artifacts, and runs are scoped to your workspace.
- **Git integration:** each workspace has a repo for your private blueprints/inputs.
- **State:** providers store generated state under a workspace-owned directory/backing storage.

### Blueprint
A blueprint is a template that defines what gets built. Skyforge typically exposes:

- A **public blueprint catalog** (shared, read-only reference set)
- Your **workspace blueprint repo** (fork/modify here)

### Deployment
A deployment is a configured instance of a blueprint (provider + template + target server + parameters).

### Run
A run is an execution of a deployment action (create/start/stop/destroy/sync/etc.). Runs produce logs and may produce artifacts.

---

## Providers (what you can deploy)

### Netlab (Netlab → Containerlab)
Best for containerized topologies generated and configured via Netlab:

- Inputs: a Netlab example folder containing `topology.yml` plus any companion files.
- Common actions:
  - **Create**: generate the working directory and Netlab state from the blueprint.
  - **Start**: `netlab up` / `containerlab deploy` + initial configuration.
  - **Stop**: `netlab down`
  - **Destroy**: cleanup of state and lab directory.
- Outputs: generated `clab.yml`, `hosts.yml`, `netlab.snapshot.yml` (when available), plus run logs.

Notes:

- Some vendor images (example: Arista cEOS) are not publicly pullable and must be preloaded on the Netlab host.
- If your selected template folder doesn’t have `topology.yml` at its root, Netlab will fail.

### Building Netlab topologies (authoring)
If you want to create or customize Netlab blueprints:

- Start from the examples already available in the Skyforge blueprint catalog.
- Refer to the Netlab documentation: https://netlab.tools
- If you need help adapting a topology to Skyforge conventions (images, credentials, startup behavior), contact Craig Johnson (`craigjohnson@forwardnetworks.com`) via Slack `#ask-skyforge`.

### LabPP (EVE-NG lab workflows)
Best for EVE-NG-backed labs where the topology is running on an EVE server.

In Skyforge, LabPP is primarily used to:

- Configure devices inside the EVE lab (when applicable).
- Generate a device inventory output (for example, name/IP CSV) for downstream ingestion.

Notes:

- Skyforge can SSH-tunnel to the EVE host for secure access.
- LabPP is not intended to create/modify Forward networks directly unless explicitly enabled by admins.

### Terraform
Terraform deployments manage cloud/on-prem infrastructure where IaC is appropriate:

- Actions: plan/apply/destroy.
- Outputs: plan/apply logs and any exported artifacts you choose to store.

### Containerlab on Kubernetes (“c9s”, experimental)
Skyforge includes an experimental path for Kubernetes-based containerlab orchestration (clabernetes, referred to as **c9s** in Skyforge).

- Target use: large-scale containerlab topologies running as Kubernetes workloads.
- Status: experimental; treat as best-effort until standardized.

---

## Typical workflow (most users)

1. **Log in**
   - Use SSO/LDAP credentials.
2. **Pick a workspace**
   - Create a new workspace (or select an existing one you own).
3. **Choose a blueprint**
   - Pick from public catalog or your workspace repo.
4. **Create a deployment**
   - Choose provider (Netlab/LabPP/Terraform/etc.), target server, and template.
5. **Run actions**
   - Create → Start → Stop/Destroy as needed.
6. **Check logs & artifacts**
   - Use run logs to diagnose failures; download artifacts when available.
7. **Export inventory**
   - Use generated inventory outputs (when applicable) for downstream ingestion.

---

## Tooling in the left navigation

Depending on your environment configuration, you may see:

- **Git (Gitea):** your workspace repo (and optionally the public blueprint repo)
- **NetBox / Nautobot:** lab asset inventory and IPAM (permission-scoped)
- **DNS:** Technitium DNS UI (SSO bridge)
- **Coder / VS Code:** browser-based dev environment (where enabled)
- **Webhook inbox:** inspect inbound webhooks during integrations testing
- **Swagger / API testing UI:** explore Skyforge APIs (admin/dev use)

If a tool loads but you have limited navigation, that usually indicates permissions are intentionally scoped.

---

## Data isolation and etiquette

Skyforge is multi-user. Please:

- Keep destructive actions scoped to your own workspace/deployments.
- Destroy labs you’re not using to free capacity.
- Avoid “shared scratch” workspaces unless explicitly coordinated.

---

## Common troubleshooting

### A run is “Queued” for longer than expected
Possible causes:

- A worker is restarting or temporarily unavailable.
- The system is processing other jobs.

What to do:

- Wait ~30–60 seconds and refresh the deployment view.
- If it persists, capture the run ID and ask the platform owner to check worker logs and queue depth.

### Netlab errors about missing `topology.yml`
This usually means the selected template folder is wrong or the folder was not synced correctly.

What to do:

- Ensure the selected template directory contains `topology.yml` at the root of the selected folder (not nested under extra path prefixes).

### Netlab errors about vendor images missing
Example: `... image ... is not installed` (common with vendor images).

What to do:

- Use a blueprint that references images available on the host, or ask the platform owner to preload the image on the Netlab server.

### LabPP errors about EVE credentials
This usually indicates expired/cleared cached credentials or missing credential handoff to the run.

What to do:

- Log out and log back in, then retry once.
- If it persists, capture the run ID and report it.

### “It worked but the run shows Failed”
Some providers can complete the core action but fail during post-steps (cleanup, optional checks, inventory sync).

What to do:

- Inspect the logs; if the primary objective succeeded, you can proceed, but still report the run ID so the failure mode can be hardened.

---

## Support / escalation

Primary owner: Craig Johnson (`craigjohnson@forwardnetworks.com`)

Slack: `#ask-skyforge`

Access: hosted on Epic; reachable via Cato VPN at `https://skyforge.local.forwardnetworks.com`

When reporting issues, include:

- Workspace name
- Deployment name
- Run ID and provider (Netlab/LabPP/Terraform/etc.)
- Copy/paste of the relevant error section from logs

---

## FAQ

### Can I add my own Netlab or EVE/LabPP server?
This may be enabled per workspace. If allowed, you can add your own server endpoint and use it as the deployment target. If it’s not visible in the UI, ask an admin to enable it.

### Why do some tools redirect or require SSO again?
Some tools use different session mechanisms (cookies vs. localStorage tokens) and require a bridge/redirect. If you see unexpected login loops, report the tool name and approximate timestamp.
