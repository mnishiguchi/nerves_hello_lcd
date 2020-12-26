# Datasheet https://cdn-shop.adafruit.com/datasheets/PCA9685.pdf
defmodule PCA9685 do
  use Bitwise
  require Logger

  @general_call_address 0x00
  @software_reset 0x06

  # Registers for modes
  @reg_mode1 0x00
  @reg_mode2 0x01

  # # TODO: what is this?
  # @prescale 0xFE

  # Registers for PWM controll
  @reg_led0_on_l 0x06
  @reg_led0_on_h 0x07
  @reg_led0_off_l 0x08
  @reg_led0_off_h 0x09
  @reg_all_led_on_l 0xFA
  @reg_all_led_on_h 0xFB
  @reg_all_led_off_l 0xFC
  @reg_all_led_off_h 0xFD

  # Bits for mode 1
  @m1_sleep 0x10
  @m1_allcall 0x01

  # Bits for mode 2
  @m2_outdrv 0x04

  defmodule State do
    defstruct(
      i2c_ref: nil,
      pca9685_address: 0x40,
      mode1: 0x11,
      mode2: 0x04
    )
  end

  @doc """
  Initialize the PCA9685.

      iex> {:ok, state} = PCA9685.start
  """
  def start(i2c_bus_name \\ "i2c-1") do
    {:ok, i2c_ref} = Circuits.I2C.open(i2c_bus_name)

    initial_state =
      %PCA9685.State{i2c_ref: i2c_ref}
      |> set_pwm_by_width(:all, {0, 0})
      |> assign_mode1(@m1_sleep, false)
      |> assign_mode1(@m1_allcall, true)
      |> assign_mode2(@m2_outdrv, true)
      |> write_mode1()
      |> write_mode2()

    {:ok, initial_state}
  end

  @doc """
  Performs the software reset (Datasheet 7.1.4 and 7.6).

      iex> PCA9685.stop(state)
  """
  def stop(%{i2c_ref: i2c_ref}) do
    :ok = Circuits.I2C.write(i2c_ref, @general_call_address, <<@software_reset>>)
  end

  @doc """
  Set the PWM frequency to the provided value in hertz.
  """

  # defp assign_pwm_freq(freq_hz) do
  #   # TODO
  # end

  @doc """
  Sets a single PWM channel or all PWM channels by specifying the duty cycle in percentage.

      iex> PCA9685.assign_pwm_by_percentage(state, 0, 50.0)
      iex> PCA9685.assign_pwm_by_percentage(state, :all, 50.0)
  """
  def assign_pwm_by_percentage(state, ch, percentage)
      when ch in 0..15 and percentage >= 0.0 and percentage <= 100.0 do
    pulse_width = pulse_width_from_percentage(percentage)
    Logger.debug("#{percentage}% -> #{inspect(pulse_width)}")
    %State{} = set_pwm_by_width(state, ch, pulse_width)
  end

  @doc """
  Sets a single PWM channel or all PWM channels by specifying the start value and the end value of
  the duty cycle.

      iex> PCA9685.set_pwm_by_width(state, 0, {0, 2000})
      iex> PCA9685.set_pwm_by_width(state, :all, {0, 2000})
  """
  def set_pwm_by_width(state, ch, {from, until})
      when ch in 0..15 and from in 0..0xFFF and until in 0..0xFFF do
    <<on_h_byte::4, on_l_byte::8>> = <<from::size(12)>>
    <<off_h_byte::4, off_l_byte::8>> = <<until::size(12)>>

    state
    |> write_byte(@reg_led0_on_l + 4 * ch, on_l_byte)
    |> write_byte(@reg_led0_on_h + 4 * ch, on_h_byte)
    |> write_byte(@reg_led0_off_l + 4 * ch, off_l_byte)
    |> write_byte(@reg_led0_off_h + 4 * ch, off_h_byte)
  end

  def set_pwm_by_width(state, :all, {from, until})
      when from in 0..0xFFF and until in 0..0xFFF do
    <<on_h_byte::4, on_l_byte::8>> = <<from::size(12)>>
    <<off_h_byte::4, off_l_byte::8>> = <<until::size(12)>>

    state
    |> write_byte(@reg_all_led_on_l, on_l_byte)
    |> write_byte(@reg_all_led_on_h, on_h_byte)
    |> write_byte(@reg_all_led_off_l, off_l_byte)
    |> write_byte(@reg_all_led_off_h, off_h_byte)
  end

  @spec pulse_width_from_percentage(float()) :: {0, 0..0xFFF}
  def pulse_width_from_percentage(percentage) when percentage >= 0.0 and percentage <= 100.0 do
    {0, round(4095.0 * percentage / 100)}
  end

  defp assign_mode1(%State{mode1: prev} = state, flag, enabled) when is_boolean(enabled) do
    new_value = if(enabled, do: prev ||| flag, else: prev &&& ~~~flag)
    %State{state | mode1: new_value}
  end

  defp assign_mode2(%State{mode2: prev} = state, flag, enabled) when is_boolean(enabled) do
    new_value = if(enabled, do: prev ||| flag, else: prev &&& ~~~flag)
    %State{state | mode2: new_value}
  end

  defp write_mode1(%State{mode1: mode1} = state), do: write_byte(state, @reg_mode1, mode1)
  defp write_mode2(%State{mode2: mode2} = state), do: write_byte(state, @reg_mode2, mode2)

  @doc """
  A demo program for quick check.

      iex> PCA9685.demo_pwm(state)
  """
  def demo_pwm(state, ch \\ 0) do
    (Enum.to_list(1..100) ++ Enum.to_list(99..0))
    |> Enum.each(fn x ->
      assign_pwm_by_percentage(state, ch, x)
      Process.sleep(10)
    end)

    demo_pwm(state)
  end

  defp write_byte(state, register, data) when register in 0..255 and data in 0..255 do
    %{i2c_ref: i2c_ref, pca9685_address: pca9685_address} = state

    Logger.debug(
      "Wrote #{to_hex(data)} to register #{to_hex(register)} at address #{to_hex(pca9685_address)}"
    )

    :ok = Circuits.I2C.write(i2c_ref, pca9685_address, <<register, data>>)
    state
  end

  defp to_hex(data), do: inspect(data, base: :hex)
end
