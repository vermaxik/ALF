defmodule ALF.Components.TbdTest do
  use ExUnit.Case, async: true
  alias ALF.{IP, TestProducer, TestConsumer}
  alias ALF.Components.Tbd

  setup do
    {:ok, producer_pid} = TestProducer.start_link([])
    %{producer_pid: producer_pid}
  end

  def setup_stage(stage) do
    {:ok, pid} = Tbd.start_link(stage)

    {:ok, consumer_pid} =
      TestConsumer.start_link(%TestConsumer{subscribe_to: [{pid, max_demand: 1}]})

    %{pid: pid, consumer_pid: consumer_pid}
  end

  def tdb_function(event, _), do: event

  setup %{producer_pid: producer_pid} do
    stage = %Tbd{
      name: :tbd,
      module: __MODULE__,
      pipeline_module: __MODULE__,
      function: :tdb_function,
      opts: %{},
      subscribe_to: [{producer_pid, max_demand: 1}]
    }

    setup_stage(stage)
  end

  test "call component", %{producer_pid: producer_pid, consumer_pid: consumer_pid} do
    ip = %IP{event: "foo"}
    GenServer.cast(producer_pid, [ip])
    Process.sleep(10)
    [ip] = TestConsumer.ips(consumer_pid)
    assert ip.event == "foo"
    assert ip.history == [{{:tbd, 0}, "foo"}]
  end
end
