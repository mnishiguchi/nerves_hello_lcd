defmodule LiquidCrystal.CommunicationBus do
  @moduledoc """
  Defines a behaviour required for a communication bus.
  """

  defmodule GPIO do
    @callback open(pos_integer, :output) :: {:ok, reference} | {:error, any}
    @callback write(reference, 0 | 1) :: :ok | {:error, any}
  end

  defmodule I2C do
    @callback open(binary) :: {:ok, reference} | {:error, any}
    @callback write(reference, pos_integer, binary) :: :ok | {:error, any}
  end
end

defmodule LiquidCrystal.GPIO do
  @moduledoc """
  Lets you control GPIOs.
  """

  @behaviour LiquidCrystal.CommunicationBus.GPIO

  @gpio Application.get_env(:nerves_hello_lcd, :gpio, Circuits.GPIO)

  def open(gpio_pin, :output), do: @gpio.open(gpio_pin, :output)

  def write(gpio_ref, 0), do: @gpio.write(gpio_ref, 0)
  def write(gpio_ref, 1), do: @gpio.write(gpio_ref, 1)
end

defmodule LiquidCrystal.I2C do
  @moduledoc """
  Lets you communicate with hardware devices using the I2C protocol
  """

  @behaviour LiquidCrystal.CommunicationBus.I2C

  @i2c Application.get_env(:nerves_hello_lcd, :i2c, Circuits.I2C)

  def open(i2c_device), do: @i2c.open(i2c_device)

  def write(i2c_ref, i2c_address, data), do: @i2c.write(i2c_ref, i2c_address, data)
end
