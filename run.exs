signing_salt = :crypto.strong_rand_bytes(8) |> Base.encode16()
secret_base = :crypto.strong_rand_bytes(32) |> Base.encode16()

host =
  if app = System.get_env("FLY_APP_NAME") do
    app <> ".fly.dev"
  else
    "localhost"
  end

Application.put_env(:phoenix, :json_library, Jason)

Application.put_env(:sample, SamplePhoenix.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: host],
  http: [
    ip: :any,
    port: String.to_integer(System.get_env("PORT") || "4000"),
  ],
  server: true,
  live_view: [signing_salt: signing_salt],
  secret_key_base: secret_base
)

Mix.install([
  {:bandit, "~> 1.1"},
  {:jason, "~> 1.2"},
  {:phoenix, "~> 1.7.10"},
  {:phoenix_live_view, "~> 0.20.2"}
])

defmodule SamplePhoenix.ErrorView do
  use Phoenix.Component

  def render(_, _), do: "error"
end

defmodule SamplePhoenix.SampleLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.10/priv/static/phoenix.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.20.2/priv/static/phoenix_live_view.min.js"></script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
    <%= @count %>
    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end
end

defmodule Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", SamplePhoenix do
    pipe_through :browser

    live "/", SampleLive, :index
  end
end

defmodule SamplePhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket "/live", Phoenix.LiveView.Socket
  plug Router
end


# Dry run for copying cached mix install from builder to runner
if System.get_env("EXS_DRY_RUN") == "true" do
  System.halt(0)
else
  {:ok, _} = Supervisor.start_link([SamplePhoenix.Endpoint], strategy: :one_for_one)
  Process.sleep(:infinity)
end
