###############################################################################################
# Setup of names in accordance to naming convention
###############################################################################################
locals {
  random_uuid               = uuid()
  project_subaccount_domain = "github-actions-teched23-resilient-apps"
  project_subaccount_cf_org = "github-actions-teched-dev"
}

###############################################################################################
# Creation of subaccount
###############################################################################################
resource "btp_subaccount" "project" {
  name      = "${var.subaccount_name}-${local.random_uuid}"
  subdomain = local.random_uuid
  region    = lower(var.region)
}

###############################################################################################
# Assignment of users as sub account administrators
###############################################################################################
resource "btp_subaccount_role_collection_assignment" "subaccount-admins" {
  for_each             = toset("${var.subaccount_admins}")
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "Subaccount Administrator"
  user_name            = each.value
}

###############################################################################################
# Assignment of users as sub account service administrators
###############################################################################################
resource "btp_subaccount_role_collection_assignment" "subaccount-service-admins" {
  for_each             = toset("${var.subaccount_service_admins}")
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "Subaccount Service Administrator"
  user_name            = each.value
}

######################################################################
# Creation of Cloud Foundry environment
######################################################################
module "cloudfoundry_environment" {
  source                = "./modules/envinstance-cloudfoundry/"
  subaccount_id         = btp_subaccount.project.id
  instance_name         = local.project_subaccount_cf_org
  plan_name             = "free"
  cloudfoundry_org_name = local.project_subaccount_cf_org
}

######################################################################
# Creation of Cloud Foundry space
######################################################################
module "cloudfoundry_space" {
  source              = "./modules/cloudfoundry-space/"
  cf_org_id           = module.cloudfoundry_environment.org_id
  name                = var.cf_space_name
  cf_space_managers   = var.cf_space_managers
  cf_space_developers = var.cf_space_developers
  cf_space_auditors   = var.cf_space_auditors
}

resource "time_sleep" "wait_a_few_seconds" {
  create_duration = "30s"
}

######################################################################
# Entitlement of all services and apps
######################################################################
resource "btp_subaccount_entitlement" "name" {
  depends_on = [time_sleep.wait_a_few_seconds]
  for_each = {
    for index, entitlement in var.entitlements :
    index => entitlement
  }
  subaccount_id = btp_subaccount.project.id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
}



resource "btp_subaccount_entitlement" "appstudio" {
  depends_on    = [time_sleep.wait_a_few_seconds]
  subaccount_id = btp_subaccount.project.id
  service_name  = "sapappstudio"
  plan_name     = "free"
  amount        = 1
}


resource "btp_subaccount_entitlement" "cicd" {
  depends_on    = [time_sleep.wait_a_few_seconds]
  subaccount_id = btp_subaccount.project.id
  service_name  = "cicd-app"
  plan_name     = "free"
  amount        = 1
}


######################################################################
# Create service instances (and service keys when needed)
######################################################################
# connectivitiy
module "create_cf_service_instance_01" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "connectivity"
  plan_name    = "lite"
  parameters   = null
}
# destination
module "create_cf_service_instance_02" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "destination"
  plan_name    = "lite"
  parameters   = null
}
# html5-apps-repo
module "create_cf_service_instance_03" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "html5-apps-repo"
  plan_name    = "app-host"
  parameters   = null
}
# enterprise-messaging
module "create_cf_service_instance_ems" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "enterprise-messaging"
  plan_name    = "default"
  parameters = jsonencode(
    {
      "emname" : "tfe",
      "namespace" : "tfe/bpem/em",
      "version" : "1.1.0",
      "resources" : {
        "units" : "10"
      },
      "options" : {
        "management" : true,
        "messagingrest" : true,
        "messaging" : true
      },
      "rules" : {

      }
    }
  )
}
# Create service key for Cloudfoundry service instance of enterprise-messaging
resource "cloudfoundry_service_key" "key_enterprise-messaging" {
  name             = "key_enterprise-messaging"
  service_instance = module.create_cf_service_instance_ems.id
}

# application-logs
module "create_cf_service_instance_05" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "application-logs"
  plan_name    = "lite"
  parameters   = null
}
# xsuaa
module "create_cf_service_instance_06" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "xsuaa"
  plan_name    = "application"
  parameters   = null
}
# hana-cloud
module "create_cf_service_instance_hana_cloud" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "hana-cloud"
  plan_name    = "hana-free"
  parameters   = jsonencode({ "data" : { "memory" : 30, "edition" : "cloud", "systempassword" : "Abcd1234", "whitelistIPs" : ["0.0.0.0/0"] } })
}
# hana
module "create_cf_service_instance_08" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, module.create_cf_service_instance_hana_cloud, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "hana"
  plan_name    = "hdi-shared"
  parameters   = null
}
# autoscaler
module "create_cf_service_instance_09" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "autoscaler"
  plan_name    = "standard"
  parameters   = null
}

######################################################################
# Create app subscriptions
######################################################################
resource "btp_subaccount_subscription" "app" {
  subaccount_id = btp_subaccount.project.id
  for_each = {
    for index, entitlement in var.entitlements :
    index => entitlement if contains(["app"], entitlement.type)
  }

  app_name   = each.value.service_name
  plan_name  = each.value.plan_name
  depends_on = [btp_subaccount_entitlement.name]
}

resource "btp_subaccount_subscription" "sapappstudio" {
  subaccount_id = btp_subaccount.project.id

  app_name   = "sapappstudio"
  plan_name  = "free"
  depends_on = [btp_subaccount_entitlement.appstudio]
}


resource "btp_subaccount_subscription" "cicd" {
  subaccount_id = btp_subaccount.project.id

  app_name   = "cicd-app"
  plan_name  = "free"
  depends_on = [btp_subaccount_entitlement.cicd]
}

locals {

  # Nested loop over both lists, and flatten the result.
  rc_assignments = distinct(flatten([
    for developer in var.subaccount_developers : [
      for role_collection in var.developer_role_collections : {
        user            = developer
        role_collection = role_collection
      }
    ]
  ]))
}

resource "btp_subaccount_role_collection_assignment" "rolecollections" {
  for_each = { for idx, entry in local.rc_assignments : "${entry.user}-${entry.role_collection}" => entry }

  subaccount_id        = btp_subaccount.project.id
  user_name            = each.value.user
  role_collection_name = each.value.role_collection
  depends_on           = [btp_subaccount_subscription.app, btp_subaccount_subscription.sapappstudio]
}
