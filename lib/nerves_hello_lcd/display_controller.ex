defmodule NervesHelloLcd.DisplayController do
  @moduledoc """
  Wraps a given display driver and controls the display using that driver.
  """

  use GenServer
  require Logger

  def child_spec(%{name: display_name} = initial_display) do
    %{
      id: {__MODULE__, display_name},
      start: {__MODULE__, :start_link, [initial_display]}
    }
  end

  # Used as a unique process name.
  def via_tuple({driver_module, _name} = key) when is_atom(driver_module) do
    NervesHelloLcd.ProcessRegistry.via_tuple({__MODULE__, key})
  end

  def whereis({driver_module, _name} = key) when is_atom(driver_module) do
    case NervesHelloLcd.ProcessRegistry.whereis_name({__MODULE__, key}) do
      :undefined -> nil
      pid -> pid
    end
  end

  @doc """
  Accepts a map that a display driver returns, starts a process, and registers
  a process with a composite key of driver module and display name.

  ## Examples
    {:ok, display} = LiquidCrystal.HD44780.I2C.start(name: "display 2")
    {:ok, pid} = DisplayController.start_link(display)
    DisplayController.execute(pid, {:print, "Hello"})
  """
  def start_link(%{driver_module: driver_module, name: display_name} = initial_display) do
    GenServer.start_link(__MODULE__, initial_display,
      name: via_tuple({driver_module, display_name})
    )
  end

  @doc """
  Accepts a map that a display driver returns, and delegates the operation to
  the display driver.

  ## Examples
    DisplayController.execute(pid, {:print, "Hello"})
  """
  def execute(pid, op), do: GenServer.call(pid, op)

  @impl true
  def init(initial_display), do: {:ok, initial_display}

  @impl true
  def handle_call(command, _from, display) do
    {_ok_or_error, new_display} = result = control_display(command, display)
    Logger.info(inspect(result))
    {:reply, result, Map.merge(display, new_display)}
  end

  defp control_display(command, %{driver_module: driver_module} = display) do
    apply(driver_module, :execute, [display, command])
  end
end
