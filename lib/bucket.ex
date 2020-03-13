defmodule Throttlex.Bucket do
  @moduledoc """
  This module defines a gen_server that owns a named public ETS table.
  The table contains counters aggregated by time slots of in seconds).
  These counters allow counting/tracking the rate for errors, requests,
  and any other variable we are interested in.

  Periodically, the server will run the garbage collector removing entries
  older than the current time slot (calculated at the GC starts).
  """

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct [
      # Server name
      :name,

      # Starting time
      :start_time,

      # Garbage collector timer ref
      :gc_timer,

      # Garbage collector interval in seconds (Defaults to 15 min)
      gc_interval: 900,

      # Time slot size in seconds (Defaults to 1 min)
      slot_size: 60,

      # Gathered stats
      stats: %{}
    ]
  end

  use GenServer

  alias Throttlex.Bucket.State
  alias Nidavellir.Utils

  @type t :: atom
  @type counter :: atom
  @type timestamp :: integer
  @type slot_size :: pos_integer

  ## API

  @doc """
  Starts a new server for the time-bucket defined by the given options `opts`.

  ## Options

    * `:name` - An atom defining the name of the server (Required).

    * `:gc_interval` - Garbage collector interval in seconds (Defaults to
      `900` - 15 min).

    * `:slot_size` - Time slot size in seconds (Defaults to `60` - 1 min).

  ## Example

      Throttlex.Bucket.start_link(name: :my_bucket)
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || raise "expected name: to be given as argument"
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Increments the value for `counter` into the time-slot given by `timestamp`
  and `slot_size`.

  ## Example

      Throttlex.Bucket.incr(:my_bucket, :my_counter)
  """
  @spec incr(t, counter, timestamp, slot_size | nil) :: integer
  def incr(bucket, counter, timestamp \\ Utils.now(), slot_size \\ nil)

  def incr(bucket, counter, timestamp, nil) do
    incr(bucket, counter, timestamp, slot_size(bucket))
  end

  def incr(bucket, counter, timestamp, slot_size) do
    counter_k = {time_slot(slot_size, timestamp), assert_counter(counter)}
    :ets.update_counter(bucket, counter_k, 1, {counter_k, 0})
  end

  @doc """
  Returns the value for `counter` into the time-slot given by `timestamp`
  and `slot_size`.

  ## Example

      Throttlex.Bucket.counter(:my_bucket, :my_counter)
  """
  @spec counter(t, counter, timestamp, slot_size | nil) :: non_neg_integer
  def counter(bucket, counter, timestamp \\ Utils.now(), slot_size \\ nil)

  def counter(bucket, counter, timestamp, nil) do
    counter(bucket, counter, timestamp, slot_size(bucket))
  end

  def counter(bucket, counter, timestamp, slot_size) do
    case :ets.lookup(bucket, {time_slot(slot_size, timestamp), assert_counter(counter)}) do
      [{_, value}] -> value
      [] -> 0
    end
  end

  @doc """
  Returns the configured slot size.

  ## Example

      Throttlex.Bucket.slot_size(:my_bucket)
  """
  @spec slot_size(t) :: pos_integer
  def slot_size(bucket) do
    :ets.lookup_element(bucket, :"$slot_size", 2)
  end

  @doc """
  Returns the gathered stats for the given `bucket`.

  ## Example

      Throttlex.Bucket.stats(:my_bucket)
  """
  @spec stats(t) :: map
  def stats(bucket) do
    GenServer.call(bucket, :stats)
  end

  @doc """
  Resets or sets to `0` all counters for the bucket linked to the given
  `bucket`.

  ## Example

      Throttlex.Bucket.reset(:my_bucket)
  """
  @spec reset(t) :: :ok
  def reset(bucket) do
    GenServer.call(bucket, :reset)
  end

  @doc """
  Returns a list of all objects in bucket `bucket`.

  ## Example

      Throttlex.Bucket.to_list(:my_bucket)
  """
  @spec to_list(t) :: [term]
  defdelegate to_list(bucket), to: :ets, as: :tab2list

  @doc """
  Returns the time-slot given by `timestamp` and `slot_size`.

  ## Example

      Throttlex.Bucket.time_slot(10)
  """
  @spec time_slot(slot_size, timestamp) :: timestamp
  def time_slot(slot_size, timestamp \\ Utils.now()) do
    trunc(timestamp / slot_size) * slot_size
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)

    ^name =
      :ets.new(name, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    state = struct(State, :maps.from_list(opts))

    state = %{
      state
      | gc_timer: gc_reset(state.gc_interval),
        start_time: Utils.now(),
        name: name
    }

    true = :ets.insert(name, {:"$slot_size", state.slot_size})
    {:ok, state}
  end

  @impl true
  def handle_call(:stats, _from, %State{stats: stats} = state) do
    {:reply, stats, state}
  end

  def handle_call(
        :reset,
        _from,
        %State{name: name, gc_interval: interval, slot_size: slot_size} = state
      ) do
    true = :ets.delete_all_objects(name)
    true = :ets.insert(name, {:"$slot_size", slot_size})
    {:reply, :ok, %{state | gc_timer: gc_reset(interval)}}
  end

  @impl true
  def handle_info(:gc_timeout, %State{gc_interval: interval} = state) do
    state =
      interval
      |> time_slot()
      |> gc_run(state)

    {:noreply, %{state | gc_timer: gc_reset(interval)}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  ## Private Functions

  defp gc_run(current_slot, %State{name: name, stats: stats} = state) do
    true = :ets.safe_fixtable(name, true)

    stats =
      :ets.foldl(
        fn
          {{slot, counter} = key, value}, acc when slot < current_slot ->
            true = :ets.delete(name, key)
            Map.update(acc, counter, value, &(&1 + value))

          _, acc ->
            acc
        end,
        stats,
        name
      )

    true = :ets.safe_fixtable(name, false)
    %{state | stats: stats}
  end

  defp gc_reset(timeout) do
    {:ok, timer_ref} = :timer.send_after(timeout * 1000, :gc_timeout)
    timer_ref
  end

  defp assert_counter(counter) when is_atom(counter), do: counter

  defp assert_counter(counter) do
    raise ArgumentError, "expected counter to be an atom, got: #{inspect(counter)}"
  end
end
