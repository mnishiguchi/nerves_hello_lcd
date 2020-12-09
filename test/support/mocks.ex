# https://hexdocs.pm/mox/Mox.html#module-compile-time-requirements
Mox.defmock(MockGPIO, for: LiquidCrystal.CommunicationBus.GPIO)
Mox.defmock(MockI2C, for: LiquidCrystal.CommunicationBus.I2C)
