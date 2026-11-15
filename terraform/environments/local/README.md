# terraform/environments/local

Local k3d environment: pinned providers (`kubernetes ~> 3.5`, `helm ~> 3.3`, `random ~> 3.8`), the `ai-platform` namespace, and the module calls for the local stack. State stays here, local and gitignored.

## Usage

```bash
task plan
task apply
```
