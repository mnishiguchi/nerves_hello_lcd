defmodule NervesHelloLcdTest do
  use ExUnit.Case
  doctest NervesHelloLcd

  test "greets the world" do
    assert NervesHelloLcd.hello() == :world
  end
end
