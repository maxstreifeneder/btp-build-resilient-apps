##
data "btp_whoami" "orchestrator" {}

output "subaccount_id" {
  value       = btp_subaccount.project.id
  description = "The ID of the project subaccount."
}

output "user" {
  value       = data.btp_whoami.orchestrator.id
  description = "logged on user"
}

output "mail" {
  value       = data.btp_whoami.orchestrator.email
  description = "logged on user mail"
}

output "api_endpoint" {
  value       = module.cloudfoundry_environment.api_endpoint
  description = "The Cloudfoundry API Endpoint"
}

output "space_name" {
  value       = module.cloudfoundry_space.name
  description = "The Cloudfoundry space name"
}

output "cf_org_id" {
  value = module.cloudfoundry_environment.org_id
  description = "The Cloudfoundy ORG ID"
}
