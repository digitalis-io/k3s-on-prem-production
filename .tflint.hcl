config {
  # Enable module inspection
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Uncomment and configure the provider plugin for your primary cloud:

# plugin "aws" {
#   enabled = true
#   version = "0.36.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }

# plugin "azurerm" {
#   enabled = true
#   version = "0.27.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
# }

# plugin "google" {
#   enabled = true
#   version = "0.29.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-google"
# }

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}
