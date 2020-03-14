defmodule Throttlex do
  @moduledoc """
  Throttler Main Interface.

  It is possible to set up multiple time buckets at the same time. This is
  useful when you want to have a non-linear behavior. For example, having
  a single bucket, let's say per minute and with limit `10`, the throttling
  logic is applied only when that limit is reached every minute. But we can
  have a bucket per minute, another one for 5 minutes and so on. If any of
  the time-bucket limits are reached, then the throttling logic is applied.

  When used, the defined throttle counter module expects the `:otp_app` as
  option. The `:otp_app` should point to an OTP application. For example,
  the throttler:

      defmodule MyApp.Throttler do
        use Throttlex, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.Throttler,
        buckets: [
          bucket0: [gc_interval: 180, slot_size: 60],  #=> 1 min
          bucket1: [gc_interval: 900, slot_size: 300], #=> 5 min
          bucket2: [gc_interval: 1800, slot_size: 600] #=> 10 min
        ]

  The final piece of configuration is to setup `MyApp.Throttler` as a
  supervisor within the application’s supervision tree, which we can do in
  `lib/my_app/application.ex` inside the `start/2` function:

      def start(_type, _args) do
        children = [
          MyApp.Throttler
        ]

        ...

  ## Options

  See `c:start_link/1`.
  """

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Throttlex

      import Throttlex.Utils

      alias Throttlex.Bucket

      {otp_app, buckets} = Throttlex.Supervisor.compile_config(__MODULE__, opts)

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
            Throttlex.Supervisor,
            :start_link,
            [__MODULE__, @otp_app, opts]
          },
          type: :supervisor
        }
      end

      @doc false
      def start_link(opts \\ []) do
        Throttlex.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      @doc false
      def stop(sup, timeout \\ 5000) do
        Supervisor.stop(sup, :normal, timeout)
      end

      @doc false
      def incr(counter, timestamp \\ now(), slot_size \\ nil) do
        Bucket.incr(@buckets, counter, timestamp, slot_size)
      end

      @doc false
      def value(counter, timestamp \\ now(), slot_size \\ nil) do
        Bucket.value(@buckets, counter, timestamp, slot_size)
      end

      @doc false
      def stats do
        Bucket.stats(@buckets)
      end

      @doc false
      def reset do
        Bucket.reset(@buckets)
      end

      @doc false
      def to_list do
        Bucket.to_list(@buckets)
      end

      @doc false
      def gc_run do
        Bucket.gc_run(@buckets)
      end

      @doc false
      def time_slots do
        Bucket.time_slots(@buckets)
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

  See `Throttlex.Bucket.Counter.start_link/1` for bucket options.
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

      Throttler.incr(:errors)
  """
  @callback incr(
              counter :: Throttlex.Bucket.Counter.counter(),
              timestamp :: integer,
              time_slot :: pos_integer | nil
            ) :: [integer]

  @doc """
  Returns the value for `counter` into the time-slot given by `timestamp`
  and `slot_size`.

  Returns a list with the current count for each bucket.

  ## Example

      Throttler.counter(:errors)
  """
  @callback value(
              counter :: Throttlex.Bucket.Counter.counter(),
              timestamp :: integer,
              time_slot :: pos_integer | nil
            ) :: [integer]

  @doc """
  Returns the gathered stats for the given server `name`.

  Returns a list with the stats for each bucket.

  ## Example

      Throttler.stats()
  """
  @callback stats :: [map]

  @doc """
  Resets or sets to `0` all counters for the bucket linked to the given
  server `name`.

  ## Example

      Throttler.reset()
  """
  @callback reset :: :ok

  @doc """
  Returns a list of all counters for each bucket.

  ## Example

      Throttler.to_list()
  """
  @callback to_list :: [term]

  @doc """
  Forces the garbage collector to run.

  ## Example

      Throttler.gc_run()
  """
  @callback gc_run :: :ok

  @doc """
  Returns a list with the slot size for each bucket.

  ## Example

      Throttler.time_slots()
  """
  @callback time_slots :: [pos_integer]
end
