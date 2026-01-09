# Comprehensive Parser Benchmarks
# Run with: mix run bench/all_parsers_bench.exs
#
# Compares ALL FnXML parsers against external libraries

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

defmodule AllParsersBench do
  @small File.read!("bench/data/small.xml")
  @medium File.read!("bench/data/medium.xml")
  @large File.read!("bench/data/large.xml")

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("COMPREHENSIVE PARSER BENCHMARKS")
    IO.puts("All FnXML parsers vs external libraries")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File sizes:")
    IO.puts("  small.xml:  #{byte_size(@small)} bytes")
    IO.puts("  medium.xml: #{byte_size(@medium)} bytes")
    IO.puts("  large.xml:  #{byte_size(@large)} bytes")
    IO.puts("")

    IO.puts("Parsers compared:")
    IO.puts("  External:")
    IO.puts("    - saxy: Highly optimized SAX parser")
    IO.puts("    - erlsom: Erlang XML library")
    IO.puts("    - xmerl: Erlang stdlib DOM parser")
    IO.puts("  FnXML:")
    IO.puts("    - parser_stream: Main parser (Stream mode)")
    IO.puts("    - parser_cb: Main parser (callback mode)")
    IO.puts("    - nimble: NimbleParsec parser (legacy)")
    IO.puts("    - recursive: Recursive descent (sub-binary rest)")
    IO.puts("    - recursive_pos: Position tracking")
    IO.puts("    - recursive_emit: Emit + process dict")
    IO.puts("    - elixir_idx: Elixir index-based")
    IO.puts("    - zig_simd: Zig SIMD scanner")
    IO.puts("")

    # Warm up Zig NIF
    _ = FnXML.Scanner.Zig.find_char(@small, ?<)

    Benchee.run(
      %{
        # External parsers
        "saxy" => fn -> Saxy.parse_string(@medium, NullHandler, nil) end,
        "erlsom" => fn -> :erlsom.simple_form(@medium) end,
        "xmerl" => fn -> :xmerl_scan.string(String.to_charlist(@medium)) end,

        # FnXML parsers
        "nimble" => fn -> FnXML.Parser.NimbleParsec.parse(@medium) |> Stream.run() end,
        "recursive" => fn -> FnXML.Parser.Recursive.parse(@medium) |> Stream.run() end,
        "parser_stream" => fn -> FnXML.Parser.parse(@medium) |> Stream.run() end,
        "parser_cb" => fn -> FnXML.Parser.parse(@medium, fn _ -> :ok end) end,
        "recursive_pos" => fn -> FnXML.Parser.RecursivePos.parse(@medium) |> Stream.run() end,
        "recursive_emit" => fn -> FnXML.Parser.RecursiveEmit.parse(@medium) |> Stream.run() end,
        "elixir_idx" => fn -> FnXML.Parser.Elixir.parse(@medium) |> Stream.run() end,
        "zig_simd" => fn -> FnXML.Parser.Zig.parse(@medium) |> Stream.run() end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_by_size do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("PARSER BENCHMARKS BY FILE SIZE")
    IO.puts(String.duplicate("=", 70) <> "\n")

    # Warm up
    _ = FnXML.Scanner.Zig.find_char(@small, ?<)

    IO.puts("\n--- SMALL FILE (#{byte_size(@small)} bytes) ---\n")

    Benchee.run(
      %{
        "saxy" => fn -> Saxy.parse_string(@small, NullHandler, nil) end,
        "erlsom" => fn -> :erlsom.simple_form(@small) end,
        "xmerl" => fn -> :xmerl_scan.string(String.to_charlist(@small)) end,
        "nimble" => fn -> FnXML.Parser.NimbleParsec.parse(@small) |> Stream.run() end,
        "recursive" => fn -> FnXML.Parser.Recursive.parse(@small) |> Stream.run() end,
        "elixir_idx" => fn -> FnXML.Parser.Elixir.parse(@small) |> Stream.run() end,
        "zig_simd" => fn -> FnXML.Parser.Zig.parse(@small) |> Stream.run() end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [Benchee.Formatters.Console]
    )

    IO.puts("\n--- MEDIUM FILE (#{byte_size(@medium)} bytes) ---\n")

    Benchee.run(
      %{
        "saxy" => fn -> Saxy.parse_string(@medium, NullHandler, nil) end,
        "erlsom" => fn -> :erlsom.simple_form(@medium) end,
        "xmerl" => fn -> :xmerl_scan.string(String.to_charlist(@medium)) end,
        "nimble" => fn -> FnXML.Parser.NimbleParsec.parse(@medium) |> Stream.run() end,
        "recursive" => fn -> FnXML.Parser.Recursive.parse(@medium) |> Stream.run() end,
        "elixir_idx" => fn -> FnXML.Parser.Elixir.parse(@medium) |> Stream.run() end,
        "zig_simd" => fn -> FnXML.Parser.Zig.parse(@medium) |> Stream.run() end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [Benchee.Formatters.Console]
    )

    IO.puts("\n--- LARGE FILE (#{byte_size(@large)} bytes) ---\n")

    Benchee.run(
      %{
        "saxy" => fn -> Saxy.parse_string(@large, NullHandler, nil) end,
        "erlsom" => fn -> :erlsom.simple_form(@large) end,
        "xmerl" => fn -> :xmerl_scan.string(String.to_charlist(@large)) end,
        "nimble" => fn -> FnXML.Parser.NimbleParsec.parse(@large) |> Stream.run() end,
        "recursive" => fn -> FnXML.Parser.Recursive.parse(@large) |> Stream.run() end,
        "elixir_idx" => fn -> FnXML.Parser.Elixir.parse(@large) |> Stream.run() end,
        "zig_simd" => fn -> FnXML.Parser.Zig.parse(@large) |> Stream.run() end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_scanners do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("SCANNER-ONLY BENCHMARKS")
    IO.puts("Comparing scanning approaches")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: medium.xml (#{byte_size(@medium)} bytes)\n")

    Benchee.run(
      %{
        "binary.matches" => fn ->
          :binary.matches(@medium, <<"<">>)
        end,
        "elixir_find_char" => fn ->
          FnXML.Scanner.Elixir.find_char(@medium, ?<)
        end,
        "elixir_find_brackets" => fn ->
          FnXML.Scanner.Elixir.find_brackets(@medium)
        end,
        "elixir_find_elements" => fn ->
          FnXML.Scanner.Elixir.find_elements(@medium)
        end,
        "elixir_find_elements_binary" => fn ->
          FnXML.Scanner.Elixir.find_elements_binary(@medium)
        end,
        "zig_find_char" => fn ->
          FnXML.Scanner.Zig.find_char(@medium, ?<)
        end,
        "zig_find_brackets" => fn ->
          FnXML.Scanner.Zig.find_brackets(@medium)
        end,
        "zig_find_elements" => fn ->
          FnXML.Scanner.Zig.find_elements(@medium)
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [Benchee.Formatters.Console]
    )
  end
end

case System.argv() do
  ["--by-size"] -> AllParsersBench.run_by_size()
  ["--scanners"] -> AllParsersBench.run_scanners()
  _ -> AllParsersBench.run()
end
