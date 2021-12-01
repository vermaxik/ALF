defmodule ALF.Examples.PlugWith.HelloComponent do
  def call(%{name: name}, _) do
    "Hello #{name}!"
  end
end

defmodule ALF.Examples.PlugWith.Pipeline do
  use ALF.DSL

  alias ALF.Examples.PlugWith.HelloComponent

  defstruct [:input, :output]

  defmodule InputToName do
    alias ALF.Examples.PlugWith.Pipeline
    def plug(%Pipeline{input: input}, _), do: %{name: input}
    def unplug(string, prev_event, _), do: %{prev_event | output: string}
  end

  @components [
    stage(:build_struct),
    plug_with(InputToName, do: [stage(HelloComponent)]),
    stage(:format_output)
  ]

  def build_struct(event, _), do: %__MODULE__{input: event}
  def format_output(%__MODULE__{output: event}, _), do: event
end

defmodule ALF.Examples.PlugWithExamplesTest do
  use ExUnit.Case

  alias ALF.Examples.PlugWith.Pipeline
  alias ALF.Manager

  setup do: Manager.start(Pipeline)

  test "process input" do
    inputs = ["Anton", "Baton"]

    results =
      inputs
      |> Manager.stream_to(Pipeline)
      |> Enum.to_list()

    assert results == ["Hello Anton!", "Hello Baton!"]
  end
end
