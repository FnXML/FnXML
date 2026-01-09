# Zig Parser Benchmarks
# Run with: mix run bench/zig_parse_bench.exs
#
# Compares FnXML parsers: NimbleParsec vs Zig SIMD-accelerated

defmodule NullHandler do
  @behaviour Saxy.Handler

  @impl true
  def handle_event(:start_document, _prolog, state), do: {:ok, state}
  @impl true
  def handle_event(:end_document, _data, state), do: {:ok, state}
  @impl true
  def handle_event(:start_element, _data, state), do: {:ok, state}
  @impl true
  def handle_event(:end_element, _name, state), do: {:ok, state}
  @impl true
  def handle_event(:characters, _chars, state), do: {:ok, state}
  @impl true
  def handle_event(:cdata, _cdata, state), do: {:ok, state}
  @impl true
  def handle_event(:comment, _comment, state), do: {:ok, state}
end

defmodule ZigParseBench do
  @small File.read!("bench/data/small.xml")
  @medium File.read!("bench/data/medium.xml")
  @large File.read!("bench/data/large.xml")

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("ZIG SIMD PARSER BENCHMARKS")
    IO.puts("Comparing: NimbleParsec vs Zig SIMD vs Saxy")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File sizes:")
    IO.puts("  small.xml:  #{byte_size(@small)} bytes")
    IO.puts("  medium.xml: #{byte_size(@medium)} bytes")
    IO.puts("  large.xml:  #{byte_size(@large)} bytes")
    IO.puts("")

    # Warm up Zig NIF
    _ = FnXML.Scanner.Zig.find_char(@small, ?<)

    Benchee.run(
      %{
        # NimbleParsec parser
        "nimble_small" => fn ->
          FnXML.Parser.parse(@small) |> Stream.run()
        end,
        "nimble_medium" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,
        "nimble_large" => fn ->
          FnXML.Parser.parse(@large) |> Stream.run()
        end,

        # Zig SIMD parser
        "zig_small" => fn ->
          FnXML.Parser.Zig.parse(@small) |> Stream.run()
        end,
        "zig_medium" => fn ->
          FnXML.Parser.Zig.parse(@medium) |> Stream.run()
        end,
        "zig_large" => fn ->
          FnXML.Parser.Zig.parse(@large) |> Stream.run()
        end,

        # Saxy for reference
        "saxy_small" => fn ->
          Saxy.parse_string(@small, NullHandler, nil)
        end,
        "saxy_medium" => fn ->
          Saxy.parse_string(@medium, NullHandler, nil)
        end,
        "saxy_large" => fn ->
          Saxy.parse_string(@large, NullHandler, nil)
        end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end

  def run_quick do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("QUICK ZIG PARSER BENCHMARK (medium file only)")
    IO.puts("Comparing: NimbleParsec vs Zig SIMD vs Saxy")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: medium.xml (#{byte_size(@medium)} bytes)")
    IO.puts("")

    # Warm up
    _ = FnXML.Scanner.Zig.find_char(@medium, ?<)

    Benchee.run(
      %{
        "saxy" => fn ->
          Saxy.parse_string(@medium, NullHandler, nil)
        end,
        "nimble" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,
        "zig_simd" => fn ->
          FnXML.Parser.Zig.parse(@medium) |> Stream.run()
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end

  def run_scanner_only do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("SCANNER-ONLY BENCHMARK")
    IO.puts("Comparing just the scanning phase")
    IO.puts(String.duplicate("=", 70) <> "\n")

    Benchee.run(
      %{
        "zig_find_char_<" => fn ->
          FnXML.Scanner.Zig.find_char(@medium, ?<)
        end,
        "zig_find_brackets" => fn ->
          FnXML.Scanner.Zig.find_brackets(@medium)
        end,
        "zig_find_elements" => fn ->
          FnXML.Scanner.Zig.find_elements(@medium)
        end,
        "binary_matches" => fn ->
          :binary.matches(@medium, <<"<">>)
        end,
        "elixir_scan" => fn ->
          find_positions(@medium, ?<)
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end

  defp find_positions(binary, char) do
    do_find(binary, char, 0, [])
  end

  defp do_find(<<>>, _char, _pos, acc), do: Enum.reverse(acc)
  defp do_find(<<c, rest::binary>>, char, pos, acc) when c == char do
    do_find(rest, char, pos + 1, [pos | acc])
  end
  defp do_find(<<_, rest::binary>>, char, pos, acc) do
    do_find(rest, char, pos + 1, acc)
  end
end

case System.argv() do
  ["--quick"] -> ZigParseBench.run_quick()
  ["--scanner"] -> ZigParseBench.run_scanner_only()
  _ -> ZigParseBench.run()
end
