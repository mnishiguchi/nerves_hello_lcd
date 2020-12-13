defmodule NervesHelloLcd.DisplaySupervisor do
  @moduledoc """
  Supervises display controller processes.
  """

  # https://hexdocs.pm/elixir/DynamicSupervisor.html
  use DynamicSupervisor

  alias NervesHelloLcd.DisplayController

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Finds or create a DisplayController process.

  ## Examples
    pid = DisplaySupervisor.display_controller(
      LiquidCrystal.HD44780.I2C,
      name: "display 1"
    )
  """
  def display_controller(driver_module, config) when is_atom(driver_module) and is_list(config) do
    display_name = Keyword.fetch!(config, :name)

    case DisplayController.whereis({driver_module, display_name}) do
      nil -> start_child(driver_module, config)
      pid -> pid
    end
  end

  defp start_child(driver_module, config) do
    display = initialize_display(driver_module, config)

    case DynamicSupervisor.start_child(__MODULE__, DisplayController.child_spec(display)) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp initialize_display(driver_module, config) do
    {:ok, display} = apply(driver_module, :start, [config])
    display
  end
end
