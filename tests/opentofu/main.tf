# Fixture module for opentofu-selftest.yml. Deliberately tiny: one variable,
# one resource, one output. The test in tests/ mocks the provider, so nothing
# is created and no credentials are needed.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

variable "prefix" {
  description = "Prefix for the generated name."
  type        = string
  default     = "selftest"
}

resource "random_pet" "this" {
  prefix = var.prefix
}

output "name" {
  description = "Generated name."
  value       = random_pet.this.id
}
