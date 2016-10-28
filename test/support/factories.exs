defmodule Sentinel.Factory do
  use ExMachina.Ecto, repo: Sentinel.TestRepo

  alias Sentinel.Config

  def user_factory do
    %Sentinel.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      username: sequence(:username, &"user#{&1}@example.com"),
      hashed_password: Config.crypto_provider.hashpwsalt("password"),
      role: "user",
      confirmed_at: nil
    }
  end
end
