import Config

# Use the mocks defined in test/support/mocks.ex
# https://hexdocs.pm/mox/Mox.html
config :nerves_hello_lcd, :gpio, MockGPIO
config :nerves_hello_lcd, :i2c, MockI2C
