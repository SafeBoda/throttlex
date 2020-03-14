defmodule Throttlex.Utils do
  @moduledoc """
  General purpose utility functions.
  """

  ## API

  @doc """
  Returns the currrent Unix time.

  ## Example

      Throttlex.Utils.now()
  """
  @spec now(System.time_unit()) :: integer()
  def now(unit \\ :second) do
    DateTime.to_unix(DateTime.utc_now(), unit)
  end
end
