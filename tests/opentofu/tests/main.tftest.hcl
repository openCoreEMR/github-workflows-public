mock_provider "random" {
  mock_resource "random_pet" {
    defaults = {
      id = "selftest-mocked-pet"
    }
  }
}

run "uses_default_prefix" {
  command = apply

  assert {
    condition     = random_pet.this.prefix == "selftest"
    error_message = "random_pet.this should default to the selftest prefix."
  }

  assert {
    condition     = output.name == "selftest-mocked-pet"
    error_message = "The name output should expose the random_pet id."
  }
}

run "passes_prefix_through" {
  command = apply

  variables {
    prefix = "custom"
  }

  assert {
    condition     = random_pet.this.prefix == "custom"
    error_message = "random_pet.this should use the prefix variable."
  }
}
