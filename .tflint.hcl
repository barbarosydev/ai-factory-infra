# tflint configuration for every Terraform folder in this repo.
# The bundled terraform plugin needs no download.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
