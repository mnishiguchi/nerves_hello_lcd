defmodule NervesHelloLcd do
  alias NervesHelloLcd.{DisplaySupervisor, DisplayController}

  @doc """
  A test program for quick check.
  """
  def hello do
    pid = DisplaySupervisor.controller_process({
      LiquidCrystal.HD44780.I2C,
      %{name: "display 1"}
    })
    DisplayController.execute(pid, {:cursor, :on})
    DisplayController.execute(pid, {:print, "Hello"})
    Process.sleep(500)
    DisplayController.execute(pid, {:right, 1})
    DisplayController.execute(pid, {:print, "world"})
    Process.sleep(500)
    DisplayController.execute(pid, {:backlight, :off})
    Process.sleep(500)
    DisplayController.execute(pid, {:backlight, :on})
    Process.sleep(500)
    DisplayController.execute(pid, {:scroll, 1})
    Process.sleep(500)
    DisplayController.execute(pid, {:scroll, 1})
    Process.sleep(500)
    DisplayController.execute(pid, {:scroll, 1})
    Process.sleep(500)
    DisplayController.execute(pid, {:scroll, -1})
    Process.sleep(500)
    DisplayController.execute(pid, {:scroll, -1})
    Process.sleep(500)
    DisplayController.execute(pid, {:scroll, -1})
    Process.sleep(500)
    DisplayController.execute(pid, :clear)

    # TODO: Test more commands
    # Process.sleep(500)
    # DisplayController.execute(pid, {:set_cursor, 0, 2})
    # DisplayController.execute(pid, {:print, "Hello"})
    # Process.sleep(500)
    # DisplayController.execute(pid, {:set_cursor, 1, 4})
    # DisplayController.execute(pid, {:print, "world"})
    # Process.sleep(500)
    # DisplayController.execute(pid, :clear)
  end
end
