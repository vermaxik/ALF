defmodule ALF.ComposersTelemetryTest do
  use ExUnit.Case
  alias ALF.Manager

  defmodule Pipeline do
    use ALF.DSL

    @components [
      decomposer(:the_decomposer),
      recomposer(:the_recomposer)
    ]

    def the_decomposer(datum, _opts) do
      {[datum + 1], datum}
    end

    def the_recomposer(datum, prev_data, _opts) do
      sum = Enum.reduce(prev_data, 0, &(&1 + &2)) + datum

      case sum >= 5 do
        true -> {sum, [hd(prev_data)]}
        false -> :continue
      end
    end
  end

  setup do
    before = Application.get_env(:alf, :telemetry_enabled)
    Application.put_env(:alf, :telemetry_enabled, true)
    on_exit(fn -> Application.put_env(:alf, :telemetry_enabled, before) end)
    {:ok, agent} = Agent.start_link(fn -> [] end)
    %{agent: agent}
  end

  describe "telemetry events" do
    defmodule Handler do
      def handle_event([:alf, :component, type], measurements, metadata, %{agent: agent}) do
        Agent.update(agent, fn list -> [{type, measurements, metadata} | list] end)
      end
    end

    setup %{agent: agent} do
      ALF.Manager.start(Pipeline)

      :ok =
        :telemetry.attach_many(
          "test-events-handler",
          [
            [:alf, :component, :start],
            [:alf, :component, :stop],
            [:alf, :component, :exception]
          ],
          &Handler.handle_event/4,
          %{agent: agent}
        )

      on_exit(fn -> :telemetry.detach("test-events-handler") end)
    end

    test "check if the pipeline works", %{agent: agent} do
      [result] =
        [2]
        |> Manager.stream_to(Pipeline)
        |> Enum.to_list()

      assert result == 5

      [
        _consumer_stop,
        _consumer_start,
        recomposer_stop2,
        recomposer_start2,
        recomposer_stop1,
        recomposer_start1,
        decomposer_stop,
        decomposer_start,
        _producer_stop,
        _producer_start
      ] = Agent.get(agent, & &1)

      check_recomposer_events1(recomposer_stop1, recomposer_start1)
      check_recomposer_events2(recomposer_stop2, recomposer_start2)
      check_decomposer_events(decomposer_stop, decomposer_start)
    end

    def check_recomposer_events1(recomposer_stop, recomposer_start) do
      assert {
               :stop,
               %{duration: _duration},
               %{
                 component: %{
                   name: :the_recomposer,
                   pipeline_module: __MODULE__.Pipeline
                 },
                 ip: nil,
                 telemetry_span_context: _ref
               }
             } = recomposer_stop

      assert {
               :start,
               %{system_time: _system_time},
               %{
                 component: %{
                   name: :the_recomposer,
                   pipeline_module: __MODULE__.Pipeline
                 },
                 ip: %{
                   datum: 3
                 },
                 telemetry_span_context: _ref
               }
             } = recomposer_start
    end

    def check_recomposer_events2(recomposer_stop, recomposer_start) do
      assert {
               :stop,
               %{duration: _duration},
               %{
                 component: %{
                   name: :the_recomposer,
                   pipeline_module: __MODULE__.Pipeline
                 },
                 ip: %{
                   datum: 5
                 },
                 telemetry_span_context: _ref
               }
             } = recomposer_stop

      assert {
               :start,
               %{system_time: _system_time},
               %{
                 component: %{
                   name: :the_recomposer,
                   pipeline_module: __MODULE__.Pipeline
                 },
                 ip: %{
                   datum: 2
                 },
                 telemetry_span_context: _ref
               }
             } = recomposer_start
    end

    def check_decomposer_events(decomposer_stop, decomposer_start) do
      assert {
               :stop,
               %{duration: _duration},
               %{
                 component: %{
                   name: :the_decomposer,
                   pipeline_module: __MODULE__.Pipeline
                 },
                 ips: [%{datum: 3}, %{datum: 2}],
                 telemetry_span_context: _ref
               }
             } = decomposer_stop

      assert {
               :start,
               %{system_time: _system_time},
               %{
                 component: %{
                   name: :the_decomposer,
                   pipeline_module: __MODULE__.Pipeline
                 },
                 ip: %{
                   datum: 2
                 },
                 telemetry_span_context: _ref
               }
             } = decomposer_start
    end
  end
end