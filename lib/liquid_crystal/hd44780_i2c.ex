defmodule LiquidCrystal.HD44780.I2C do
  @moduledoc """
  Knows how to commuticate with HD44780 type display via I2C.

  ## Examples

      # Start the LCD driver and get the initial display state.
      {:ok, display} = HD44780.I2C.start([])

      # Run a command as needed. The display state will also be updated.
      {:ok, display} = HD44780.I2C.execute(display, {:print, "Hello world"})
      {:ok, display} = HD44780.I2C.execute(display, {:backlight, :off})
      {:ok, display} = HD44780.I2C.execute(display, {:backlight, :on})
      {:ok, display} = HD44780.I2C.execute(display, {:clear, nil})

  """

  use Bitwise
  require Logger

  @behaviour LiquidCrystal.Driver

  # flags for function set
  @font_size_5x10 0x04
  @font_size_5x8 0x00
  @number_of_lines_2 0x08
  @number_of_lines_1 0x00

  # commands
  @cmd_clear_ 0x01
  @cmd_return_home 0x02
  @cmd_entry_mode_set 0x04
  @cmd__control 0x08
  @cmd_cursor_shift_control 0x10
  @cmd_function_set 0x20
  @cmd_set_cgram_address 0x40
  @cmd_set_ddram_address 0x80

  # flags for display entry mode
  @entry_left 0x02
  @entry_increment 0x01

  # flags for display on/off control
  @display_on 0x04
  @cursor_on 0x02
  @blink_on 0x01

  # flags for display/cursor shift
  @display_move 0x08
  @move_right 0x04

  # flags for backlight control
  @backlight_on 0x08

  @enable_bit 0b00000100

  @default_i2c_address 0x27
  @default_rows 2
  @default_cols 16

  @impl true
  def start(opts \\ []) do
    i2c_device = opts[:i2c_device] || "i2c-1"
    {:ok, i2c_ref} = Circuits.I2C.open(i2c_device)

    number_of_lines = if opts[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if opts[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    display =
      %{
        name: opts[:name] || i2c_device,
        i2c_ref: i2c_ref,
        i2c_address: opts[:i2c_address] || @default_i2c_address,
        rows: opts[:rows] || @default_rows,
        cols: opts[:cols] || @default_cols,

        # Initial values for features that we can change later.
        # They will be updated when the "command" function is called.
        entry_mode: @cmd_entry_mode_set ||| @entry_left,
        display_control: @cmd__control ||| @display_on,
        backlight: true
      }
      |> expander_write(@backlight_on)
      |> initialize_(function_set: @cmd_function_set ||| font_size ||| number_of_lines)

    {:ok, display}
  end

  @impl true
  def stop(display) do
    execute(display, {:display, :off})
    Circuits.I2C.close(display.i2c_device)
    :ok
  end

  @doc """
  Initializes the display for 4-Bit Interface. See Hitachi HD44780 datasheet page 46 for details.
  """
  def initialize_(display, function_set: function_set) do
    display
    # Function set (8-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x03 <<< 4)
    |> delay(5)
    |> write_four_bits(0x03 <<< 4)
    |> delay(5)
    |> write_four_bits(0x03 <<< 4)
    |> delay(1)

    # Function set (4-bit mode; Interface is 8 bits long)
    |> write_four_bits(0x02 <<< 4)

    # Function set (4-bit mode; Interface is 4 bits long)
    # The number of display lines and character font cannot be changed after this point.
    |> write_instruction(function_set)
    |> write_feature(:display_control)
    |> clear()
    |> write_feature(:entry_mode)
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
    {:ok, disable_feature(display, :display_control, @cursor_on)}
  end

  def execute(display, {:cursor, :on}) do
    {:ok, enable_feature(display, :display_control, @cursor_on)}
  end

  def execute(display, {:blink, :off}) do
    {:ok, disable_feature(display, :display_control, @blink_on)}
  end

  def execute(display, {:blink, :on}) do
    {:ok, enable_feature(display, :display_control, @blink_on)}
  end

  def execute(display, {:display, :off}) do
    {:ok, disable_feature(display, :display_control, @display_on)}
  end

  def execute(display, {:display, :on}) do
    {:ok, enable_feature(display, :display_control, @display_on)}
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

  def execute(display, {:backlight, :off}), do: {:ok, set_backlight(display, false)}
  def execute(display, {:backlight, :on}), do: {:ok, set_backlight(display, true)}

  def execute(display, {:scroll, 0}), do: {:ok, display}

  # Scroll the entire display left
  def execute(display, {:scroll, cols}) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @display_move)
    execute(display, {:scroll, cols + 1})
  end

  # Scroll the entire display right
  def execute(display, {:scroll, cols}) when cols > 0 do
    write_instruction(display, @cmd_cursor_shift_control ||| @display_move ||| @move_right)
    execute(display, {:scroll, cols - 1})
  end

  # Move cursor right
  def execute(display, {:right, 0}), do: {:ok, display}

  def execute(display, {:right, cols}) do
    write_instruction(display, @cmd_cursor_shift_control ||| @move_right)
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

  defp clear(display), do: display |> write_instruction(@cmd_clear_) |> delay(3)

  defp home(display), do: display |> write_instruction(@cmd_return_home) |> delay(3)

  # ---
  # Low level data pushing commands
  # ---

  # DDRAM is organized as two 40 byte rows. In a 2x display the first row
  # Determines the starting DDRAM address of each display row and returns a map
  # for up to 4 rows. Rows are not contiguous in memory.
  defp row_offsets(cols) when is_integer(cols) do
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

  defp set_backlight(display, flag) when is_boolean(flag) do
    # Set backlight and write 0 (nothing) to trigger it.
    %{display | backlight: flag} |> expander_write(0)
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

  # Write a feature based on the display state.
  defp write_feature(display, feature_key) when is_atom(feature_key) do
    display |> write_instruction(Map.fetch!(display, feature_key))
  end

  defp write_instruction(display, byte), do: write_byte(display, byte, 0)
  defp write_data(display, byte), do: write_byte(display, byte, 1)

  defp write_byte(display, byte, mode) when is_integer(byte) and mode in 0..1 do
    display
    |> write_four_bits((byte &&& 0xF0) ||| mode)
    |> write_four_bits((byte <<< 4 &&& 0xF0) ||| mode)
  end

  # Write 4 bits to the device
  defp write_four_bits(display, byte) when is_integer(byte) do
    display |> expander_write(byte) |> pulse_enable(byte)
  end

  defp pulse_enable(display, byte) do
    display
    |> expander_write(byte ||| @enable_bit)
    |> expander_write(byte &&& ~~~@enable_bit)
  end

  defp expander_write(display, byte)
       when is_reference(display.i2c_ref) and is_integer(display.i2c_address) and
              is_boolean(display.backlight) and is_integer(byte) do
    %{i2c_ref: i2c_ref, i2c_address: i2c_address, backlight: backlight} = display
    # log_write(display, byte)
    data = if(backlight, do: <<byte ||| @backlight_on>>, else: <<byte>>)
    :ok = Circuits.I2C.write(i2c_ref, i2c_address, data)
    display
  end

  defp delay(display, milliseconds) do
    Process.sleep(milliseconds)
    display
  end

  # defp log_write(%{i2c_address: i2c_address}, byte) do
  #   byte_for_log = Integer.to_string(byte, 2) |> String.pad_leading(8, "0")
  #   addr_hex = Integer.to_string(i2c_address, 16)
  #   Logger.info("Write #{byte_for_log} to 0x#{addr_hex}")
  # end
end
