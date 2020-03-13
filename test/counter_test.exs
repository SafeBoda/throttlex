defmodule Throttlex.CounterTest do
  use ExUnit.Case

  defmodule RateCounter do
    use Throttlex.Counter, otp_app: :nidavellir
  end

  alias Throttlex.CounterTest.RateCounter
  alias Nidavellir.Utils

  @base_ts 1_098_926_040

  setup do
    {:ok, pid} = RateCounter.start_link()
    RateCounter.reset()

    on_exit(fn ->
      :ok = Process.sleep(20)
      if Process.alive?(pid), do: RateCounter.stop(pid, 5000)
    end)
  end

  test "incr" do
    # validate buckets
    assert [10, 60, 120] == RateCounter.time_buckets()

    # all buckets in 0
    assert [0, 0, 0] == RateCounter.counter(:x, @base_ts)

    # all buckets updated
    assert :ok == incr([x: 2], @base_ts)
    assert [2, 2, 2] == RateCounter.counter(:x, @base_ts)

    # bucket 1 is reset and the rest updated
    ts = @base_ts + 10
    assert [1, 3, 3] == RateCounter.incr(:x, ts)
    assert [1, 3, 3] == RateCounter.counter(:x, ts)

    # bucket 1 and 2 are reset and the rest updated
    ts = ts + 50
    assert :ok == incr([x: 3], ts)
    assert [3, 3, 6] == RateCounter.counter(:x, ts)

    # all buckets are reset
    ts = ts + 60
    assert :ok == incr([x: 2], ts)
    assert [2, 2, 2] == RateCounter.counter(:x, ts)

    ts = ts + 10
    assert [1, 3, 3] == RateCounter.incr(:x, ts)
    assert [1, 3, 3] == RateCounter.counter(:x, ts)

    ts = ts + 50
    assert [1, 1, 4] == RateCounter.incr(:x, ts)
    assert [1, 1, 4] == RateCounter.counter(:x, ts)
  end

  test "garbage collector" do
    assert 3 = len = RateCounter.__buckets__() |> length()

    assert :ok == incr([x: 2], @base_ts)
    assert [2, 2, 2] == RateCounter.counter(:x, @base_ts)

    ts = @base_ts + 10
    assert [1, 3, 3] == RateCounter.incr(:x, ts)
    assert [1, 1, 1] == RateCounter.incr(:y, ts)
    assert [1, 1, 1] == RateCounter.incr(:z, ts)

    assert RateCounter.to_list() |> List.flatten() |> length() == 10 + len

    assert [1, 1, 1] == RateCounter.incr(:x, Utils.now() + 100)

    :ok = RateCounter.gc_run()
    :ok = Process.sleep(1000)

    assert RateCounter.to_list() |> List.flatten() |> length() == 3 + len

    [
      %{x: 3, y: 1, z: 1},
      %{x: 3, y: 1, z: 1},
      %{x: 3, y: 1, z: 1}
    ] = RateCounter.stats()
  end

  ## Private Functions

  defp incr(specs, ts) do
    Enum.each(specs, fn {counter, count} ->
      Enum.each(1..count, fn _ ->
        _ = RateCounter.incr(counter, ts)
      end)
    end)
  end
end
