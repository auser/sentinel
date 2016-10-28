defmodule Mix.Tasks.Sentinel.Install do
  use Mix.Task

  @shortdoc "Used to initially setup and configure sentinel"

  def run(_) do
    IO.puts "Creating migrations"
    create_migrations

    IO.puts "Appending config"
    generate_config

    IO.puts "You should go in and ensure your application is configured correctly"
  end

  defp create_migrations do
    #FIXME ueberauth passports, do we save them in this paradigm?
    if File.exists?("priv/repo/migrations") do
      migrations = Path.wildcard("priv/repo/migrations/*.exs")

      migrations
      |> Enum.find(fn(migration) ->
        String.contains?(migration, "create_user")
      end) |> create_user_migration

      migrations
      |> Enum.find(fn(migration) ->
        String.contains?(migration, "guardian")
      end) |> create_guardian_token_migration
    else
      create_user_migration
      create_guardian_token_migration
    end
  end

  defp create_user_migration do
    generate_user_migration
  end
  defp create_user_migration(nil) do
    generate_user_migration
  end
  defp create_user_migration(_) do
    IO.puts "A user creation migration appears to already exist"
  end

  defp generate_user_migration do
    Mix.Tasks.Phoenix.Gen.Model.run([
      "User",
      "users",
      "email:string",
      "username:string",
      "hashed_password:text",
      "hashed_confirmation_token:text",
      "hashed_password_reset_token:text",
      "confirmed_at:datetime",
      "unconfirmed_email:string"
    ])
  end

  defp create_guardian_token_migration do
    generate_token_migration
  end
  defp create_guardian_token_migration(nil) do
    generate_token_migration
  end
  defp create_guardian_token_migration(_migration) do
    IO.puts "A guardian token migration appears to already exist"
  end

  defp generate_token_migration do
    Mix.Tasks.Ecto.Gen.Migration.run(["AddGuardianDbTokens"])
    migration_path =
      Path.wildcard("priv/repo/migrations/*.exs")
      |> Enum.find(fn(migration) ->
        String.contains?(migration, "guardian")
      end)

    migration_content =
      migration_path
      |> File.stream!
      |> Enum.map(fn(line) -> line end)
      |> Enum.slice(0..2)

    new_content =
      "deps/sentinel/test/support/migrations/guardian_db_migration.exs"
      |> File.stream!
      |> Enum.map(fn(line) -> line end)
      |> Enum.slice(3..100)

    migration_content ++ new_content
    |> File.write(migration_path)
  end

  defp generate_config do
    "deps/sentinel/config/test.exs"
    |> File.stream!
    |> Enum.map(fn(line) -> line end)
    |> Enum.slice(15..100)
    |> append_config
  end

  defp append_config(config) do
    {:ok, file} = File.open("config/config.exs", [:append])
    save_config(file, config)
    File.close(file)
  end

  defp save_config(file, []), do: :ok
  defp save_config(file, [data|rest]) do
    IO.binwrite(file, data)
    save_config(file, rest)
  end
end
