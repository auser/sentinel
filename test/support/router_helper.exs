defmodule RouterHelper do
  use Plug.Test

  @default_opts [
    store: :cookie,
    key: "_sentinel_test_key",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt"
  ]
  @secret String.duplicate("secret", 12)

  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))
  def call(router, verb, path, params \\ nil, headers \\ []) do
    conn = Plug.Test.conn(verb, path, params)
    conn = Enum.reduce(headers, conn, fn ({name, value}, conn) ->
        put_req_header(conn, name, value)
      end) |> Plug.Conn.fetch_query_params(conn)

    keyed_conn =
      conn.secret_key_base
      |> put_in(@secret)
      |> Plug.Session.call(@signing_opts)
      |> Plug.Conn.fetch_session

    router.call(keyed_conn, router.init([]))
  end
end

defmodule HtmlRequestHelper do
  use Phoenix.ConnTest

  @default_opts [
    store: :cookie,
    key: "_sentinel_test_key",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt"
  ]
  @secret String.duplicate("secret", 12)

  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))

  def call_with_session(user, router, verb, path, params \\ nil) do
    conn =
      Plug.Test.conn(verb, path, params)
      |> Plug.Conn.fetch_query_params

    session_conn =
      conn.secret_key_base
      |> put_in(@secret)
      |> Plug.Session.call(@signing_opts)
      |> Plug.Conn.fetch_session
      |> Guardian.Plug.sign_in(user)

    router.call(session_conn, router.init([]))
  end
end
