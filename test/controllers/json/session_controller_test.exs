defmodule Json.SessionControllerTest do
  use Sentinel.ConnCase

  alias GuardianDb.Token
  alias Mix.Config
  alias Sentinel.Registrator
  alias Sentinel.Confirmator

  @email "user@example.com"
  @odd_case_email "User@example.com"
  @username "user@example.com"
  @password "secret"
  @headers [{"content-type", "application/json"}]
  @role "user"

  setup do
    conn = build_conn() |> Plug.Conn.put_req_header("content-type", "application/json")
    params = %{email: @email, password: @password}
    username_params = %{username: @username, password: @password}
    {:ok, %{conn: conn, params: params, username_params: username_params}}
  end

  test "sign in with unknown email", %{conn: conn, params: params} do
    conn = post conn, api_session_path(conn, :create), params
    response = json_response(conn, 401)
    assert response == %{"errors" => [%{"base" => "Unknown email or password"}]}
  end

  test "sign in with wrong password", %{conn: conn, params: params} do
    params
    |> Registrator.changeset
    |> TestRepo.insert!

    conn = post conn, api_session_path(conn, :create), %{ password: "wrong", email: @email }
    response = json_response(conn, 401)
    assert response == %{"errors" => [%{"base" => "Unknown email or password"}]}
  end

  test "sign in as unconfirmed user - confirmable default/optional", %{conn: conn, params: params} do
    Config.persist([sentinel: [confirmable: :optional]])

    {_, changeset} =
      params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset
    TestRepo.insert!(changeset)

    conn = post conn, api_session_path(conn, :create), params
    assert %{"token" => token} = json_response(conn, 200)
    TestRepo.get_by!(Token, jwt: token)
  end

  test "sign in as unconfirmed user - confirmable false", %{conn: conn, params: params} do
    Config.persist([sentinel: [confirmable: :false]])

    {_, changeset} =
      params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset
    TestRepo.insert!(changeset)

    conn = post conn, api_session_path(conn, :create), params
    assert %{"token" => token} = json_response(conn, 200)
    TestRepo.get_by!(Token, jwt: token)
  end

  test "sign in as unconfirmed user - confirmable required", %{conn: conn, params: params} do
    Config.persist([sentinel: [confirmable: :required]])

    {_, changeset} =
      params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset
    TestRepo.insert!(changeset)

    conn = post conn, api_session_path(conn, :create), params
    response = json_response(conn, 401)
    assert response == %{"errors" => [%{"base" => "Account not confirmed yet. Please follow the instructions we sent you by email."}]}
  end

  test "sign in as confirmed user with email", %{conn: conn, params: params} do
    params
    |> Registrator.changeset
    |> Ecto.Changeset.put_change(:confirmed_at, Ecto.DateTime.utc)
    |> TestRepo.insert!

    conn = post conn, api_session_path(conn, :create), params
    assert %{"token" => token} = json_response(conn, 200)
    TestRepo.get_by!(Token, jwt: token)
  end

  test "sign in as confirmed user with email - case insensitive", %{conn: conn, params: params} do
    params
    |> Registrator.changeset
    |> Ecto.Changeset.put_change(:confirmed_at, Ecto.DateTime.utc)
    |> TestRepo.insert!

    conn = post conn, api_session_path(conn, :create), %{
      email: String.upcase(params.email),
      password: params.password
    }
    assert %{"token" => token} = json_response(conn, 200)
    TestRepo.get_by!(Token, jwt: token)
  end

  test "sign in with unknown username", %{conn: conn, username_params: username_params} do
    conn = post conn, api_session_path(conn, :create), username_params
    response = json_response(conn, 401)
    assert response == %{"errors" => [%{"base" => "Unknown email or password"}]}
  end

  test "sign in with username and wrong password", %{conn: conn, username_params: username_params} do
    username_params
    |> Registrator.changeset
    |> TestRepo.insert!

    conn = post conn, api_session_path(conn, :create), %{
      username: username_params.username,
      password: "wrong"
    }
    response = json_response(conn, 401)
    assert response == %{"errors" => [%{"base" => "Unknown email or password"}]}
  end

  test "sign in user with username", %{conn: conn, username_params: username_params} do
    username_params
    |> Registrator.changeset
    |> TestRepo.insert!

    conn = post conn, api_session_path(conn, :create), username_params
    %{"token" => token} = json_response(conn, 200)
    TestRepo.get_by!(Token, jwt: token)
  end

  test "sign out", %{conn: conn} do
    user = Factory.insert(:user, confirmed_at: Ecto.DateTime.utc)
    permissions = Sentinel.User.permissions(user.role)
    {:ok, token, _} = Guardian.encode_and_sign(user, :token, permissions)

    token_count = length(TestRepo.all(Token))
    conn = conn |> Plug.Conn.put_req_header("authorization", token)
    conn = delete conn, api_session_path(conn, :delete)

    assert json_response(conn, 200)
    assert (token_count - 1) == length(TestRepo.all(Token))
  end
end
