import Config

# Use the mocks defined in test/support/mocks.ex
# https://hexdocs.pm/mox/Mox.html
config :nerves_hello_lcd,
  gpio: MockGPIO,
  i2c: MockI2C,
  display_driver: MockDisplayDriver
