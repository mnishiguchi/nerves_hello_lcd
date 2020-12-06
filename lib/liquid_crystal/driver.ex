defmodule LiquidCrystal.Driver do
  @moduledoc """
  Defines a behaviour required for an LCD driver.

  ## Examples

      defmodule MyDisplayDriver do
        @behaviour LiquidCrystal.Driver
      end

  """

  use LiquidCrystal.Types

  @callback start(list) :: {:ok | :error, display}

  @callback stop(display) :: :ok

  @callback execute(display, command()) :: {:ok | :error, display}
end
