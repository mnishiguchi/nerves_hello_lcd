defmodule RGB do
  defstruct r: 255, g: 255, b: 255

  @doc """
  {:ok, rgb} = RGB.start
  RGB.loop(rgb)
  """
  def start do
    rgb = %RGB{r: :rand.uniform(255), g: :rand.uniform(255), b: :rand.uniform(255)}
    {:ok, rgb}
  end

  def loop(%RGB{} = rgb) do
    IO.inspect(rgb)
    Process.sleep(200)

    case :rand.uniform(2) do
      1 -> increment(rgb)
      2 -> decrement(rgb)
    end
    |> loop()
  end

  # Maps a value from 0~255 to 0~100.
  def percentage_from_byte(byte) when byte in 0..0xFF do
    map_range(byte, {0x00, 0xFF}, {0, 100})
  end

  def increment(rgb) do
    key = pick_key()
    value = Map.fetch!(rgb, key)

    if value > 235 do
      decrement(rgb)
    else
      Map.put(rgb, key, value + :rand.uniform(20))
    end
  end

  def decrement(rgb) do
    key = pick_key()
    value = Map.fetch!(rgb, key)

    if value < 20 do
      increment(rgb)
    else
      Map.put(rgb, key, value - :rand.uniform(20))
    end
  end

  def pick_key do
    case :rand.uniform(3) do
      1 -> :r
      2 -> :g
      3 -> :b
    end
  end

  def map_range(x, {in_min, in_max}, {out_min, out_max}) do
    (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
  end
end
