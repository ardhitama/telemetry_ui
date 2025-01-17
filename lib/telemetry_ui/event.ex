defmodule TelemetryUI.Event do
  @moduledoc false

  @enforce_keys ~w(value time event_name tags report_as)a
  defstruct value: 0, time: nil, event_name: nil, tags: %{}, report_as: nil

  def cast_event_name(metric) do
    Enum.join(metric.name, ".")
  end

  def cast_report_as(metric) do
    Keyword.get(metric.reporter_options, :report_as) || ""
  end
end
