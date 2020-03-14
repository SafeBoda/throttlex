defmodule ThrottlexTest do
  use ExUnit.Case

  defmodule Throttler do
    use Throttlex, otp_app: :throttlex
  end

  import Throttlex.Utils

  alias ThrottlexTest.Throttler

  @base_ts 1_098_926_040

  setup do
    {:ok, pid} = Throttler.start_link()
    Throttler.reset()

    on_exit(fn ->
      :ok = Process.sleep(20)
      if Process.alive?(pid), do: Throttler.stop(pid, 5000)
    end)
  end

  test "incr" do
    # validate time slots
    assert [10, 60, 120] == Throttler.time_slots()

    # all buckets in 0
    assert [0, 0, 0] == Throttler.value(:x, @base_ts)

    # all buckets updated
    assert :ok == incr([x: 2], @base_ts)
    assert [2, 2, 2] == Throttler.value(:x, @base_ts)

    # bucket 1 is reset and the rest updated
    ts = @base_ts + 10
    assert [1, 3, 3] == Throttler.incr(:x, ts)
    assert [1, 3, 3] == Throttler.value(:x, ts)

    # bucket 1 and 2 are reset and the rest updated
    ts = ts + 50
    assert :ok == incr([x: 3], ts)
    assert [3, 3, 6] == Throttler.value(:x, ts)

    # all buckets are reset
    ts = ts + 60
    assert :ok == incr([x: 2], ts)
    assert [2, 2, 2] == Throttler.value(:x, ts)

    ts = ts + 10
    assert [1, 3, 3] == Throttler.incr(:x, ts)
    assert [1, 3, 3] == Throttler.value(:x, ts)

    ts = ts + 50
    assert [1, 1, 4] == Throttler.incr(:x, ts)
    assert [1, 1, 4] == Throttler.value(:x, ts)
  end

  test "garbage collector" do
    assert 3 = len = Throttler.__buckets__() |> length()

    assert :ok == incr([x: 2], @base_ts)
    assert [2, 2, 2] == Throttler.value(:x, @base_ts)

    ts = @base_ts + 10
    assert [1, 3, 3] == Throttler.incr(:x, ts)
    assert [1, 1, 1] == Throttler.incr(:y, ts)
    assert [1, 1, 1] == Throttler.incr(:z, ts)

    assert Throttler.to_list() |> List.flatten() |> length() == 10 + len

    assert [1, 1, 1] == Throttler.incr(:x, now() + 100)

    :ok = Throttler.gc_run()
    :ok = Process.sleep(1000)

    assert Throttler.to_list() |> List.flatten() |> length() == 3 + len

    [
      %{x: 3, y: 1, z: 1},
      %{x: 3, y: 1, z: 1},
      %{x: 3, y: 1, z: 1}
    ] = Throttler.stats()
  end

  ## Private Functions

  defp incr(specs, ts) do
    Enum.each(specs, fn {counter, count} ->
      Enum.each(1..count, fn _ ->
        _ = Throttler.incr(counter, ts)
      end)
    end)
  end
end
