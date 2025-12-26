# Agentic Generation (Iterate Until Valid)

Goal: generate Terraform/netlab/lab template configs and assets using an LLM, while minimizing hallucination risk by **running real validators** and iterating until outputs are workable (or a retry limit is reached).

This is a good fit for a Skyforge “v2” because it turns generation into a controlled pipeline, not a single-shot prompt.

## High-level loop

1. **Plan**
   - Ask for a manifest of intended changes (files to create/modify) plus assumptions and required inputs.
2. **Generate**
   - Have the model emit a **strict JSON manifest** containing file contents (and optionally patch diffs).
3. **Apply**
   - Write outputs into a **sandbox working directory** (never directly into a production repo path).
4. **Validate**
   - Run authoritative tool checks (Terraform/netlab/lab templates + any org policy checks).
5. **Repair**
   - If validation fails, feed back the exact command + stderr and ask for a minimal patch.
6. **Finalize**
   - When all checks pass, produce a diff/PR-ready set of changes for review and merge.

Recommended retry budget: 3–5 repair iterations per request, then stop with a clear error summary.

## Output contract (recommended)

Make the model output **only** JSON in a stable schema so Skyforge can act deterministically:

```json
{
  "intent": "short summary",
  "assumptions": ["..."],
  "inputs_needed": ["..."],
  "files": [
    { "path": "terraform/main.tf", "format": "hcl", "content": "..." },
    { "path": "netlab/topology.yml", "format": "yaml", "content": "..." }
  ],
  "patches": [
    { "path": "README.md", "format": "unified_diff", "content": "..." }
  ],
  "validate": [
    { "name": "terraform_fmt", "command": "terraform fmt -recursive" },
    { "name": "terraform_validate", "command": "terraform validate" }
  ]
}
```

Notes:
- Prefer `files[]` for new files and full rewrites.
- Prefer `patches[]` for small, reviewable edits.
- Treat the model-provided `validate[]` list as *suggestions*; Skyforge should choose the authoritative validation commands.

## Validation-first design

The LLM is a *proposer*; your toolchain is the *authority*.

Practical checks to include:
- Terraform: `terraform fmt`, `terraform validate`, and optionally `terraform plan` against a stubbed backend
- netlab: schema/compile/render checks used by your workflow
- lab templates: schema/compile checks used by your workflow
- Policy checks: provider/module version pinning, naming conventions, forbidden CIDRs, required tags/labels

## Repair loop prompt discipline

When something fails:
- Provide only:
  - failing command
  - exit code
  - stderr/stdout (trimmed)
  - current relevant file(s) or minimal diff context
- Ask for:
  - *minimal patch* that fixes the error (not a full rewrite)
- Require output as:
  - `patches[]` only (unified diff), or a narrowed `files[]` subset

This makes iteration fast and reduces drift.

## Stop conditions

Success:
- All validation steps pass in the sandbox workspace.

Failure (after retry budget):
- Return:
  - best-effort outputs
  - the final failing command + error
  - what information is missing (inputs_needed)
  - a recommended human fix path

## VMware/on-prem considerations

- Plan for restricted egress: internal model hosting, internal registries, offline model distribution.
- Keep prompts/logs redacted (no secrets); generated code is untrusted until validated.
- Expect heterogeneous compute: CPU-only support via quantized models, optional GPU acceleration where available.

## Suggested “v2” implementation sketch

- `LLM Provider`: pluggable (local OpenAI-compatible server first; cloud optional fallback)
- `Workspace Manager`: creates per-run sandbox dirs, collects artifacts, produces diffs
- `Validator Runner`: runs a fixed set of validators per “generator type”
- `Repair Orchestrator`: retries with strict patch-only outputs after the first generation
- `Audit Trail`: stores inputs, prompts (redacted), validation results, diffs, and final artifacts

## Open questions to answer before implementing

- Which exact commands validate `netlab` and lab templates in Skyforge’s workflow?
- Do we want the agent to run `terraform plan` (needs backend strategy), or stop at `validate`?
- What policy checks are mandatory (tags, CIDRs, naming, versions)?
- Where should “golden examples” live for retrieval (RAG)?
