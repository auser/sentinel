defmodule Sentinel.ChangesetHashPassword do
  @moduledoc """
  Module responsible the password hashing utilized in Sentinel, to be easily
  pulled out and used oustide Sentinel if necessary, or redefined
  """

  alias Ecto.Changeset
  alias Sentinel.Config

  @doc """
  Handles user model changeset validations for passwords, and hashes them if
  necessary
  """
  def changeset(changeset = %{params: %{"password" => password}}) when password != "" and password != nil do
    hashed_password = Config.crypto_provider.hashpwsalt(password)

    case Enum.empty?(changeset.errors) do
      true -> changeset |> Changeset.put_change(:hashed_password, hashed_password)
      false -> changeset
    end
  end
  def changeset(changeset = %{params: %{"password" => _}}) do
    if invitable? && being_created?(changeset) do
      changeset
    else
      changeset |> Changeset.add_error(:password, "can't be blank")
    end
  end
  def changeset(changeset) do
    if not invitable? && being_created?(changeset) do
      changeset |> Changeset.add_error(:password, "can't be blank")
    else
      changeset
    end
  end

  defp invitable? do
    Config.invitable
  end
  defp being_created?(changeset) do #FIXME might need to make this more robust
    changeset.data |> Map.get(:id) |> is_nil
  end
end
