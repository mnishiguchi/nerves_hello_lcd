defmodule NervesHelloLcd.DisplaySupervisor do
  alias NervesHelloLcd.DisplayController

  @moduledoc """
  ## Examples

      # GPIO
      pid = DisplaySupervisor.controller_process({
        LiquidCrystal.HD44780.GPIO,
        %{name: "display 1", rs: 1, en: 2, d4: 3, d5: 4, d6: 5, d7: 6, rows: 2, cols: 20}
      })

      # I2C
      pid = DisplaySupervisor.controller_process({
        LiquidCrystal.HD44780.I2C,
        %{name: "display 1"}
      })

  """

  def child_spec(_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def start_link() do
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  def controller_process(args) do
    existing_process(args) || new_process(args)
  end

  defp existing_process({driver_module, config}) when is_atom(driver_module) and is_map(config) do
    DisplayController.whereis({driver_module, config[:name] || "display"})
  end

  defp new_process({driver_module, config} = args)
       when is_atom(driver_module) and is_map(config) do
    case DynamicSupervisor.start_child(__MODULE__, {DisplayController, args}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
