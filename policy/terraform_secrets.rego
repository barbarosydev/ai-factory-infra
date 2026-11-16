# Rule 1: Kubernetes Secrets are write-only (hard rule 5).
#
# Input: every Terraform file (*.tf), parsed by Conftest's hcl2 parser.
# Each resource arrives as input.resource.<type>.<name>[0].
#
# A kubernetes_secret_v1 must carry its values in `data_wo` with a
# `data_wo_revision`, so the values stay null in terraform.tfstate. The
# readable attributes `data`, `string_data` and `binary_data` would store
# them in state. Passwords come from `ephemeral "random_password"`; a plain
# `resource "random_password"` would also write its result to state.
package terraform.secrets

readable_attributes := ["data", "string_data", "binary_data"]

deny contains msg if {
	some name, blocks in input.resource.kubernetes_secret_v1
	some attr in readable_attributes
	some block in blocks
	block[attr]
	msg := sprintf("kubernetes_secret_v1.%s sets `%s`, which stores the value in Terraform state; use `data_wo` and `data_wo_revision` instead (docs/secrets.md)", [name, attr])
}

deny contains msg if {
	some name, blocks in input.resource.kubernetes_secret_v1
	some attr in ["data_wo", "data_wo_revision"]
	some block in blocks
	not block[attr]
	msg := sprintf("kubernetes_secret_v1.%s does not set `%s`; write-only Secrets need both `data_wo` and `data_wo_revision` (docs/secrets.md)", [name, attr])
}

deny contains msg if {
	some name, _ in input.resource.random_password
	msg := sprintf("resource \"random_password\" \"%s\" stores the password in Terraform state; declare it as `ephemeral \"random_password\"` instead (docs/secrets.md)", [name])
}
