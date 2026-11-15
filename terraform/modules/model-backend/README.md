# terraform/modules/model-backend

Creates the `ollama` ExternalName Kubernetes Service pointing at `host.k3d.internal:11434`, giving LiteLLM one stable in-cluster address (`http://ollama:11434`) for models running natively on the Mac.
