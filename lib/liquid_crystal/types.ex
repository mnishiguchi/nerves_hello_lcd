defmodule LiquidCrystal.Types do
  defmacro __using__(_opts) do
    quote do
      @type display :: map

      @type feature :: :entry_mode | :display_control

      @type command ::
              :clear
              | :home
              | {:print, String.t()}
              | {:write, charlist}
              | {:set_cursor, integer, integer}
              | {:cursor, :on | :off}
              | {:blink, :on | :off}
              | {:display, :on | :off}
              | {:autoscroll, :on | :off}
              | {:right_to_left, :on}
              | {:left_to_right, :on}
              | {:backlight, :on | :off}
              | {:scroll, integer}
              | {:left, integer}
              | {:right, integer}
              | {:char, integer, byte}
    end
  end
end
