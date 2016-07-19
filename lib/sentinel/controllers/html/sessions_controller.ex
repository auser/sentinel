defmodule Sentinel.Controllers.Html.Sessions do
  use Phoenix.Controller
  alias Sentinel.Authenticator

  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.EnsureAuthenticated, %{ handler: Application.get_env(:sentinel, :auth_handler) || Sentinel.AuthHandler } when action in [:delete]
  plug Guardian.Plug.LoadResource

  def new(conn, _params) do
    changeset = Sentinel.Session.changeset(%Sentinel.Session{})

    conn
    |> put_status(:ok)
    |> render(Sentinel.SessionView, "new.html", changeset: changeset)
  end

  @doc """
  Log in as an existing user.
  Parameter are "username" and "password".
  """
  def create(conn, %{"session" => %{"username" => username, "password" => password}} = params) do
    case Authenticator.authenticate_by_username(username, password) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Successfully logged in")
        |> redirect(to: "/")
      {:error, errors} ->
        conn
        |> put_flash(:error, "Unable to perform authentication")
        |> put_status(:unauthorized)
        |> render(Sentinel.SessionView, "new.html", changeset: error_changeset(params, errors))
    end
  end

  @doc """
  Log in as an existing user.
  Parameter are "email" and "password".
  """
  def create(conn, %{"session" => %{"email" => email, "password" => password}} = params) do
    case Authenticator.authenticate_by_email(email, password) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Successfully logged in")
        |> redirect(to: "/")
      {:error, errors} ->
        conn
        |> put_flash(:error, "Unable to perform authentication")
        |> put_status(:unauthorized)
        |> render(Sentinel.SessionView, "new.html", changeset: error_changeset(params, errors))
    end
  end

  @doc """
  Destroy the active session.
  """
  def delete(conn, _params) do
    Guardian.Plug.sign_out(conn)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: Sentinel.RouterHelper.helpers.sessions_path(conn, :new))
  end

  defp error_changeset(params, errors) do
    changeset = Sentinel.Session.changeset(%Sentinel.Session{}, params["session"])
    changeset = Enum.reduce(errors, changeset,  fn ({key, value}, changeset) ->
      Ecto.Changeset.add_error(changeset, key, value)
    end)
    %{changeset | action: :create}
  end
end
