defmodule NervesHelloLcd do
  alias NervesHelloLcd.{DisplaySupervisor, DisplayController}

  @doc """
  A test program for quick check.
  """
  def hello_i2c do
    pid =
      DisplaySupervisor.display_controller(
        LcdDisplay.HD44780.I2C,
        name: "display 1"
      )

    cursor_and_print(pid)
    backlight_off_on(pid)
    scroll_right_and_left(pid)

    DisplayController.execute(pid, :clear)
  end

  def hello_gpio do
    pid =
      DisplaySupervisor.display_controller(
        LcdDisplay.HD44780.GPIO,
        %{name: "display 1", rs: 2, rw: 3, en: 4, d4: 23, d5: 24, d6: 25, d7: 26}
      )

    cursor_and_print(pid)
    scroll_right_and_left(pid)

    DisplayController.execute(pid, :clear)
  end

  defp cursor_and_print(pid) do
    DisplayController.execute(pid, {:cursor, true})
    DisplayController.execute(pid, {:print, "Hello"})
    Process.sleep(500)
    DisplayController.execute(pid, {:right, 1})
    DisplayController.execute(pid, {:print, "world"})
    Process.sleep(500)
    DisplayController.execute(pid, {:cursor, false})
    Process.sleep(500)
  end

  defp backlight_off_on(pid) do
    DisplayController.execute(pid, {:backlight, false})
    Process.sleep(500)
    DisplayController.execute(pid, {:backlight, true})
    Process.sleep(500)
  end

  defp scroll_right_and_left(pid) do
    0..3
    |> Enum.each(fn _ ->
      DisplayController.execute(pid, {:scroll, 1})
      Process.sleep(300)
    end)

    0..3
    |> Enum.each(fn _ ->
      DisplayController.execute(pid, {:scroll, -1})
      Process.sleep(300)
    end)
  end
end
