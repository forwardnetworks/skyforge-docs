# Generating Terraform / netlab / lab template Configs Safely

For infrastructure/config generation, treat the LLM as a *proposer* and your toolchain as the *authority*.

## Recommended workflow: plan → generate → validate → repair

1. **Plan**
   - Produce a file manifest (which files will be created/modified) and high-level intent.
2. **Generate**
   - Emit outputs in strict formats (JSON/YAML/HCL) with explicit constraints.
3. **Validate**
   - Run real validators and compilers:
     - Terraform: `terraform fmt` + `terraform validate` (and optionally `tflint`)
     - netlab: whatever CLI checks your workflow uses (schema/compile)
     - lab templates: whatever schema/compilation checks exist in your toolchain
4. **Repair**
   - Feed back the exact error output and ask for a minimal patch (repeat until clean or retry limit hit).

## Output contracts (high leverage)

Make the model output a strict JSON “manifest” so Skyforge can apply changes deterministically:

- `files[]`: `{ path, format, content }`
- `edits[]` (optional): `{ path, patch }` for small changes
- `assumptions[]`: list of assumptions made
- `requires[]`: external dependencies (provider versions, modules, images)

This gives you:
- predictable file writes
- easy diff/review
- an audit trail

## RAG: use your existing configs as “training”

Instead of fine-tuning early, retrieve:
- “golden” examples from your repos
- your organization’s naming conventions
- provider/module pinning rules
- netlab/lab patterns that your environment already uses

Then include only the top few relevant snippets in the prompt.

## Guardrails that matter for infra generation

- Enforce schemas (JSON Schema/YAML schema) when possible.
- Disallow unknown keys in structured outputs.
- Keep secrets out of prompts and outputs (use references/secret managers).
- Prefer generating small diffs over regenerating whole trees.

## VMware-specific notes

- Expect network egress restrictions; plan for offline model distribution and internal artifact registries.
- If using GPUs, confirm your vSphere GPU passthrough/MIG strategy and how it maps to your chosen serving stack.
- Keep the inference service inside the trusted network boundary; treat it like any other internal platform dependency.
