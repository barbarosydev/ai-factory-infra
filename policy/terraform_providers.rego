# Rule 3: the Kubernetes and Helm providers name the project kubeconfig
# (hard rule 1).
#
# Input: terraform/environments/local/providers.tf, parsed by Conftest's
# hcl2 parser. Providers arrive as input.provider.<name>[0].
#
# Both providers must set `config_path` and `config_context`. Without them
# the providers fall back to ~/.kube/config and its current context, which
# holds real AKS clusters. In the Helm provider 3.x, `kubernetes = { ... }`
# is an attribute (an object); the old 2.x block syntax arrives as a list,
# and both shapes are read here.
package terraform.providers

required := ["config_path", "config_context"]

# The connection settings of each provider, by name.
connection(name) := blocks if {
	name == "kubernetes"
	blocks := input.provider.kubernetes
}

connection(name) := [kube |
	some block in input.provider.helm
	some kube in as_list(block.kubernetes)
] if {
	name == "helm"
}

as_list(x) := x if is_array(x)

as_list(x) := [x] if is_object(x)

deny contains msg if {
	some name in ["kubernetes", "helm"]
	not input.provider[name]
	msg := sprintf("provider \"%s\" is missing from this file; it must be configured here with `config_path` and `config_context` (hard rule 1)", [name])
}

deny contains msg if {
	some name in ["kubernetes", "helm"]
	input.provider[name]
	count(connection(name)) == 0
	msg := sprintf("provider \"%s\" has no kubernetes connection settings; set `config_path` and `config_context` (hard rule 1)", [name])
}

deny contains msg if {
	some name in ["kubernetes", "helm"]
	some settings in connection(name)
	some attr in required
	object.get(settings, attr, "") == ""
	msg := sprintf("provider \"%s\" does not set `%s`; without it the provider uses ~/.kube/config (hard rule 1)", [name, attr])
}
