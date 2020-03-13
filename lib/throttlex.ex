defmodule Throttlex.Counter.Supervisor do
  @moduledoc false

  use Supervisor

  alias Throttlex.Bucket

  @doc """
  Starts the Throttlex.Counter supervisor.
  """
  @spec start_link(module, atom, Keyword.t()) :: Supervisor.on_start()
  def start_link(name, otp_app, opts) do
    Supervisor.start_link(__MODULE__, {name, otp_app, opts}, name: name)
  end

  @doc """
  Retrieves the compile time configuration.
  """
  def compile_config(name, opts) do
    otp_app = opts[:otp_app] || raise("expected otp_app: to be given as argument")

    len =
      otp_app
      |> config(name, opts)
      |> Keyword.get(:buckets, [])
      |> length()

    buckets = for index <- 0..(len - 1), do: :"#{name}.#{index}"

    {otp_app, buckets}
  end

  ## Supervisor Callbacks

  @impl true
  def init({name, otp_app, opts}) do
    otp_app
    |> config(name, opts)
    |> Keyword.get(:buckets, [])
    |> Enum.reduce({[], 0}, fn {_, bucket_opts}, {acc, index} ->
      spec =
        Supervisor.child_spec(
          {Bucket, [name: :"#{name}.#{index}"] ++ bucket_opts},
          id: {name, index}
        )

      {[spec | acc], index + 1}
    end)
    |> elem(0)
    |> Supervisor.init(strategy: :one_for_one)
  end

  ## Private Functions

  defp config(otp_app, name, opts) do
    otp_app
    |> Application.get_env(name, [])
    |> Keyword.merge(opts)
  end
end
