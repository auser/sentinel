defmodule AuthenticatorTest do
  use Sentinel.UnitCase

  alias Ecto.DateTime
  alias Sentinel.Authenticator
  alias Sentinel.Config
  alias Mix.Config

  defp password do
    "password"
  end

  setup do
    hashed_password = Sentinel.Config.crypto_provider.hashpwsalt(password)
    confirmed_user = Factory.insert(
      :user,
      hashed_password: hashed_password,
      confirmed_at: DateTime.utc
    )
    hashed_password = Sentinel.Config.crypto_provider.hashpwsalt(password)
    user = Factory.insert(:user, hashed_password: hashed_password)
    {:ok, %{user: user, confirmed_user: confirmed_user}}
  end

  test "authenticate a confirmed user", %{confirmed_user: user} do
    {:ok, _} = Authenticator.authenticate_by_email(user.email, password)
  end

  test "authenticate a confirmed user - case insensitive", %{confirmed_user: user} do
    {:ok, _} =
      String.upcase(user.email)
      |> Authenticator.authenticate_by_email(password)
  end

  test "authenticate an unconfirmed user - confirmable default/optional", %{user: user} do
    Config.persist([sentinel: [confirmable: :optional]])
    assert Authenticator.authenticate_by_email(user.email, password) == {:ok, user}
  end

  test "authenticate an unconfirmed user - confirmable false", %{user: user} do
    Config.persist([sentinel: [confirmable: :false]])
    assert Authenticator.authenticate_by_email(user.email, password) == {:ok, user}
  end

  test "authenticate an unconfirmed user - confirmable required", %{user: user} do
    Config.persist([sentinel: [confirmable: :required]])
    assert Authenticator.authenticate_by_email(user.email, password) =={:error, %{base: "Account not confirmed yet. Please follow the instructions we sent you by email."}}
  end

  test "authenticate an unknown user" do
    assert Authenticator.authenticate_by_email("unknown@example.com", password) == {:error, %{base: "Unknown email or password"}}
  end
end
