# terraform/modules/postgres

Installs the CloudNativePG operator (`0.29.1`, operator `1.30.1`) and a single-instance PostgreSQL `16` cluster (`cluster` chart `0.9.0`) in the target namespace.

## What it provisions

- Three databases: `temporal`, `temporal_visibility` (owned by `temporal`), and `litellm` (owned by `litellm`).
- Two non-superuser roles (`temporal`, `litellm`) with `pg_hba` rules restricting each role to its own database(s).
- Passwords generated via `ephemeral "random_password"` and stored in `kubernetes_secret_v1` using write-only `data_wo`, so no password is saved in Terraform state.
