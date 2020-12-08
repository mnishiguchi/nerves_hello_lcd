defmodule LiquidCrystal.HD44780.GPIO do
  @moduledoc """
  Knows how to commuticate with HD44780 type display via GPIO pins.

  ## Examples

      config = %{
        name: "display 1", # Identifier
        rs: 1,             # The GPIO pin ID for the RS signal
        en: 2,             # The GPIO pin ID for the EN signal
        d4: 7,             # The GPIO pin ID for the D4 signal
        d5: 8,             # The GPIO pin ID for the D5 signal
        d6: 9,             # The GPIO pin ID for the D6 signal
        d7: 10,            # The GPIO pin ID for the D7 signal
        rows: 2,           # The number of display rows
        cols: 16,          # The number of display columns
        font_size: "5x8"   # "5x10" or "5x8"
      }

      HD44780.GPIO.start(config)

  """

  use Bitwise
  require Logger

  @behaviour LiquidCrystal.Driver

  # flags for function set
  @font_size_5x8 0x00
  @font_size_5x10 0x04
  @number_of_lines_1 0x00
  @number_of_lines_2 0x08

  # commands
  @cmd_clear_display 0x01
  @cmd_return_home 0x02
  @cmd_entry_mode_set 0x04
  @cmd_display_control 0x08
  @cmd_cursor_shift_control 0x10
  @cmd_function_set 0x20
  @cmd_set_cgram_address 0x40
  @cmd_set_ddram_address 0x80

  # flags for display entry mode
  @entry_left 0x02
  @entry_increment 0x01

  # flags for display on/off control
  @ctl_display 0x04
  @ctl_cursor 0x02
  @ctl_blink 0x01

  # flags for display/cursor shift
  @shift_display 0x08
  @shift_right 0x04

  @pins_4bit [:rs, :en, :d4, :d5, :d6, :d7]

  @required_config_keys [:name, :rs, :en, :d4, :d5, :d6, :d7, :rows, :cols]
  @optional_config_keys [:font_size]

  @impl true
  def start(opts) do
    config_key_allowlist = @required_config_keys ++ @optional_config_keys

    # Ensure that the datatype is map and remove garbage keys.
    opts = opts |> Enum.into(%{}) |> Map.take(config_key_allowlist)

    # Raise an error when required key is missing.
    @required_config_keys |> Enum.each(&Map.fetch!(opts, &1))

    number_of_lines = if opts[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if opts[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    display =
      Map.merge(opts, %{
        rows: opts[:rows] || 2,
        cols: opts[:cols] || 16,
        # Initial values for features that we can change later.
        # They will be updated when the "command" function is called.
        display_control: @cmd_display_control,
        entry_mode: @cmd_entry_mode_set
      })
      |> open_gpio_pins(@pins_4bit)
      |> register_select(0)
      |> enable(0)
      |> initialize_display(function_set: @cmd_function_set ||| font_size ||| number_of_lines)

    {:ok, display}
  end

  @impl true
  def stop(display) do
    {:ok, display} = execute(display, {:display, :off})

    @pins_4bit
    |> Enum.map(fn pin_name -> String.to_atom("#{pin_name}_ref") end)
    |> Enum.filter(fn x -> not is_nil(display[x]) end)
    |> Enum.each(fn x -> Circuits.GPIO.close(display[x]) end)

    :ok
  end

  @doc """
  Initializes the display for 4-Bit Interface. See Hitachi HD44780 datasheet page 46 for details.
  """
  def initialize_display(display, function_set: function_set) do
    display
    # Function set (8-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(5)
    |> write_four_bits(0x03)
    |> delay(1)

    # Function set (4-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x02)

    # Function set (4-bit mode; Interface is 4 bits long)
    # The number of display lines and character font cannot be changed after this point.
    |> write_instruction(function_set)
    |> write_feature(:display_control)
    |> clear()
    |> write_feature(:entry_mode)
  end

  # setup GPIO output pins, add the refs to the config and return
  defp open_gpio_pins(config, pins) do
    config
    |> Map.take(pins)
    |> Enum.map(fn {k, v} -> {String.to_atom("#{k}_ref"), start_pin(v, :output)} end)
    |> Map.new()
    |> Map.merge(config)
  end

  # start Circuits.GPIO to manage a GPIO pin and return the ref
  defp start_pin(pin, direction) do
    with {:ok, ref} <- Circuits.GPIO.open(pin, direction), do: ref
  end

  @impl true
  def execute(display, :clear) do
    clear(display)
    {:ok, display}
  end

  def execute(display, :home) do
    home(display)
    {:ok, display}
  end

  # Write a string.
  def execute(display, {:print, string}) when is_binary(string) do
    # Translates a string to a charlist (list of bytes).
    execute(display, {:write, to_charlist(string)})
  end

  # Writes a list of integers.
  def execute(display, {:write, byte}) when is_list(byte) do
    byte |> Enum.each(fn x -> write_data(display, x) end)
    {:ok, display}
  end

  def execute(display, {:set_cursor, row, col}) do
    {:ok, set_cursor(display, row, col)}
  end

  def execute(display, {:cursor, :off}) do
    {:ok, disable_feature(display, :display_control, @ctl_cursor)}
  end

  def execute(display, {:cursor, :on}) do
    {:ok, enable_feature(display, :display_control, @ctl_cursor)}
  end

  def execute(display, {:blink, :off}) do
    {:ok, disable_feature(display, :display_control, @ctl_blink)}
  end

  def execute(display, {:blink, :on}) do
    {:ok, enable_feature(display, :display_control, @ctl_blink)}
  end

  def execute(display, {:display, :off}) do
    {:ok, disable_feature(display, :display_control, @ctl_display)}
  end

  def execute(display, {:display, :on}) do
    {:ok, enable_feature(display, :display_control, @ctl_display)}
  end

  def execute(display, {:autoscroll, :off}) do
    {:ok, disable_feature(display, :entry_mode, @entry_increment)}
  end

  def execute(display, {:autoscroll, :on}) do
    {:ok, enable_feature(display, :entry_mode, @entry_increment)}
  end

  def execute(display, {:right_to_left, :on}) do
    {:ok, disable_feature(display, :entry_mode, @entry_left)}
  end

  def execute(display, {:left_to_right, :on}) do
    {:ok, enable_feature(display, :entry_mode, @entry_left)}
  end

  def execute(display, {:scroll, 0}), do: {:ok, display}

  # Scroll the entire display left
  def execute(display, {:scroll, cols}) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display)
    execute(display, {:scroll, cols + 1})
  end

  # Scroll the entire display right
  def execute(display, {:scroll, cols}) do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_display ||| @shift_right)
    execute(display, {:scroll, cols - 1})
  end

  # Move cursor right
  def execute(display, {:right, 0}), do: {:ok, display}

  def execute(display, {:right, cols}) do
    write_instruction(display, @cmd_cursor_shift_control ||| @shift_right)
    execute(display, {:right, cols - 1})
  end

  # Move cursor left
  def execute(display, {:left, 0}), do: {:ok, display}

  def execute(display, {:left, cols}) do
    write_instruction(display, @cmd_cursor_shift_control)
    execute(display, {:left, cols - 1})
  end

  # Program custom character to CGRAM. We only have 8 CGRAM locations.
  def execute(display, {:char, index, bitmap}) when index in 0..7 and length(bitmap) === 8 do
    write_instruction(display, @cmd_set_cgram_address ||| index <<< 3)
    for line <- bitmap, do: write_data(display, line)
    {:ok, display}
  end

  def execute(display, _), do: {:unsupported, display}

  defp clear(display), do: display |> write_instruction(@cmd_clear_display) |> delay(3)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(3)

  # ---
  # Low level data pushing commands
  # ---

  # Determines the starting DDRAM address of each display row and returns a map
  # for up to 4 rows. Rows are not contiguous in memory.
  defp row_offsets(cols) do
    %{0 => 0x00, 1 => 0x40, 2 => 0x00 + cols, 3 => 0x40 + cols}
  end

  # Set the DDRAM address corresponding to the specified cursor position.
  defp set_cursor(display, cursor_row, cursor_col) when cursor_row > 0 and cursor_col > 0 do
    %{rows: display_rows, cols: display_cols} = display
    col = min(cursor_col, display_cols - 1)
    row = min(cursor_col, display_rows - 1)
    %{^row => offset} = row_offsets(display_cols)
    write_instruction(display, @cmd_set_ddram_address ||| col + offset)
  end

  defp disable_feature(display, feature_key, flag)
       when is_atom(feature_key) and is_integer(flag) do
    %{display | feature_key => Map.fetch!(display, feature_key) &&& ~~~flag}
    |> write_feature(feature_key)
  end

  defp enable_feature(display, feature_key, flag)
       when is_atom(feature_key) and is_integer(flag) do
    %{display | feature_key => Map.fetch!(display, feature_key) ||| flag}
    |> write_feature(feature_key)
  end

  # Write a feature register to the controller and return the state.
  defp write_feature(display, feature_key) when is_atom(feature_key) do
    display |> write_byte(Map.fetch!(display, feature_key))
  end

  defp write_instruction(display, byte), do: write_byte(display, byte, 0)
  defp write_data(display, byte), do: write_byte(display, byte, 1)

  defp write_byte(display, byte, mode \\ 0) when is_integer(byte) and mode in 0..1 do
    display
    |> register_select(mode)
    |> delay(1)
    |> write_four_bits(byte >>> 4)
    |> write_four_bits(byte)
  end

  defp write_four_bits(display, bits) when is_integer(bits) do
    :ok = Circuits.GPIO.write(display.d4_ref, bits &&& 0x01)
    :ok = Circuits.GPIO.write(display.d5_ref, bits >>> 1 &&& 0x01)
    :ok = Circuits.GPIO.write(display.d6_ref, bits >>> 2 &&& 0x01)
    :ok = Circuits.GPIO.write(display.d7_ref, bits >>> 3 &&& 0x01)
    pulse_enable(display)
  end

  defp register_select(display, flag) when flag in 0..1 do
    :ok = Circuits.GPIO.write(display.rs_ref, flag)
    display
  end

  defp enable(display, flag) when flag in 0..1 do
    :ok = Circuits.GPIO.write(display.en_ref, flag)
    display
  end

  defp pulse_enable(display) do
    display |> enable(0) |> enable(1) |> enable(0)
  end

  defp delay(display, milliseconds) do
    Process.sleep(milliseconds)
    display
  end
end
