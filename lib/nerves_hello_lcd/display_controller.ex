defmodule NervesHelloLcd.DisplayController do
  @moduledoc """
  ## Examples

    {:ok, pid} = DisplayController.start_link({LiquidCrystal.HD44780.I2C, %{name: "display 1"}})
    DisplayController.execute(pid, {:print, "Hello"})
    DisplayController.execute(pid, {:backlight, :off})
    DisplayController.execute(pid, {:backlight, :on})
    DisplayController.execute(pid, :clear)

  """

  use GenServer
  require Logger

  defmodule State do
    defstruct driver_module: nil, display: nil
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

  def start_link({driver_module, config} = args) when is_atom(driver_module) and is_map(config) do
    GenServer.start_link(__MODULE__, args, name: via_tuple({driver_module, config.name}))
  end

  def execute(pid, op), do: GenServer.call(pid, op)

  @impl true
  def init({driver_module, config}) do
    # Start an LCD driver and get a display map.
    with {:ok, display} <- initialize_display(driver_module, config) do
      {:ok, %State{driver_module: driver_module, display: display}}
    end
  end

  @impl true
  def handle_call(command, _from, state) do
    {_, display} = result = control_display(command, state)
    Logger.info(inspect(result))
    {:reply, result, %State{state | display: display}}
  end

  defp initialize_display(driver_module, config) do
    apply(driver_module, :start, [config])
  end

  defp control_display(command, %State{driver_module: driver_module, display: display}) do
    apply(driver_module, :execute, [display, command])
  end
end
