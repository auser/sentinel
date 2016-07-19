defmodule Sentinel.Authenticator do
  alias Sentinel.Util
  alias Sentinel.UserHelper

  @doc """
  Tries to authenticate a user with the given email and password.
  Returns:
  * {:ok, token} if a confirmed user is found. The token has to be send in the "authorization" header on following requests: "Authorization: Bearer \#{token}"
  * {:error, message} if the user was not confirmed before or no matching user was found
  """
  @unconfirmed_account_error_message "Account not confirmed yet. Please follow the instructions we sent you by email."
  def authenticate_by_email(email, password) do
    String.downcase(email)
    |> UserHelper.find_by_email
    |> authenticate(password, "email")
  end
  def authenticate_by_username(username, password) do
    UserHelper.find_by_username(username)
    |> authenticate(password, "username")
  end

  @unknown_password_error_message "Unknown ~s or password"
  def authenticate(user, password, identifier_name) do
    case check_password(user, password) do
      {:ok, %{confirmed_at: nil}} -> user |> confirmation_required?
      {:ok, _} -> {:ok, user}
      _ ->
        {:error, %{base: to_string(:io_lib.format(@unknown_password_error_message, [identifier_name]))}}
    end
  end

  defp check_password(nil, _) do
    Util.crypto_provider.dummy_checkpw
    {:error}
  end
  defp check_password(user, password) do
    if Util.crypto_provider.checkpw(password, user.hashed_password) do
      {:ok, user}
    else
      {:error}
    end
  end

  defp confirmation_required?(user) do
    case Application.get_env(:sentinel, :confirmable) do
      :required ->
        {:error, %{base: @unconfirmed_account_error_message}}
      _ ->
        {:ok, user}
    end
  end
end
