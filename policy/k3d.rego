# Rule 5: the k3d cluster is reachable from this Mac only and leaves the
# global kubeconfig alone (hard rule 1).
#
# Input: cluster/k3d-config.yaml (yaml).
#
#   - every published port (`ports[].port`) binds to 127.0.0.1, and the API
#     server's `kubeAPI.hostIP` is 127.0.0.1, so nothing listens on the LAN;
#   - `options.kubeconfig.updateDefaultKubeconfig` and `switchCurrentContext`
#     are explicitly false. k3d defaults both to true, which would write to
#     ~/.kube/config (real AKS contexts) and switch its current context.
package k3d

loopback := "127.0.0.1"

deny contains msg if {
	some entry in input.ports
	not startswith(entry.port, concat("", [loopback, ":"]))
	msg := sprintf("cluster/k3d-config.yaml publishes port %q on all interfaces; prefix it with %s: so it binds to this Mac only", [entry.port, loopback])
}

deny contains msg if {
	object.get(input, ["kubeAPI", "hostIP"], null) != loopback
	msg := sprintf("cluster/k3d-config.yaml: kubeAPI.hostIP must be %s so the API server is reachable from this Mac only", [loopback])
}

deny contains msg if {
	some option in ["updateDefaultKubeconfig", "switchCurrentContext"]
	object.get(input, ["options", "kubeconfig", option], null) != false
	msg := sprintf("cluster/k3d-config.yaml: set options.kubeconfig.%s: false; k3d defaults it to true and would change ~/.kube/config (hard rule 1)", [option])
}
