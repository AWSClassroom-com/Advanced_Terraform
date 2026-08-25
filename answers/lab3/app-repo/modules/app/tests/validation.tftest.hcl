# modules/app/tests/validation.tftest.hcl
# Challenge answer - proves the module's two input validations actually reject
# bad values, which fmt, validate and tflint cannot tell you.
#
# There is no provider block and no credentials are needed. A failed variable
# validation stops the run before a provider is ever configured, which is why
# this check belongs in the Validate stage rather than in Plan.

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
