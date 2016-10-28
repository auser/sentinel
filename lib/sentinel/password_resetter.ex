defmodule Sentinel.PasswordResetter do
  alias Ecto.Changeset
  alias Sentinel.ChangesetHashPassword
  alias Sentinel.Config
  alias Sentinel.UserHelper

  @moduledoc """
  Module responsible for handling the password reset logic changeset
  """

  @doc """
  Adds the changes needed to create a password reset token.
  Returns {unhashed_password_reset_token, changeset}
  """
  def create_changeset(nil) do
    changeset =
      UserHelper.model
      |> struct
      |> Changeset.cast(%{}, [], ~w())
      |> Changeset.add_error(:email, "not known")
    {nil, changeset}
  end
  def create_changeset(user) do
    {password_reset_token, hashed_password_reset_token} = generate_token

    changeset =
      user
      |> Changeset.cast(%{}, [], ~w())
      |> Changeset.put_change(:hashed_password_reset_token, hashed_password_reset_token)

    {password_reset_token, changeset}
  end

  @doc """
  Changes a users password, if the reset token matches.
  Returns the changeset
  """
  def reset_changeset(nil, _params) do
    changeset =
      UserHelper.model
      |> struct
      |> Changeset.cast(%{}, [], ~w())
      |> Changeset.add_error(:id, "unknown")
    {nil, changeset}
  end
  def reset_changeset(user, params) do
    user
    |> Changeset.cast(params, [], ~w())
    |> Changeset.put_change(:hashed_password_reset_token, nil)
    |> ChangesetHashPassword.changeset
    |> validate_token
  end

  @doc """
  Generates a random token.
  Returns {token, hashed_token}.
  """
  def generate_token do
    token = SecureRandom.urlsafe_base64(64)
    {token, Config.crypto_provider.hashpwsalt(token)}
  end

  defp validate_token(changeset) do
    token_matches = Config.crypto_provider.checkpw(changeset.params["password_reset_token"],
    changeset.data.hashed_password_reset_token)
    do_validate_token token_matches, changeset
  end

  defp do_validate_token(true, changeset), do: changeset
  defp do_validate_token(false, changeset) do
    Changeset.add_error changeset, :password_reset_token, "invalid"
  end
end
