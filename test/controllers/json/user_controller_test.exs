defmodule Json.UserControllerTest do
  use Sentinel.ConnCase

  alias Mix.Config
  alias Sentinel.AccountUpdater
  alias Sentinel.Confirmator
  alias Sentinel.PasswordResetter
  alias Sentinel.Registrator

  @email "user@example.com"
  @password "secret"
  @headers [{"content-type", "application/json"}, {"language", "en"}]

  setup do
    on_exit fn ->
      Application.delete_env :sentinel, :user_model_validator
    end

    conn = build_conn |> Conn.put_req_header("content-type", "application/json")
    params = %{user: %{email: @email, password: @password}}
    invite_params = %{user: %{email: @email}}

    mocked_token = SecureRandom.urlsafe_base64()
    mocked_confirmation_token = SecureRandom.urlsafe_base64()
    mocked_password_reset_token = SecureRandom.urlsafe_base64()

    welcome_email = Sentinel.Mailer.send_welcome_email(
      %Sentinel.User{
        unconfirmed_email: params.user.email,
        email: params.user.email,
        id: 1
      }, mocked_token)
    invite_email = Sentinel.Mailer.send_invite_email(
      %Sentinel.User{
        email: params.user.email,
        id: 1
      }, {mocked_confirmation_token, mocked_password_reset_token})

    {
      :ok,
      %{
        conn: conn,
        params: params,
        invite_params: invite_params,
        mocked_token: mocked_token,
        welcome_email: welcome_email,
        invite_email: invite_email
      }
    }
  end

  test "default sign up", %{conn: conn, params: params, welcome_email: mocked_mail} do
    Config.persist([sentinel: [confirmable: :optional]])
    Config.persist([sentinel: [invitable: false]])

    with_mock Sentinel.Mailer, [:passthrough], [send_welcome_email: fn(_, _) -> mocked_mail end] do
      conn = post conn, api_user_path(conn, :create), params
      response = json_response(conn, 201)

      %{"email" => email} = response
      assert email == params.user.email

      user = TestRepo.get_by!(User, email: params.user.email)
      refute is_nil(user.hashed_confirmation_token)
      assert_delivered_email mocked_mail
    end
  end

  test "confirmable :required sign up", %{conn: conn, params: params, welcome_email: mocked_mail} do
    Config.persist([sentinel: [confirmable: :required]])
    Config.persist([sentinel: [invitable: false]])


    with_mock Sentinel.Mailer, [:passthrough], [send_welcome_email: fn(_, _) -> mocked_mail end] do
      conn = post conn, api_user_path(conn, :create), params
      response = json_response(conn, 201)

      %{"email" => email} = response
      assert email == params.user.email

      user = TestRepo.get_by!(User, email: params.user.email)
      refute is_nil(user.hashed_confirmation_token)
      assert_delivered_email mocked_mail
    end
  end

  test "confirmable :false sign up", %{conn: conn, params: params} do
    Config.persist([sentinel: [confirmable: false]])
    Config.persist([sentinel: [invitable: false]])

    conn = post conn, api_user_path(conn, :create), params
    response = json_response(conn, 201)

    %{"email" => email} = response
    assert email == params.user.email

    user = TestRepo.get_by!(User, email: params.user.email)
    refute is_nil(user.hashed_confirmation_token)
    refute_delivered_email Sentinel.Mailer.NewEmailAddress.build(user, "token")
  end

  test "invitable sign up", %{conn: conn, params: params, invite_email: mocked_mail} do
    Config.persist([sentinel: [invitable: true]])
    Config.persist([sentinel: [confirmable: false]])

    with_mock Sentinel.Mailer, [:passthrough], [send_invite_email: fn(_, _) -> mocked_mail end] do
      conn = post conn, api_user_path(conn, :create), params
      response = json_response(conn, 201)

      %{"email" => email} = response
      assert email == params.user.email
      assert_delivered_email mocked_mail
    end
  end

  test "invitable and confirmable sign up", %{conn: conn, invite_params: params, invite_email: mocked_mail} do
    Config.persist([sentinel: [confirmable: :optional]])
    Config.persist([sentinel: [invitable: true]])

    with_mock Sentinel.Mailer, [:passthrough], [send_invite_email: fn(_, _) -> mocked_mail end] do
      conn = post conn, api_user_path(conn, :create), params
      response = json_response(conn, 201)

      %{"email" => email} = response
      assert email == params.user.email
      assert_delivered_email mocked_mail
    end
  end

  test "invitable setup password", %{conn: conn, params: params} do
    Config.persist([sentinel: [confirmable: :optional]])
    Config.persist([sentinel: [invitable: true]])

    {confirmation_token, changeset} =
      %{email: params.user.email}
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset
    user = TestRepo.insert!(changeset)

    {password_reset_token, changeset} = PasswordResetter.create_changeset(user)
    user = TestRepo.update!(changeset)

    conn = post conn, api_user_path(conn, :invited, user.id), %{confirmation_token: confirmation_token, password_reset_token: password_reset_token, password: params.user.password}
    response = json_response(conn, 200)
    %{"email" => email} = response
    assert email == params.user.email

    updated_user = TestRepo.get! User, user.id

    assert updated_user.hashed_confirmation_token == nil
    assert updated_user.hashed_password_reset_token == nil
    assert updated_user.unconfirmed_email == nil
  end

  test "sign up with missing password without the invitable module enabled", %{conn: conn, invite_params: params}  do
    Config.persist([sentinel: [invitable: false]])

    conn = post conn, api_user_path(conn, :create), params
    response = json_response(conn, 422)
    assert response == %{"errors" => [%{"password" => "can't be blank"}]}
  end

  test "sign up with missing email", %{conn: conn} do
    conn = post conn, api_user_path(conn, :create), %{"user" => %{"password" => @password}}
    response = json_response(conn, 422)
    assert response == %{"errors" =>
      [
        %{"email" => "can't be blank"},
        %{"username" => "Username or email address required"}
      ]
    }
  end

  test "sign up with custom validations", %{conn: conn, params: params} do
    Config.persist([sentinel: [confirmable: :optional]])
    Config.persist([sentinel: [invitable: false]])

    Application.put_env(:sentinel, :user_model_validator, fn changeset ->
      Ecto.Changeset.add_error(changeset, :password, "too short")
    end)

    conn = post conn, api_user_path(conn, :create), params
    response = json_response(conn, 422)
    assert response == %{"errors" => [%{"password" => "too short"}]}
  end

  test "confirm user with a bad token", %{conn: conn, params: %{user: params}} do
    {_, changeset} =
      params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset
    TestRepo.insert!(changeset)

    conn = post conn, api_user_path(conn, :confirm), %{email: params.email, confirmation_token: "bad_token"}
    response = json_response(conn, 422)
    assert response == %{"errors" => [%{"confirmation_token" => "invalid"}]}
  end

  test "confirm a user", %{conn: conn, params: %{user: params}} do
    {token, changeset} =
      params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset
    user = TestRepo.insert!(changeset)

    conn = post conn, api_user_path(conn, :confirm), %{email: params.email, confirmation_token: token}
    assert json_response(conn, 200)

    updated_user = TestRepo.get! User, user.id
    assert updated_user.hashed_confirmation_token == nil
    assert updated_user.confirmed_at != nil
  end

  test "confirm a user's new email", %{conn: conn, params: %{user: params}} do
    {token, registrator_changeset} =
      params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset

    user =
      registrator_changeset
      |> TestRepo.insert!
      |> Confirmator.confirmation_changeset(%{"confirmation_token" => token})
      |> TestRepo.update!

    {token, updater_changeset} = AccountUpdater.changeset(user, %{"email" => "new@example.com"})
    TestRepo.update!(updater_changeset)

    conn = post conn, api_user_path(conn, :confirm), %{email: user.email, confirmation_token: token}
    assert json_response(conn, 200)

    updated_user = TestRepo.get! User, user.id
    assert updated_user.hashed_confirmation_token == nil
    assert updated_user.unconfirmed_email == nil
    assert updated_user.email == "new@example.com"
  end
end
