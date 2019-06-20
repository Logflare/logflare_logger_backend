defmodule LogflareLogger.LogParamsTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{LogParams}
  require Logger
  use Placebo

  describe "LogParams" do
    test "converts tuples to lists" do
      assert LogEvent.encode()
    end
  end

end
