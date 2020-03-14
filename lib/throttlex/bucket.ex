defmodule Throttlex.Bucket do
  @moduledoc false

  import Throttlex.Utils

  alias Throttlex.Bucket.Counter

  @doc """
  Implementation for `c:Throttlex.incr/3`.
  """
  def incr(buckets, counter, timestamp \\ now(), slot_size \\ nil) do
    for bucket <- buckets do
      Counter.incr(bucket, counter, timestamp, slot_size)
    end
  end

  @doc """
  Implementation for `c:Throttlex.value/3`.
  """
  def value(buckets, counter, timestamp \\ now(), slot_size \\ nil) do
    for bucket <- buckets do
      Counter.value(bucket, counter, timestamp, slot_size)
    end
  end

  @doc """
  Implementation for `c:Throttlex.stats/0`.
  """
  def stats(buckets) do
    for bucket <- buckets, do: Counter.stats(bucket)
  end

  @doc """
  Implementation for `c:Throttlex.reset/0`.
  """
  def reset(buckets) do
    for bucket <- buckets, do: Counter.reset(bucket)
    :ok
  end

  @doc """
  Implementation for `c:Throttlex.to_list/0`.
  """
  def to_list(buckets) do
    for bucket <- buckets, do: Counter.to_list(bucket)
  end

  @doc """
  Implementation for `c:Throttlex.gc_run/0`.
  """
  def gc_run(buckets) do
    for bucket <- buckets, do: send(bucket, :gc_timeout)
    :ok
  end

  @doc """
  Implementation for `c:Throttlex.time_slots/0`.
  """
  def time_slots(buckets) do
    for bucket <- buckets, do: Counter.slot_size(bucket)
  end
end
