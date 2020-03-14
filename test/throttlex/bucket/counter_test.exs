defmodule Throttlex.Bucket.CounterTest do
  use ExUnit.Case

  alias Throttlex.Bucket.Counter
  alias Throttlex.Utils

  @config [
    name: __MODULE__,
    gc_interval: 300,
    slot_size: 10
  ]

  @base_ts 1_098_926_040

  setup do
    {:ok, pid} = Counter.start_link(@config)
    Counter.reset(__MODULE__)

    on_exit(fn ->
      :ok = Process.sleep(20)
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5000)
    end)
  end

  test "time slots" do
    # all buckets in 0
    assert 0 == Counter.value(__MODULE__, :x, @base_ts)

    # all buckets updated
    assert :ok == incr([x: 2], @base_ts)
    assert 2 == Counter.value(__MODULE__, :x, @base_ts)

    ts = @base_ts + 5
    assert 3 == Counter.incr(__MODULE__, :x, ts)
    assert 3 == Counter.value(__MODULE__, :x, ts)

    ts = ts + 5
    assert :ok == incr([x: 3], ts)
    assert 3 == Counter.value(__MODULE__, :x, ts)

    ts = ts + 60
    assert :ok == incr([x: 2], ts)
    assert 2 == Counter.value(__MODULE__, :x, ts)

    ts = ts + 10
    assert 1 == Counter.incr(__MODULE__, :x, ts)
    assert 1 == Counter.value(__MODULE__, :x, ts)
  end

  test "garbage collector" do
    assert :ok == incr([{"x", 2}], @base_ts)
    assert 2 == Counter.value(__MODULE__, "x", @base_ts)

    ts = @base_ts + 10
    assert 1 == Counter.incr(__MODULE__, "x", ts)
    assert 1 == Counter.incr(__MODULE__, "y", ts)
    assert 1 == Counter.incr(__MODULE__, "z", ts)

    assert __MODULE__ |> Counter.to_list() |> length() == 5

    assert 1 == Counter.incr(__MODULE__, "x", Utils.now() + 100)

    _ = send(__MODULE__, :gc_timeout)
    :ok = Process.sleep(1000)

    assert __MODULE__ |> Counter.to_list() |> length() == 2

    stats = Counter.stats(__MODULE__)
    assert 3 == stats["x"]
    assert 1 == stats["y"]
    assert 1 == stats["z"]
  end

  test "invalid conuter name" do
    msg = ~r"expected counter to be an atom, got:"

    for counter <- [1, {:a, 1}] do
      assert_raise ArgumentError, msg, fn ->
        Counter.incr(__MODULE__, counter)
      end

      assert_raise ArgumentError, msg, fn ->
        Counter.value(__MODULE__, counter)
      end
    end
  end

  test "skip unhandled messages" do
    _ = send(__MODULE__, :ping)
  end

  ## Private Functions

  defp incr(specs, ts) do
    Enum.each(specs, fn {counter, count} ->
      Enum.each(1..count, fn _ ->
        _ = Counter.incr(__MODULE__, counter, ts)
      end)
    end)
  end
end
