defmodule Sentinel.Authenticator do
  @moduledoc """
  Handles Sentinel authentication logic
  """

  alias Sentinel.Config
  alias Sentinel.UserHelper

  @doc """
  Tries to authenticate a user with the given email and password.
  Returns:
  * {:ok, token} if a confirmed user is found. The token has to be send in the "authorization" header on following requests: "Authorization: Bearer \#{token}"
  * {:error, message} if the user was not confirmed before or no matching user was found
  """
  @unconfirmed_account_error_message "Account not confirmed yet. Please follow the instructions we sent you by email."
  def authenticate_by_email(email, password) do
    email
    |> String.downcase
    |> UserHelper.get_by_email
    |> authenticate(password)
  end

  @doc """
  Tries to authenticate a user with the given username and password.
  Returns:
  * {:ok, token} if a confirmed user is found. The token has to be send in the "authorization" header on following requests: "Authorization: Bearer \#{token}"
  * {:error, message} if the user was not confirmed before or no matching user was found
  """
  def authenticate_by_username(username, password) do
    username
    |> UserHelper.get_by_username
    |> authenticate(password)
  end

  @doc """
  Compares user password and ensures user is confirmed if applicable
  """
  def authenticate(user, password) do
    case check_password(user, password) do
      {:ok, %{confirmed_at: nil}} -> user |> confirmation_required?
      {:ok, _} -> {:ok, user}
      error -> error
    end
  end

  @unknown_password_error_message "Unknown email or password"
  defp check_password(nil, _) do
    Config.crypto_provider.dummy_checkpw
    {:error, %{base: @unknown_password_error_message}}
  end
  defp check_password(user, password) do
    if Config.crypto_provider.checkpw(password, user.hashed_password) do
      {:ok, user}
    else
      {:error, %{base: @unknown_password_error_message}}
    end
  end

  defp confirmation_required?(user) do
    case Config.confirmable do
      :required ->
        {:error, %{base: @unconfirmed_account_error_message}}
      _ ->
        {:ok, user}
    end
  end
end
