defmodule Throttlex.Counter do
  @moduledoc """
  This module is a wrapper for `Throttlex.Counter.Bucket` enabling
  multiple time buckets at the same time. This is useful for having multiple
  rate trackers and/or limiters.

  When used, the defined throttle counter module expects the `:otp_app` as
  option. The `:otp_app` should point to an OTP application. For example,
  tthe rate counter:

      defmodule MyApp.RateCounter do
        use Throttlex.Counter, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.RateCounter,
        buckets: [
          bucket0: [gc_interval: 180, slot_size: 60],  #=> 1 min
          bucket1: [gc_interval: 900, slot_size: 300], #=> 5 min
          bucket2: [gc_interval: 1800, slot_size: 600] #=> 10 min
        ]

  The final piece of configuration is to setup `MyApp.RateCounter` as a
  supervisor within the application’s supervision tree, which we can do in
  `lib/my_app/application.ex` inside the `start/2` function:

      def start(_type, _args) do
        children = [
          MyApp.RateCounter
        ]

        ...

  ## Options

  See `c:start_link/1`.
  """

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Throttlex.Counter

      alias Throttlex.Counter.Bucket
      alias Throttlex.Utils

      {otp_app, buckets} = Throttlex.Counter.Supervisor.compile_config(__MODULE__, opts)

      @otp_app otp_app
      @buckets buckets

      ## API

      @doc false
      def __buckets__, do: @buckets

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {
            Throttlex.Counter.Supervisor,
            :start_link,
            [__MODULE__, @otp_app, opts]
          },
          type: :supervisor
        }
      end

      @doc false
      def start_link(opts \\ []) do
        Throttlex.Counter.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      @doc false
      def stop(sup, timeout \\ 5000) do
        Supervisor.stop(sup, :normal, timeout)
      end

      @doc false
      def incr(counter, timestamp \\ Utils.now(), slot_size \\ nil) do
        for bucket <- @buckets do
          Bucket.incr(bucket, counter, timestamp, slot_size)
        end
      end

      @doc false
      def counter(counter, timestamp \\ Utils.now(), slot_size \\ nil) do
        for bucket <- @buckets do
          Bucket.counter(bucket, counter, timestamp, slot_size)
        end
      end

      @doc false
      def stats do
        for bucket <- @buckets, do: Bucket.stats(bucket)
      end

      @doc false
      def reset do
        for bucket <- @buckets, do: Bucket.reset(bucket)
        :ok
      end

      @doc false
      def to_list do
        for bucket <- @buckets, do: Bucket.to_list(bucket)
      end

      @doc false
      def gc_run do
        for bucket <- @buckets, do: send(bucket, :gc_timeout)
        :ok
      end

      @doc false
      def time_buckets do
        for bucket <- @buckets, do: Bucket.slot_size(bucket)
      end
    end
  end

  @doc """
  Starts a new throttle counter with the configured buckets.

  ## Options

    * `:buckets`: A list of buckets with their options; list of `Keyword.t()`
      where the key is a name identifying the bucket and the value the options
      for that bucket. For example: `buckets: [b1: opts, ...]`.
      Defaults to `[]`.

  See `Throttlex.Counter.Bucket.start_link/1` for bucket options.
  """
  @callback start_link(opts :: Keyword.t()) :: GenServer.on_start()

  @doc """
  Shuts down the throttle counter represented by the given pid.
  """
  @callback stop(pid, timeout) :: :ok

  @doc """
  Increments the value for `counter` into the time-slot given by `timestamp`
  and `slot_size`.

  Returns a list with the current count for each bucket.

  ## Example

      RateCounter.incr(:errors)
  """
  @callback incr(
              counter :: atom,
              timestamp :: integer,
              time_slot :: pos_integer | nil
            ) :: [integer]

  @doc """
  Returns the value for `counter` into the time-slot given by `timestamp`
  and `slot_size`.

  Returns a list with the current count for each bucket.

  ## Example

      RateCounter.counter(:errors)
  """
  @callback counter(
              counter :: atom,
              timestamp :: integer,
              time_slot :: pos_integer | nil
            ) :: [integer]

  @doc """
  Returns the gathered stats for the given server `name`.

  Returns a list with the stats for each bucket.

  ## Example

      RateCounter.stats()
  """
  @callback stats :: [map]

  @doc """
  Resets or sets to `0` all counters for the bucket linked to the given
  server `name`.

  ## Example

      RateCounter.reset()
  """
  @callback reset :: :ok

  @doc """
  Returns a list of all counters for each bucket.

  ## Example

      RateCounter.to_list()
  """
  @callback to_list :: [term]

  @doc """
  Forces the garbage collector to run.

  ## Example

      RateCounter.gc_run()
  """
  @callback gc_run :: :ok

  @doc """
  Returns a list with the slot size for each bucket.

  ## Example

      RateCounter.time_buckets()
  """
  @callback time_buckets :: [pos_integer]
end
