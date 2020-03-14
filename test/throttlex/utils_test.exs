defmodule Throttlex.UtilsTest do
  use ExUnit.Case
  doctest Throttlex.Utils

  import Throttlex.Utils

  test "now" do
    assert is_integer(now())
  end
end
