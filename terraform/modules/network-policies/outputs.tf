output "policy_names" {
  description = "Names of the Kubernetes NetworkPolicy resources created in the platform namespace."
  value = [
    kubernetes_network_policy_v1.default_deny_all.metadata[0].name,
    kubernetes_network_policy_v1.allow_dns_egress.metadata[0].name,
    kubernetes_network_policy_v1.postgres.metadata[0].name,
    kubernetes_network_policy_v1.cnpg_operator.metadata[0].name,
    kubernetes_network_policy_v1.litellm.metadata[0].name,
    kubernetes_network_policy_v1.temporal.metadata[0].name,
    kubernetes_network_policy_v1.phoenix.metadata[0].name,
    kubernetes_network_policy_v1.jobs_and_probes.metadata[0].name,
    kubernetes_network_policy_v1.smoke_probe.metadata[0].name,
  ]
}
