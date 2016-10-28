defmodule Sentinel.Controllers.Json.SessionController do
  @moduledoc """
  Handles the session create and destroy actions for JSON APIs
  """

  use Phoenix.Controller
  #alias Plug.Conn
  #alias Sentinel.Authenticator
  #alias Sentinel.Config
  #alias Sentinel.UserHelper
  #alias Sentinel.Util
  alias Ueberauth.Strategy.Helpers

  plug Ueberauth
  #plug Guardian.Plug.VerifyHeader
  #plug Guardian.Plug.EnsureAuthenticated, %{handler: Config.auth_handler} when action in [:delete]
  #plug Guardian.Plug.LoadResource

  # FIXME UEBERAUTH FIXME
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    IO.puts "good fail"
    Util.send_error(conn, %{error: "Failed to authenticate"}, 401)
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    IO.puts "good"
    IO.inspect auth
    json conn, :ok
    #case UserFromAuth.find_or_create(auth) do
    #  {:ok, user} ->
    #    conn
    #    |> put_flash(:info, "Successfully authenticated.")
    #    |> put_session(:current_user, user)
    #    |> redirect(to: "/")
    #  {:error, reason} ->
    #    conn
    #    |> put_flash(:error, reason)
    #    |> redirect(to: "/")
    #end
  end

  def callback(conn, params) do
    IO.puts "FAIL BAD"
    IO.inspect conn
    json conn, :ok
  end

  #@doc """
  #Log in as an existing user.
  #Parameter are "email" and "password".
  #Responds with status 200 and {token: token} if credentials were correct.
  #Responds with status 401 and {errors: error_message} otherwise.
  #"""
  #def create(conn, %{"username" => username, "password" => password}) do
  #  case Authenticator.authenticate_by_username(username, password) do
  #    {:ok, user} ->
  #      permissions = UserHelper.model.permissions(user.role)

  #      case Guardian.encode_and_sign(user, :token, permissions) do
  #        {:ok, token, _encoded_claims} -> json conn, %{token: token}
  #        {:error, :token_storage_failure} -> Util.send_error(conn, %{error: "Failed to store session, please try to login again using your new password"})
  #        {:error, reason} -> Util.send_error(conn, %{error: reason})
  #      end
  #    {:error, errors} -> Util.send_error(conn, errors, 401)
  #  end
  #end

  #def create(conn, %{"email" => email, "password" => password}) do
  #  case Authenticator.authenticate_by_email(email, password) do
  #    {:ok, user} ->
  #      permissions = UserHelper.model.permissions(user.role)

  #      case Guardian.encode_and_sign(user, :token, permissions) do
  #        {:ok, token, _encoded_claims} ->
  #         json conn, %{token: token}
  #        {:error, :token_storage_failure} -> Util.send_error(conn, %{error: "Failed to store session, please try to login again using your new password"})
  #        {:error, reason} -> Util.send_error(conn, %{error: reason})
  #      end
  #    {:error, errors} ->
  #      Util.send_error(conn, errors, 401)
  #  end
  #end

  #@doc """
  #Destroy the active session.
  #Will delete the authentication token from the user table.
  #Responds with status 200 if no error occured.
  #"""
  #def delete(conn, _params) do
  #  token = conn |> Conn.get_req_header("authorization") |> List.first

  #  case Guardian.revoke! token do
  #    :ok -> json conn, :ok
  #    {:error, :could_not_revoke_token} -> Util.send_error(conn, %{error: "Could not revoke the session token"}, 422)
  #    {:error, error} -> Util.send_error(conn, error, 422)
  #  end
  #end

  #def request(conn, params) do
  #  json conn, %{callback_url: Helpers.callback_url(conn)}
  #end
end
