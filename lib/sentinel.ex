defmodule Sentinel do
  @moduledoc """
  Module responsible for the macros that mount the Sentinel routes
  """

  require Ueberauth

  alias Sentinel.Config
  alias Sentinel.Controllers.Html
  alias Sentinel.Controllers.Json

  @doc """
  Mount's Sentinel HTML routes inside your application
  """
  defmacro mount_html do
    quote do
      require Ueberauth

      get "/users/new", Html.UserController, :new
      post "/users", Html.UserController, :create
      if Sentinel.invitable? do
        get "/users/:id/invited", Html.UserController, :invitation_registration
        post "/users/:id/invited", Html.UserController, :invited
      end
      if Sentinel.confirmable? do
        get "/confirmation_instructions", Html.UserController, :confirmation_instructions
        post "/confirmation", Html.UserController, :confirm
      end

      get "/sessions/new", Html.SessionController, :new
      post "/sessions", Html.SessionController, :create
      delete "/sessions", Html.SessionController, :delete

      #FIXME setup
      get "/:provider", Html.SessionController, :request
      get "/:provider/callback", Html.SessionController, :callback
      post "/:provider/callback", Html.SessionController, :callback

      get "/password/new", Html.PasswordController, :new
      post "/password", Html.PasswordController, :create
      post "/password/reset", Html.PasswordController, :reset #FIXME
      get "/account", Html.AccountController, :edit
      put "/account", Html.AccountController, :update
    end
  end

  @doc """
  Mount's Sentinel JSON API routes inside your application
  """
  defmacro mount_api do
    if Sentinel.invitable? && !Sentinel.invitable_configured? do
      raise "Must configure :sentinel :invitation_registration_url when using sentinel invitable API"
    end

    quote do
      require Ueberauth

      post "/users", Json.UserController, :create
      if Sentinel.invitable? do
        post "/users/:id/invited", Json.UserController, :invited
      end
      if Sentinel.confirmable? do
        post "/confirmation", Json.UserController, :confirm
      end

      post "/sessions", Json.SessionController, :create
      delete  "/sessions", Json.SessionController, :delete

      get "/password/new", Json.PasswordController, :new
      put "/password", Json.PasswordController, :update

      get "/account", Json.AccountController, :show
      put "/account", Json.AccountController, :update

      get "/:provider", Json.SessionController, :request
      get "/:provider/callback", Json.SessionController, :callback
      post "/:provider/callback", Json.SessionController, :callback
    end
  end

  def invitable? do
    Config.invitable
  end

  def invitable_configured? do
    Config.invitable_configured?
  end

  def confirmable? do
    Config.confirmable
  end
end
