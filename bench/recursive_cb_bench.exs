defmodule NullHandler do
  @behaviour Saxy.Handler
  def handle_event(_, _, state), do: {:ok, state}
end

medium = File.read!("bench/data/medium.xml")

IO.puts("Comparing recursive descent parser variants")
IO.puts("File size: #{byte_size(medium)} bytes\n")

Benchee.run(
  %{
    "recursive" => fn -> FnXML.Parser.Recursive.parse(medium) |> Stream.run() end,
    "recursive_cps" => fn -> FnXML.Parser.RecursiveCPS.parse(medium) |> Stream.run() end,
    "saxy" => fn -> Saxy.parse_string(medium, NullHandler, nil) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
