# Comprehensive Parser Benchmarks
# Run with: mix run bench/all_parsers_bench.exs
#
# Compares FnXML parsers against external libraries

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

# Define configurable parsers inline using the macro
# Edition 5 variants
defmodule Bench.CompliantEd5 do
  @moduledoc "All features enabled - Edition 5"
  use FnXML.MacroBlkParserGenerator, edition: 5, disable: []
end

defmodule Bench.FastEd5 do
  @moduledoc "No position, no whitespace - Edition 5"
  use FnXML.MacroBlkParserGenerator, edition: 5, disable: [:space, :position]
end

defmodule Bench.MinimalEd5 do
  @moduledoc "Only elements and text - Edition 5"
  use FnXML.MacroBlkParserGenerator,
    edition: 5,
    disable: [:space, :position, :comment, :cdata, :processing_instruction, :prolog, :dtd]
end

# Edition 4 variants
defmodule Bench.CompliantEd4 do
  @moduledoc "All features enabled - Edition 4"
  use FnXML.MacroBlkParserGenerator, edition: 4, disable: []
end

defmodule Bench.FastEd4 do
  @moduledoc "No position, no whitespace - Edition 4"
  use FnXML.MacroBlkParserGenerator, edition: 4, disable: [:space, :position]
end

defmodule Bench.MinimalEd4 do
  @moduledoc "Only elements and text - Edition 4"
  use FnXML.MacroBlkParserGenerator,
    edition: 4,
    disable: [:space, :position, :comment, :cdata, :processing_instruction, :prolog, :dtd]
end

# Aliases for backward compatibility
defmodule Bench.Compliant do
  @moduledoc "Alias for CompliantEd5"
  defdelegate parse(xml), to: Bench.CompliantEd5
  defdelegate stream(enum), to: Bench.CompliantEd5
end

defmodule Bench.Fast do
  @moduledoc "Alias for FastEd5"
  defdelegate parse(xml), to: Bench.FastEd5
  defdelegate stream(enum), to: Bench.FastEd5
end

defmodule Bench.Minimal do
  @moduledoc "Alias for MinimalEd5"
  defdelegate parse(xml), to: Bench.MinimalEd5
  defdelegate stream(enum), to: Bench.MinimalEd5
end

