import Config

config :grabakey,
  ecto_repos: [Grabakey.Repo],
  generators: [binary_id: true]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"