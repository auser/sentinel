defmodule Sentinel.UserRegistration do
  alias Sentinel.Config
  alias Sentinel.Confirmator
  alias Sentinel.Mailer
  alias Sentinel.PasswordResetter
  alias Sentinel.Registrator
  alias Sentinel.UserHelper

  @moduledoc """
  Abstracted user registration logic module, enables us to use the same core
  logic in the HTML & JSON requests
  """

  @doc """
  Registration with email
  """
  def register(%{"user" => user_params = %{"email" => email}}) when email != "" and email != nil do
    {confirmation_token, changeset} =
      user_params
      |> Registrator.changeset
      |> Confirmator.confirmation_needed_changeset

    case Config.repo.insert(changeset) do
      {:ok, user} -> confirmable_and_invitable(user, confirmation_token)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Registration with username
  """
  def register(%{"user" => user_params = %{"username" => username}}) when username != "" and username != nil do
    changeset = Registrator.changeset(user_params)

    case Config.repo.insert(changeset) do
      {:ok, user} -> confirmable_and_invitable(user, "")
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Registration with invalid user parameters
  """
  def register(%{"user" => user_params}) do
    changeset = Registrator.changeset(user_params)
    {:error, changeset}
  end

  @doc """
  Abstracted confirmation from validation to db update
  """
  def confirm(params = %{"email" => email}) do
    user =
      case Config.repo.get_by(UserHelper.model, email: email) do
        nil -> Config.repo.get_by!(UserHelper.model, unconfirmed_email: email)
        user -> user
      end
    changeset = Confirmator.confirmation_changeset(user, params)

    case Config.repo.update(changeset) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Abstracted invitation logic
  """
  def invited(%{"id" => user_id} = params) do
    user = Config.repo.get!(UserHelper.model, user_id)
    changeset =
      user
      |> PasswordResetter.reset_changeset(params)
      |> Confirmator.confirmation_changeset

    case Config.repo.update(changeset) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp confirmable_and_invitable(user, confirmation_token) do
    case {confirmable?, invitable?} do
      {false, false} -> # not confirmable or invitable
        {:ok, user}

      {_confirmable, :true} -> # must be invited
        {password_reset_token, changeset} = PasswordResetter.create_changeset(user)
        updated_user = Config.repo.update!(changeset)
        updated_user
        |> Mailer.send_invite_email({confirmation_token, password_reset_token})
        |> Mailer.managed_deliver
        {:ok, updated_user}

      {:required, _invitable} -> # must be confirmed
        user
        |> Mailer.send_welcome_email(confirmation_token)
        |> Mailer.managed_deliver
        {:ok, user}

      {_confirmable_default, _invitable} -> # default behavior, optional confirmable, not invitable
        user
        |> Mailer.send_welcome_email(confirmation_token)
        |> Mailer.managed_deliver
        {:ok, user}
    end
  end

  defp confirmable? do
    case Config.confirmable do
      :required -> :required
      :false -> :false
      _ -> :optional
    end
  end

  defp invitable? do
    Config.invitable
  end
end
