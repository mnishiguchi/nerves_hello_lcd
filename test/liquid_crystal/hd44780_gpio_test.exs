defmodule LiquidCrystal.HD44780.GPIOTest do
  use ExUnit.Case, async: true

  # https://hexdocs.pm/mox/Mox.html
  import Mox

  alias LiquidCrystal.HD44780

  setup do
    setup_gpio_mock()
    :ok
  end

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  test "LiquidCrystal.GPIO mock works" do
    assert {:ok, gpio_ref} = LiquidCrystal.GPIO.open(12, :output)
    assert :ok = LiquidCrystal.GPIO.write(gpio_ref, 1)
    assert :ok = LiquidCrystal.GPIO.write(gpio_ref, 0)
  end

  test "start display" do
    assert %{
             driver_module: LiquidCrystal.HD44780.GPIO,
             name: "display 1",
             font_size: "5x8",
             rows: 2,
             cols: 16,
             rs: 1,
             rs_ref: rs_ref,
             en: 2,
             en_ref: en_ref,
             d4: 7,
             d4_ref: d4_ref,
             d5: 8,
             d5_ref: d5_ref,
             d6: 9,
             d6_ref: d6_ref,
             d7: 10,
             d7_ref: d7_ref,
             entry_mode: 4,
             display_control: 8
           } = start_display()

    assert is_reference(rs_ref)
    assert is_reference(en_ref)
    assert is_reference(d4_ref)
    assert is_reference(d5_ref)
    assert is_reference(d6_ref)
    assert is_reference(d7_ref)
  end

  describe "commands" do
    setup do
      %{display: start_display()}
    end

    test "execute valid commands", %{display: d} do
      assert {:ok, %{}} = HD44780.GPIO.execute(d, :clear)
      assert {:ok, %{}} = HD44780.GPIO.execute(d, :home)
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:print, "Hello"})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:write, 'H'})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:set_cursor, 2, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:cursor, :off})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:cursor, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:blink, :off})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:blink, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:display, :off})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:display, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:autoscroll, :off})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:autoscroll, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:right_to_left, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:left_to_right, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:backlight, :off})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:backlight, :on})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:scroll, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:left, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:right, 2})
      assert {:ok, %{}} = HD44780.GPIO.execute(d, {:char, 2, [1, 1, 1, 1, 1, 1, 1, 1]})
    end

    test "execute unsupported commands", %{display: d} do
      assert {:unsupported, %{}} = HD44780.GPIO.execute(d, {:write, "Hello"})
      assert {:unsupported, %{}} = HD44780.GPIO.execute(d, {:left_to_right, :off})
      assert {:unsupported, %{}} = HD44780.GPIO.execute(d, {:cursor, false})
      assert {:unsupported, %{}} = HD44780.GPIO.execute(d, {:char, "invalid args"})
    end

    test "change entry_mode", %{display: d} do
      assert {:ok, %{entry_mode: 4}} = HD44780.GPIO.execute(d, {:right_to_left, :on})
      assert {:ok, %{entry_mode: 6}} = HD44780.GPIO.execute(d, {:left_to_right, :on})
    end

    test "change display_control", %{display: d} do
      assert {:ok, %{display_control: 8}} = HD44780.GPIO.execute(d, {:display, :off})
      assert {:ok, %{display_control: 12}} = HD44780.GPIO.execute(d, {:display, :on})
    end

    test "change backlight", %{display: d} do
      assert {:ok, %{backlight: false}} = HD44780.GPIO.execute(d, {:backlight, :off})
      assert {:ok, %{backlight: true}} = HD44780.GPIO.execute(d, {:backlight, :on})
    end
  end

  defp start_display do
    {:ok, display} =
      HD44780.GPIO.start(
        name: "display 1",
        rows: 2,
        cols: 16,
        font_size: "5x8",
        rs: 1,
        en: 2,
        d4: 7,
        d5: 8,
        d6: 9,
        d7: 10
      )

    display
  end

  defp setup_gpio_mock() do
    # https://hexdocs.pm/mox/Mox.html#stub/3
    MockGPIO
    |> stub(:open, fn _gpio_pin, :output -> {:ok, Kernel.make_ref()} end)
    |> stub(:write, fn _ref, _hign_low -> :ok end)
  end
end
