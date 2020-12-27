defmodule NervesHelloLcd do
  @moduledoc """
  Some test programs for quick check.

  NervesHelloLcd.hello_i2c
  """

  def hello_i2c() do
    pid = LcdDisplay.start_display(LcdDisplay.HD44780.I2C, %{display_name: "display 1"})
    qa_steps(pid)
    pid
  end

  def hello_gpio() do
    config = %{
      display_name: "display 2",
      pin_rs: 5,
      pin_rw: 6,
      pin_en: 13,
      pin_d4: 23,
      pin_d5: 24,
      pin_d6: 25,
      pin_d7: 26,
      pin_led_5v: 12
    }

    pid = LcdDisplay.start_display(LcdDisplay.HD44780.GPIO, config)
    qa_steps(pid)
    pid
  end

  def hello_pwm(ch \\ 0) do
    {:ok, state} = PCA9685.start(%{})
    hello_pwm_loop(state, ch)
  end

  defp hello_pwm_loop(state, ch \\ 0) do
    (Enum.to_list(1..100) ++ Enum.to_list(99..0))
    |> Enum.each(fn x ->
      PCA9685.set_pwm_by_percentage(state, ch, x)
      Process.sleep(10)
    end)

    hello_pwm_loop(state)
  end

  defp qa_steps(pid) do
    cursor_and_print(pid)
    blink_and_print(pid)
    backlight_off_on(pid)
    scroll_right_and_left(pid)
    autoscroll(pid)
    text_direction(pid)
    lgtm(pid)
    pid
  end

  defp cursor_and_print(pid) do
    introduction(pid, "Cursor")

    LcdDisplay.execute(pid, {:cursor, true})
    print_text(pid, 5)
    Process.sleep(1234)
  end

  defp blink_and_print(pid) do
    introduction(pid, "Blink")

    LcdDisplay.execute(pid, {:blink, true})
    print_text(pid, 5)
    Process.sleep(1234)
  end

  defp backlight_off_on(pid) do
    introduction(pid, "Backlight")

    LcdDisplay.execute(pid, {:backlight, false})
    Process.sleep(500)
    LcdDisplay.execute(pid, {:backlight, true})
    Process.sleep(1234)
  end

  defp scroll_right_and_left(pid) do
    introduction(pid, "Scroll")

    LcdDisplay.execute(pid, {:print, "<>"})

    0..3
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, {:scroll, 1})
      Process.sleep(222)
    end)

    0..3
    |> Enum.each(fn _ ->
      LcdDisplay.execute(pid, {:scroll, -1})
      Process.sleep(222)
    end)

    Process.sleep(1234)
  end

  # TODO: Endless autoscroll?
  defp autoscroll(pid) do
    introduction(pid, "autoscroll")

    LcdDisplay.execute(pid, {:autoscroll, true})
    LcdDisplay.execute(pid, {:set_cursor, 1, 15})
    print_text(pid)
    Process.sleep(1234)
  end

  defp text_direction(pid) do
    introduction(pid, "Text direction")
    LcdDisplay.execute(pid, {:set_cursor, 0, 15})
    LcdDisplay.execute(pid, :entry_right_to_left)
    print_text(pid)
    LcdDisplay.execute(pid, {:set_cursor, 1, 0})
    LcdDisplay.execute(pid, :entry_left_to_right)
    print_text(pid)
    Process.sleep(1234)
  end

  defp print_text(pid, limit \\ 16) do
    ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    |> Enum.take(limit)
    |> Enum.each(fn x ->
      {:ok, _} = LcdDisplay.execute(pid, {:print, "#{x}"})
      Process.sleep(222)
    end)
  end

  defp lgtm(pid) do
    LcdDisplay.execute(pid, :clear)
    LcdDisplay.execute(pid, {:set_cursor, 0, 0})
    LcdDisplay.execute(pid, {:print, "LGTM"})
  end

  defp introduction(pid, message) do
    LcdDisplay.execute(pid, :clear)

    # Default setup
    LcdDisplay.execute(pid, {:display, true})
    LcdDisplay.execute(pid, {:cursor, false})
    LcdDisplay.execute(pid, {:blink, false})
    LcdDisplay.execute(pid, {:autoscroll, false})

    # Print message and clear
    LcdDisplay.execute(pid, {:print, message})
    Process.sleep(1234)
    LcdDisplay.execute(pid, :clear)
  end
end