defmodule AllParsersBench do
  @small File.read!("bench/data/small.xml")
  @medium File.read!("bench/data/medium.xml")
  @large File.read!("bench/data/large.xml")

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("COMPREHENSIVE PARSER BENCHMARKS")
    IO.puts("FnXML parsers vs external libraries")
    IO.puts(String.duplicate("=", 70) <> "\n")

    print_file_info()
    print_parser_info()

    IO.puts("\n--- MEDIUM FILE BENCHMARK ---\n")

    Benchee.run(
      %{
        # External parsers
        "saxy" => fn -> Saxy.parse_string(@medium, NullHandler, nil) end,
        "erlsom" => fn -> :erlsom.simple_form(@medium) end,
        "xmerl" => fn -> :xmerl_scan.string(String.to_charlist(@medium)) end,

        # FnXML MacroBlkParser - Edition 5
        "compliant_ed5" => fn -> Bench.CompliantEd5.parse(@medium) end,
        "fast_ed5" => fn -> Bench.FastEd5.parse(@medium) end,
        "minimal_ed5" => fn -> Bench.MinimalEd5.parse(@medium) end,

        # FnXML MacroBlkParser - Edition 4
        "compliant_ed4" => fn -> Bench.CompliantEd4.parse(@medium) end,
        "fast_ed4" => fn -> Bench.FastEd4.parse(@medium) end,
        "minimal_ed4" => fn -> Bench.MinimalEd4.parse(@medium) end,

        # FnXML legacy parsers
        "ex_blk_parser" => fn -> FnXML.ExBlkParser.parse(@medium) end,
        "fast_ex_blk" => fn -> FnXML.FastExBlkParser.parse(@medium) end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_streaming do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("STREAMING PARSER BENCHMARKS")
    IO.puts("Chunked input simulation")
    IO.puts(String.duplicate("=", 70) <> "\n")

    print_file_info()
    print_parser_info()

    medium_chunks = chunk_string(@medium, 4096)
    large_chunks = chunk_string(@large, 4096)

    IO.puts("\n--- MEDIUM FILE STREAMING (#{length(medium_chunks)} x 4KB chunks) ---\n")

    Benchee.run(
      %{
        # FnXML MacroBlkParser - Edition 5
        "compliant_ed5" => fn -> medium_chunks |> Bench.CompliantEd5.stream() |> Stream.run() end,
        "fast_ed5" => fn -> medium_chunks |> Bench.FastEd5.stream() |> Stream.run() end,
        "minimal_ed5" => fn -> medium_chunks |> Bench.MinimalEd5.stream() |> Stream.run() end,

        # FnXML MacroBlkParser - Edition 4
        "compliant_ed4" => fn -> medium_chunks |> Bench.CompliantEd4.stream() |> Stream.run() end,
        "fast_ed4" => fn -> medium_chunks |> Bench.FastEd4.stream() |> Stream.run() end,
        "minimal_ed4" => fn -> medium_chunks |> Bench.MinimalEd4.stream() |> Stream.run() end,

        # FnXML legacy parsers
        "ex_blk_parser" => fn -> medium_chunks |> FnXML.ExBlkParser.stream() |> Stream.run() end,
        "fast_ex_blk" => fn -> medium_chunks |> FnXML.FastExBlkParser.stream() |> Stream.run() end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )

    IO.puts("\n--- LARGE FILE STREAMING (#{length(large_chunks)} x 4KB chunks) ---\n")

    Benchee.run(
      %{
        # FnXML MacroBlkParser - Edition 5
        "compliant_ed5" => fn -> large_chunks |> Bench.CompliantEd5.stream() |> Stream.run() end,
        "fast_ed5" => fn -> large_chunks |> Bench.FastEd5.stream() |> Stream.run() end,
        "minimal_ed5" => fn -> large_chunks |> Bench.MinimalEd5.stream() |> Stream.run() end,

        # FnXML MacroBlkParser - Edition 4
        "compliant_ed4" => fn -> large_chunks |> Bench.CompliantEd4.stream() |> Stream.run() end,
        "fast_ed4" => fn -> large_chunks |> Bench.FastEd4.stream() |> Stream.run() end,
        "minimal_ed4" => fn -> large_chunks |> Bench.MinimalEd4.stream() |> Stream.run() end,

        # FnXML legacy parsers
        "ex_blk_parser" => fn -> large_chunks |> FnXML.ExBlkParser.stream() |> Stream.run() end,
        "fast_ex_blk" => fn -> large_chunks |> FnXML.FastExBlkParser.stream() |> Stream.run() end
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

    print_file_info()
    print_parser_info()

    IO.puts("\n--- SMALL FILE (#{byte_size(@small)} bytes) ---\n")

    Benchee.run(
      %{
        "saxy" => fn -> Saxy.parse_string(@small, NullHandler, nil) end,
        "erlsom" => fn -> :erlsom.simple_form(@small) end,
        "xmerl" => fn -> :xmerl_scan.string(String.to_charlist(@small)) end,
        "compliant_ed5" => fn -> Bench.CompliantEd5.parse(@small) end,
        "fast_ed5" => fn -> Bench.FastEd5.parse(@small) end,
        "minimal_ed5" => fn -> Bench.MinimalEd5.parse(@small) end,
        "compliant_ed4" => fn -> Bench.CompliantEd4.parse(@small) end,
        "fast_ed4" => fn -> Bench.FastEd4.parse(@small) end,
        "minimal_ed4" => fn -> Bench.MinimalEd4.parse(@small) end,
        "ex_blk_parser" => fn -> FnXML.ExBlkParser.parse(@small) end,
        "fast_ex_blk" => fn -> FnXML.FastExBlkParser.parse(@small) end
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
        "compliant_ed5" => fn -> Bench.CompliantEd5.parse(@medium) end,
        "fast_ed5" => fn -> Bench.FastEd5.parse(@medium) end,
        "minimal_ed5" => fn -> Bench.MinimalEd5.parse(@medium) end,
        "compliant_ed4" => fn -> Bench.CompliantEd4.parse(@medium) end,
        "fast_ed4" => fn -> Bench.FastEd4.parse(@medium) end,
        "minimal_ed4" => fn -> Bench.MinimalEd4.parse(@medium) end,
        "ex_blk_parser" => fn -> FnXML.ExBlkParser.parse(@medium) end,
        "fast_ex_blk" => fn -> FnXML.FastExBlkParser.parse(@medium) end
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
        "compliant_ed5" => fn -> Bench.CompliantEd5.parse(@large) end,
        "fast_ed5" => fn -> Bench.FastEd5.parse(@large) end,
        "minimal_ed5" => fn -> Bench.MinimalEd5.parse(@large) end,
        "compliant_ed4" => fn -> Bench.CompliantEd4.parse(@large) end,
        "fast_ed4" => fn -> Bench.FastEd4.parse(@large) end,
        "minimal_ed4" => fn -> Bench.MinimalEd4.parse(@large) end,
        "ex_blk_parser" => fn -> FnXML.ExBlkParser.parse(@large) end,
        "fast_ex_blk" => fn -> FnXML.FastExBlkParser.parse(@large) end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_fnxml_only do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("FNXML PARSER COMPARISON")
    IO.puts("MacroBlkParser configurations only")
    IO.puts(String.duplicate("=", 70) <> "\n")

    print_file_info()

    IO.puts("\nParser configurations:")
    IO.puts("  compliant - All features (position, whitespace, all events)")
    IO.puts("  fast      - No position, no whitespace events")
    IO.puts("  minimal   - Only elements and text content")
    IO.puts("  _ed5      - Edition 5 (permissive Unicode)")
    IO.puts("  _ed4      - Edition 4 (strict character validation)")
    IO.puts("")

    IO.puts("\n--- MEDIUM FILE ---\n")

    Benchee.run(
      %{
        # Edition 5
        "compliant_ed5" => fn -> Bench.CompliantEd5.parse(@medium) end,
        "fast_ed5" => fn -> Bench.FastEd5.parse(@medium) end,
        "minimal_ed5" => fn -> Bench.MinimalEd5.parse(@medium) end,
        # Edition 4
        "compliant_ed4" => fn -> Bench.CompliantEd4.parse(@medium) end,
        "fast_ed4" => fn -> Bench.FastEd4.parse(@medium) end,
        "minimal_ed4" => fn -> Bench.MinimalEd4.parse(@medium) end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end

  defp print_file_info do
    IO.puts("File sizes:")
    IO.puts("  small.xml:  #{byte_size(@small)} bytes")
    IO.puts("  medium.xml: #{byte_size(@medium)} bytes")
    IO.puts("  large.xml:  #{byte_size(@large)} bytes")
  end

  defp print_parser_info do
    IO.puts("")
    IO.puts("Parsers compared:")
    IO.puts("  External:")
    IO.puts("    - saxy:           Highly optimized SAX parser")
    IO.puts("    - erlsom:         Erlang XML library")
    IO.puts("    - xmerl:          Erlang stdlib DOM parser")
    IO.puts("  FnXML MacroBlkParser - Edition 5 (permissive Unicode):")
    IO.puts("    - compliant_ed5:  All features enabled (position, whitespace, all events)")
    IO.puts("    - fast_ed5:       No position tracking, no whitespace events")
    IO.puts("    - minimal_ed5:    Only elements and text (maximum performance)")
    IO.puts("  FnXML MacroBlkParser - Edition 4 (strict character validation):")
    IO.puts("    - compliant_ed4:  All features enabled (position, whitespace, all events)")
    IO.puts("    - fast_ed4:       No position tracking, no whitespace events")
    IO.puts("    - minimal_ed4:    Only elements and text (maximum performance)")
    IO.puts("  FnXML Legacy:")
    IO.puts("    - ex_blk_parser:  ExBlkParser")
    IO.puts("    - fast_ex_blk:    FastExBlkParser")
  end

  defp chunk_string(string, chunk_size) do
    string
    |> :binary.bin_to_list()
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(&:binary.list_to_bin/1)
  end
end

case System.argv() do
  ["--by-size"] -> AllParsersBench.run_by_size()
  ["--streaming"] -> AllParsersBench.run_streaming()
  ["--fnxml"] -> AllParsersBench.run_fnxml_only()
  ["--help"] ->
    IO.puts("""
    Comprehensive Parser Benchmarks

    Usage: mix run bench/all_parsers_bench.exs [option]

    Options:
      (none)       Run benchmark with medium file (all parsers)
      --by-size    Run benchmarks with small, medium, and large files
      --streaming  Run streaming benchmarks with chunked input
      --fnxml      Run FnXML parsers only (macro configurations)
      --help       Show this help message
    """)
  _ -> AllParsersBench.run()
end
