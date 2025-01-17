defmodule TelemetryUI.Test.ErrorView do
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule TelemetryUI.Test.Router do
  use Phoenix.Router

  defmodule Select do
    import Plug.Conn

    def init(_), do: []

    def call(conn, _) do
      conn
      |> put_resp_header("content-type", "text/plain")
      |> send_resp(:ok, inspect(TelemetryUI.Test.Repo.query!("SELECT 1")))
    end
  end

  scope "/" do
    get("/", TelemetryUI.Test.Router.Select, [])

    get("/empty-metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :empty_metrics, telemetry_ui_allowed: true})
    get("/custom-render-metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :custom_render_metrics, telemetry_ui_allowed: true})
    get("/data-metrics", TelemetryUI.Web, :index, assigns: %{telemetry_ui_name: :data_metrics, telemetry_ui_allowed: true})
  end
end

defmodule TelemetryUI.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :telemetry_ui

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug TelemetryUI.Test.Router
end

Application.ensure_all_started(:os_mon)

ExUnit.start()

defmodule TestCustomRenderMetric do
  use TelemetryUI.Metrics

  def new(attrs), do: struct!(__MODULE__, attrs)

  defimpl TelemetryUI.Web.Component do
    def render(_metric, _assigns) do
      "Custom metric in render function"
    end
  end
end

custom_render_metric =
  TestCustomRenderMetric.new(%{
    id: "custom",
    title: "Custom",
    telemetry_metric: nil,
    data: nil,
    data_resolver: fn -> {:ok, []} end
  })

data_metric =
  TelemetryUI.Metrics.count_over_time(:data,
    description: "Users count",
    unit: " users",
    data_resolver: fn ->
      {:ok, [%{date: DateTime.utc_now(), value: 1.2, count: 1}]}
    end
  )

Supervisor.start_link(
  [
    TelemetryUI.Test.Endpoint,
    TelemetryUI.Test.Repo,
    {TelemetryUI, [name: :empty_metrics, metrics: [], theme: [title: "My test metrics"]]},
    {TelemetryUI, [name: :custom_render_metrics, metrics: [custom_render_metric], theme: [title: "My custom render metrics"]]},
    {TelemetryUI, [name: :data_metrics, metrics: [data_metric], theme: [title: "My data metrics"]]}
  ],
  strategy: :one_for_one
)

Ecto.Adapters.SQL.Sandbox.mode(TelemetryUI.Test.Repo, :manual)
