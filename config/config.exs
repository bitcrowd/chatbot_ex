# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

config :chatbot, Chatbot.Repo, types: Chatbot.PostgrexTypes
config :chatbot, openai_key: "your openai API key"
config :nx, default_backend: EXLA.Backend
import_config "config/endpoint.exs"
import_config "config/logger.exs"
import_config "config/phoenix.exs"
import_config "config/repo.exs"
