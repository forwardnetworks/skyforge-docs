# Composite Deployments

Composite deployments are primarily for one workflow shape today:

- `terraform -> netlab`

The engine is still generic underneath, but the authoring model should optimize for that path instead of forcing users to type raw JSON and hidden `env.*` keys.

## Primary Flow

A composite plan has three visible parts in guided mode:

- `Workflow Inputs`: named values you can set once and optionally override when you run the plan
- `Terraform`: the template plus Terraform variables and extra environment
- `Netlab`: the server, deployment, topology path, and Netlab environment

Variable handoff is explicit:

- workflow inputs can map into Terraform variables
- workflow inputs can map into Terraform environment
- workflow inputs can map into Netlab fields or Netlab environment
- Terraform outputs can map into Netlab fields or Netlab environment

Users should not need to type:

- raw JSON for plan inputs
- raw JSON for run overrides
- hidden keys like `env.TF_VAR_region`
- hidden keys like `env.VPN_PEER_IP`

The portal translates the guided form into the existing composite API contract.

## Guided Terraform Plus Netlab Model

### Workflow Inputs

These are named values available at plan start.

Example:

- `region = us-east-1`
- `netlab_server = user:server-1`
- `topology = netlab/BGP/Default-NH/topology.yml`

### Terraform Section

Visible inputs:

- action: `plan|apply|destroy`
- target: for example `aws`
- template source/repo/dir/template
- Terraform variables table
- extra environment table
- declared Terraform outputs

Portal translation:

- Terraform variables become `env.TF_VAR_*`
- Terraform extra environment becomes `env.*`

### Netlab Section

Visible inputs:

- action: `up|down|validate`
- server
- deployment
- topology path
- cleanup
- user-scope root/dir
- Netlab environment table

Portal translation:

- Netlab environment becomes `env.*`

## Example Variable Flow

The page should make handoff visible in plain language.

Example summary:

- `workflow.region -> terraform.var.region`
- `workflow.netlab_server -> netlab.server`
- `workflow.topology -> netlab.topologyPath`
- `terraform.vpn_peer_ip -> netlab.env.VPN_PEER_IP`
- `terraform.vpn_psk -> netlab.env.VPN_PSK`

That is the same execution model the backend already supports. The difference is only the authoring experience.

## What Guided Mode Supports

Guided mode only supports:

- exactly two stages
- first stage `terraform`
- second stage `netlab`
- workflow inputs as binding sources
- Terraform outputs as binding sources
- promoted outputs from Terraform

If a saved plan does not fit that shape, the portal opens it in `Advanced` mode automatically.

## Advanced Mode

Advanced mode keeps the generic composite contract for cases such as:

- `baremetal -> netlab`
- `containerlab`
- unusual binding patterns
- plans with more than two stages

Advanced mode still exposes the real stage graph:

- `stages[]`
- `bindings[]`
- `inputs`
- `outputs`

That is the escape hatch. It is not the primary authoring path.

## Backend Contract

The backend contract does not change in this pass.

Preview:

- `POST /api/users/:id/composite/plan/preview`

Saved plans:

- `GET /api/users/:id/composite/plans`
- `POST /api/users/:id/composite/plans`
- `GET /api/users/:id/composite/plans/:planID`
- `PUT /api/users/:id/composite/plans/:planID`
- `DELETE /api/users/:id/composite/plans/:planID`

Run:

- `POST /api/users/:id/composite/plans/:planID/runs`

The portal now translates the guided editor into the same persisted generic shape.

## Underlying Generic Contract

A composite plan still persists as:

- `stages[]`: ordered logical units with explicit `id`, `provider`, `action`, and `dependsOn`
- `bindings[]`: handoff edges from prior stage outputs or workflow inputs into later stage inputs
- `inputs`: user/admin supplied values available at plan start
- `outputs`: declared stage outputs promoted as run outputs

### Provider Set

- `terraform`
- `netlab`
- `containerlab`
- `baremetal`

### Action Set

- `terraform`: `plan`, `apply`, `destroy`
- `netlab`: `up`, `down`, `validate`
- `containerlab`: `deploy`, `destroy`, `validate`
- `baremetal`: `reserve`, `configure`, `release`, `validate`

## Advanced JSON Reference

Reference payloads remain useful for API consumers and debugging:

- `components/docs/examples/composite-plan-terraform-netlab.json`
- `components/docs/examples/composite-plan-baremetal-netlab.json`

## Validation Rules

A plan is valid only when:

- all stage IDs are unique
- every `dependsOn` target exists
- stage graph is acyclic
- every binding source stage/output exists and precedes target stage
- every binding target stage/input exists
- provider/action pair is allowed

## Checklist

- [x] Keep the existing generic backend contract
- [x] Add guided Terraform-plus-Netlab authoring in portal
- [x] Replace JSON input editors in the main path with key/value editing
- [x] Add explicit variable-flow summaries in the portal
- [x] Fall back to advanced mode for unsupported saved plans
- [x] Keep advanced JSON reference payloads for debugging and API consumers
