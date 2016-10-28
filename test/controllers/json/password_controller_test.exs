defmodule Json.PasswordControllerTest do
  use Sentinel.ConnCase

  alias Ecto.Changeset
  alias Ecto.DateTime
  alias GuardianDb.Token
  alias Sentinel.Registrator
  alias Sentinel.PasswordResetter

  @email "user@example.com"
  @headers [{"content-type", "application/json"}]

  setup do
    conn = build_conn |> Conn.put_req_header("content-type", "application/json")
    {:ok, %{conn: conn}}
  end

  test "request a reset token for an unknown email", %{conn: conn} do
    conn = get conn, api_password_path(conn, :new), %{email: @email}
    response = json_response(conn, 200)
    assert response == "ok"
    refute_delivered_email Sentinel.Mailer.PasswordReset.build(%User{email: @email}, "token")
  end

  test "request a reset token", %{conn: conn} do
    user =
      %{"email" => @email, "password" => "oldpassword"}
      |> Registrator.changeset
      |> Changeset.put_change(:confirmed_at, DateTime.utc)
      |> TestRepo.insert!

    mocked_reset_token = "mocked_reset_token"
    mocked_mail = Mailer.send_password_reset_email(user, mocked_reset_token)

    with_mock Sentinel.Mailer, [:passthrough], [send_password_reset_email: fn(_, _) -> mocked_mail end] do
      conn = get conn, api_password_path(conn, :new), %{email: @email}
      response = json_response(conn, 200)
      assert response == "ok"

      updated_user = TestRepo.get!(User, user.id)
      assert updated_user.hashed_password_reset_token != nil
      assert_delivered_email mocked_mail
    end
  end

  test "reset password with a wrong token", %{conn: conn} do
    {_reset_token, changeset} =
      %{email: @email, password: "oldpassword"}
      |> Registrator.changeset
      |> PasswordResetter.create_changeset
    user = TestRepo.insert!(changeset)

    params = %{user_id: user.id, password_reset_token: "wrong_token", password: "newpassword"}
    conn = put conn, api_password_path(conn, :update), params
    response = json_response(conn, 422)

    assert response == %{"errors" => [%{"password_reset_token" => "invalid"}]}
  end

  test "reset password", %{conn: conn} do
    {reset_token, changeset} =
      %{email: @email, password: "oldpassword"}
      |> Registrator.changeset
      |> PasswordResetter.create_changeset
    user = TestRepo.insert!(changeset)

    params = %{user_id: user.id, password_reset_token: reset_token, password: "newpassword"}
    conn = put conn, api_password_path(conn, :update), params
    assert %{"token" => session_token} = json_response(conn, 200)
    assert TestRepo.get_by!(Token, jwt: session_token)
  end
end
