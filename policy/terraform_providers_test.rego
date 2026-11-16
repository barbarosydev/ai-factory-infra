package terraform.providers

settings := {"config_context": "${var.kube_context}", "config_path": "${local.kubeconfig_path}"}

test_both_providers_pass if {
	count(deny) == 0 with input as {"provider": {
		"helm": [{"kubernetes": settings}],
		"kubernetes": [settings],
	}}
}

test_helm_2x_block_syntax_is_read if {
	count(deny) == 0 with input as {"provider": {
		"helm": [{"kubernetes": [settings]}],
		"kubernetes": [settings],
	}}
}

test_kubernetes_without_context_fails if {
	deny["provider \"kubernetes\" does not set `config_context`; without it the provider uses ~/.kube/config (hard rule 1)"] with input as {"provider": {
		"helm": [{"kubernetes": settings}],
		"kubernetes": [{"config_path": "${local.kubeconfig_path}"}],
	}}
}

test_helm_without_path_fails if {
	deny["provider \"helm\" does not set `config_path`; without it the provider uses ~/.kube/config (hard rule 1)"] with input as {"provider": {
		"helm": [{"kubernetes": {"config_context": "${var.kube_context}"}}],
		"kubernetes": [settings],
	}}
}

test_helm_without_connection_fails if {
	some msg in deny with input as {"provider": {
		"helm": [{}],
		"kubernetes": [settings],
	}}
	contains(msg, "no kubernetes connection settings")
}

test_missing_provider_fails if {
	some msg in deny with input as {"provider": {"kubernetes": [settings]}}
	contains(msg, "provider \"helm\" is missing")
}
