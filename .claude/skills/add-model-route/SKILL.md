---
name: add-model-route
description: Add or change a LiteLLM model route (which Ollama model an agent name such as pm-agent, dev-agent or sec-agent uses). Use when swapping a model, adding an agent route, or changing model settings.
---

# Add or change a model route

Agent names stay stable; only the model behind them changes. All routes live in one Terraform variable in `terraform/environments/local` (the LiteLLM model map, passed to `terraform/modules/litellm`).

1. Check the model exists and fits: `ollama list`. On this 36 GB Mac keep models at or below about 10 GB while the cluster runs. Check the real size in `ollama list`, not the name: `gemma4:e4b` is 9.5 GB. If the model is missing, ask before `ollama pull <model>` and say its size.
2. Edit `variable "model_routes"` in `terraform/environments/local/variables.tf`: one entry per agent name (`"<agent>" = "<ollama-model>"`), which `terraform/modules/litellm` renders as `ollama_chat/<model>` through the `ollama` Service (`http://ollama:11434`) for native `/api/chat` tool calling, reasoning, and multimodal vision support. Do not address the Mac directly.
3. Adding or changing a key in `model_routes` automatically creates its `litellm-<agent>-key` Kubernetes Secret (write-only `data_wo`) and updates `bootstrap_hash` on the bootstrap Job (`litellm-bootstrap-keys-v<secret_version>-<bootstrap_hash>`), so Kubernetes re-runs the Job on the next `task apply` without needing a manual `secret_version` bump.
4. Update the agent lists in `scripts/access.sh` and `tests/smoke/litellm.sh` if a new agent name was added, and add the model to `REQUIRED_MODELS` in `scripts/doctor-prereqs.sh` when it is a new model.
5. Run `task lint`, then `task plan` and show the diff. Ask before `task apply`.
6. After apply, run `task doctor`; it sends a real completion to every route.

Cloud models (for example Claude) are out of scope until API credit exists (see `docs/adr/0004-model-gateway-and-agent-routes.md`); when added, the key comes from the macOS Keychain at run time, never a file.
