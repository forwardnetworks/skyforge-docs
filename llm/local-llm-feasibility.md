# Local LLM Feasibility (VMware / On-Prem)

Running a local LLM to generate Terraform/netlab/lab template configs is very feasible. The largest risks are **correctness** and **operational fit** (compute, latency, and deployment constraints), not model “training”.

## What “local LLM” means here

- A model server runs inside your VMware environment (VM or Kubernetes).
- Skyforge calls it over an internal API to do text/code generation.
- You add validation/repair loops to keep outputs correct.

## Deployment patterns

### 1) Easiest integration: OpenAI-compatible API locally

Run an inference server that exposes OpenAI-style endpoints (or a thin adapter that does).
This lets Skyforge treat “local” and “cloud” similarly.

Common options:
- `Ollama` (very easy to run; good developer ergonomics)
- `llama.cpp` server (efficient; works well with quantized models)
- `vLLM` (great throughput on NVIDIA GPUs; more ops-heavy)
- `TGI` (Hugging Face Text Generation Inference; strong for serving)

### 2) Direct provider client

Skyforge talks to the server’s native API. This can be fine, but you lose portability.

## Compute considerations (VMware)

- **CPU-only is possible** (especially with quantized models), but latency may be high for iterative workflows.
- **GPU acceleration** is a major quality-of-life improvement. If you have NVIDIA GPUs and can do GPU passthrough (vSphere) or run on bare metal nodes, you can host stronger models.
- **Quantization** (4-bit/8-bit) is often the enabler for “fits on available hardware”.

What matters most for config generation:
- Steady latency (so “repair loops” don’t feel painful)
- Enough context window to include templates/examples + current project facts

## Do you need training data?

Usually no.

Start with:
- A decent instruction-tuned model
- Strong prompt constraints and output contracts
- Retrieval of your own templates/examples (RAG)
- Validation and repair loops

Consider fine-tuning only if:
- You have a large, clean set of input→output examples,
- You need highly consistent house style,
- Prompting/RAG + validation still isn’t reliable enough.

## Operational concerns for on-prem

- **Data handling:** keep prompts/logs free of secrets; treat generated code as untrusted until validated.
- **Caching:** cache retrieved examples/templates and model responses for common tasks.
- **Observability:** log prompts/outputs (redacted) + validation errors to improve reliability.
- **Failover:** allow swapping between local and remote providers if local capacity is constrained.
