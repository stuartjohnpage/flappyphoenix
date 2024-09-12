import Config

# In test we don't send emails
config :flappy, Flappy.Mailer, adapter: Swoosh.Adapters.Test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :flappy, FlappyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "XYgiqcZ+p1SlI0wWVxlo0ujUFL8jfypjf0N3dwi8MFnxeQjagI3xbvnj8OoO7mfo",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test

# Initialize plugs at runtime for faster test compilation

# Enable helpful, but potentially expensive runtime checks
