# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
config :logger, :console,
  level: :info

config :comeonin, :bcrypt_log_rounds, 4

config :sentinel,
  crypto_provider: Comeonin.Bcrypt, #FIXME make this a default
  auth_handler: Sentinel.AuthHandler,
  user_view: Sentinel.UserView

config :guardian, Guardian,
  allowed_algos: ["HS512"], # optional
  verify_module: Guardian.JWT,  # optional
  ttl: { 30, :days },
  verify_issuer: true, # optional
  serializer: Sentinel.GuardianSerializer,
  hooks: GuardianDb,
  permissions: Application.get_env(:sentinel, :permissions)#,
  #issuer: "Sentinel",
  #secret_key: "guardian_sekret", #FIXME collapse these two

config :guardian_db, GuardianDb,
  repo: Application.get_env(:sentinel, :repo)

config :sentinel, Sentinel.Mailer,
  adapter: Bamboo.LocalAdapter

config :bamboo, :refute_timeout, 10

#FIXME this doesn't appear to do much for the world, unfortunately
config :ueberauth, Ueberauth,
  providers: [
    identity: {
      Ueberauth.Strategy.Identity,
      [
        callback_methods: ["POST"],
        uid_field: :email,
        nickname_field: :email,
      ]
    },
  ]

import_config "#{Mix.env}.exs"
