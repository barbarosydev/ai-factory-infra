package k3d

good_config := {
	"kind": "Simple",
	"kubeAPI": {"hostIP": "127.0.0.1"},
	"ports": [
		{"port": "127.0.0.1:8080:80", "nodeFilters": ["loadbalancer"]},
		{"port": "127.0.0.1:7233:7233", "nodeFilters": ["loadbalancer"]},
	],
	"options": {"kubeconfig": {"updateDefaultKubeconfig": false, "switchCurrentContext": false}},
}

test_local_only_config_passes if {
	count(deny) == 0 with input as good_config
}

test_port_on_all_interfaces_fails if {
	some msg in deny with input as object.union(good_config, {"ports": [{"port": "0.0.0.0:8080:80"}]})
	contains(msg, "\"0.0.0.0:8080:80\"")
}

test_port_without_host_ip_fails if {
	some msg in deny with input as object.union(good_config, {"ports": [{"port": "8080:80"}]})
	contains(msg, "\"8080:80\"")
}

test_api_on_all_interfaces_fails if {
	some msg in deny with input as object.union(good_config, {"kubeAPI": {"hostIP": "0.0.0.0"}})
	contains(msg, "kubeAPI.hostIP")
}

test_update_default_kubeconfig_fails if {
	some msg in deny with input as object.union(good_config, {"options": {"kubeconfig": {"updateDefaultKubeconfig": true, "switchCurrentContext": false}}})
	contains(msg, "updateDefaultKubeconfig")
}

test_missing_kubeconfig_options_fails if {
	some msg in deny with input as object.remove(good_config, ["options"])
	contains(msg, "switchCurrentContext")
}
