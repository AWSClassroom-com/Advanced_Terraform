# modules/app/tests/validation.tftest.hcl
# Challenge answer - proves the module's two input validations actually reject
# bad values, which fmt, validate and tflint cannot tell you.
#
# mock_provider stands in for the real AWS provider, so this test needs no
# credentials and no region - it checks the configuration and never talks to a
# cloud. That is why the check belongs in the Validate stage and not in Plan.
# Without it, the AWS provider authenticates at configure time and the test
# fails before it ever reaches the validations.

mock_provider "aws" {}

# Defaults for every run. Each run below overrides exactly one of them.
variables {
  user_id     = "user07"
  environment = "staging"
}

run "rejects_the_placeholder" {
  command = plan

  variables {
    user_id = "userXX"
  }

  expect_failures = [var.user_id]
}

run "rejects_an_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}
