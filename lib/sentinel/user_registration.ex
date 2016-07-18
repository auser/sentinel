defmodule Sentinel.UserRegistration do
  import Logger

  alias Sentinel.Registrator
  alias Sentinel.Confirmator
  alias Sentinel.Mailer
  alias Sentinel.Util
  alias Sentinel.UserHelper
  alias Sentinel.PasswordResetter

  @doc """
  Registration with email
  """
  def register(%{"user" => user_params = %{"email" => email}}) when email != "" and email != nil do
    {confirmation_token, changeset} =
      Registrator.changeset(user_params)
      |> Confirmator.confirmation_needed_changeset

    Logger.debug "Confirmation token is: #{confirmation_token}"

    case Util.repo.insert(changeset) do
      {:ok, user} -> confirmable_and_invitable(user, confirmation_token)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Registration with username
  """
  def register(%{"user" => user_params = %{"username" => username}}) when username != "" and username != nil do
    changeset = Registrator.changeset(user_params)

    case Util.repo.insert(changeset) do
      {:ok, user} -> confirmable_and_invitable(user, "")
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Invalid user parameters
  """
  def register(%{"user" => user}) do
    changeset = Registrator.changeset(user)
    {:error, changeset}
  end

  def confirm(params = %{"email" => email}) do
    user =
      case Util.repo.get_by(UserHelper.model, email: email) do
        nil -> Util.repo.get_by!(UserHelper.model, unconfirmed_email: email)
        user -> user
      end
    changeset = Confirmator.confirmation_changeset(user, params)

    case Util.repo.update(changeset) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def invited(%{"id" => user_id} = params) do
    user = Util.repo.get!(UserHelper.model, user_id)
    changeset = PasswordResetter.reset_changeset(user, params)
      |> Confirmator.confirmation_changeset

    case Util.repo.update(changeset) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp confirmable_and_invitable(user, confirmation_token) do
    case {is_confirmable, is_invitable} do
      {false, false} -> # not confirmable or invitable
        {:ok, user}

      {_confirmable, :true} -> # must be invited
        {password_reset_token, changeset} = PasswordResetter.create_changeset(user)
        updated_user = Util.repo.update!(changeset)
        Mailer.send_invite_email(updated_user, {confirmation_token, password_reset_token}) |> Mailer.managed_deliver
        {:ok, updated_user}

      {:required, _invitable} -> # must be confirmed
        Mailer.send_welcome_email(user, confirmation_token) |> Mailer.managed_deliver
        {:ok, user}

      {_confirmable_default, _invitable} -> # default behavior, optional confirmable, not invitable
        Mailer.send_welcome_email(user, confirmation_token) |> Mailer.managed_deliver
        {:ok, user}
    end
  end

  defp is_confirmable do
    case Application.get_env(:sentinel, :confirmable) do
      :required -> :required
      :false -> :false
      _ -> :optional
    end
  end

  defp is_invitable do
    Application.get_env(:sentinel, :invitable) || :false
  end
end
