# Streaming vs Non-Streaming Parser Benchmarks
# Run with: mix run bench/streaming_bench.exs
#
# Compares Saxy, FnXML Elixir, and FnXML Zig NIF parsers
# in both streaming and non-streaming modes

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

defmodule FnXMLSaxHandler do
  use FnXML.SAX.Handler

  @impl true
  def start_element(_uri, _local, _qname, _attrs, state), do: {:ok, state}
  @impl true
  def end_element(_uri, _local, _qname, state), do: {:ok, state}
  @impl true
  def characters(_chars, state), do: {:ok, state}
end

defmodule StreamingBench do
  @small_file "bench/data/small.xml"
  @medium_file "bench/data/medium.xml"
  @large_file "bench/data/large.xml"

  @chunk_size 64 * 1024  # 64KB chunks

  def run do
    small = File.read!(@small_file)
    medium = File.read!(@medium_file)
    large = File.read!(@large_file)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("STREAMING vs NON-STREAMING PARSER BENCHMARKS")
    IO.puts("Saxy vs FnXML Elixir vs FnXML Zig NIF")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File sizes:")
    IO.puts("  small.xml:  #{byte_size(small)} bytes")
    IO.puts("  medium.xml: #{byte_size(medium)} bytes")
    IO.puts("  large.xml:  #{byte_size(large)} bytes")
    IO.puts("")
    IO.puts("Chunk size: #{@chunk_size} bytes (64KB)")
    IO.puts("")

    IO.puts("Parsers:")
    IO.puts("  saxy           - Saxy.parse_string (non-streaming)")
    IO.puts("  saxy_stream    - Saxy.parse_stream (streaming)")
    IO.puts("  fnxml_elixir   - FnXML.Parser.parse (non-streaming)")
    IO.puts("  fnxml_zig      - FnXML.NifParser.parse (non-streaming)")
    IO.puts("  fnxml_zig_stream - FnXML.NifParser.stream (streaming)")
    IO.puts("")
    IO.puts("Note: FnXML Elixir parser doesn't support chunk-based streaming.")
    IO.puts("")

    # Warm up Zig NIF
    _ = FnXML.NifParser.parse("<root/>", nil, 0, {1, 0, 0})

    run_benchmark("MEDIUM FILE", medium, @medium_file)
    run_benchmark("LARGE FILE", large, @large_file)
  end

  def run_quick do
    medium = File.read!(@medium_file)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("QUICK STREAMING BENCHMARK (medium file)")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: medium.xml (#{byte_size(medium)} bytes)")
    IO.puts("Chunk size: #{@chunk_size} bytes")
    IO.puts("")

    # Warm up
    _ = FnXML.NifParser.parse("<root/>", nil, 0, {1, 0, 0})

    run_benchmark("MEDIUM FILE", medium, @medium_file)
  end

  defp run_benchmark(label, content, file_path) do
    IO.puts("\n--- #{label} (#{byte_size(content)} bytes) ---\n")

    # Pre-create chunks for fair comparison
    chunks = chunk_binary(content, @chunk_size)

    Benchee.run(
      %{
        # Saxy parsers
        "saxy" => fn ->
          Saxy.parse_string(content, NullHandler, nil)
        end,
        "saxy_stream" => fn ->
          File.stream!(file_path, @chunk_size)
          |> Saxy.parse_stream(NullHandler, nil)
        end,

        # FnXML Elixir parser (non-streaming only)
        "fnxml_elixir" => fn ->
          FnXML.Parser.parse(content) |> Stream.run()
        end,

        # FnXML Zig NIF parser
        "fnxml_zig" => fn ->
          {events, _, _} = FnXML.NifParser.parse(content, nil, 0, {1, 0, 0})
          length(events)  # Force evaluation
        end,
        "fnxml_zig_stream" => fn ->
          FnXML.NifParser.stream(chunks)
          |> Enum.count()
        end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end

  defp chunk_binary(binary, chunk_size) do
    chunk_binary(binary, chunk_size, [])
  end

  defp chunk_binary(<<>>, _chunk_size, acc) do
    Enum.reverse(acc)
  end

  defp chunk_binary(binary, chunk_size, acc) when byte_size(binary) <= chunk_size do
    Enum.reverse([binary | acc])
  end

  defp chunk_binary(binary, chunk_size, acc) do
    <<chunk::binary-size(chunk_size), rest::binary>> = binary
    chunk_binary(rest, chunk_size, [chunk | acc])
  end

  def run_by_chunk_size do
    large = File.read!(@large_file)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("STREAMING BENCHMARK BY CHUNK SIZE")
    IO.puts("FnXML Zig NIF streaming with different chunk sizes")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: large.xml (#{byte_size(large)} bytes)")
    IO.puts("")

    # Warm up
    _ = FnXML.NifParser.parse("<root/>", nil, 0, {1, 0, 0})

    chunk_sizes = [4 * 1024, 64 * 1024, 1024 * 1024, 2 * 1024 * 1024]

    # Zig streaming benchmarks
    zig_benchmarks =
      chunk_sizes
      |> Enum.map(fn size ->
        chunks = chunk_binary(large, size)
        label = if size < 1024, do: "zig_#{size}b", else: "zig_#{div(size, 1024)}kb"
        {label, fn ->
          FnXML.NifParser.stream(chunks) |> Enum.count()
        end}
      end)
      |> Map.new()

    # Saxy streaming benchmarks
    saxy_benchmarks =
      chunk_sizes
      |> Enum.map(fn size ->
        chunks = chunk_binary(large, size)
        label = if size < 1024, do: "saxy_#{size}b", else: "saxy_#{div(size, 1024)}kb"
        {label, fn ->
          Saxy.parse_stream(chunks, NullHandler, nil)
        end}
      end)
      |> Map.new()

    benchmarks = Map.merge(zig_benchmarks, saxy_benchmarks)

    # Add non-streaming baselines
    benchmarks = Map.put(benchmarks, "zig_full", fn ->
      {events, _, _} = FnXML.NifParser.parse(large, nil, 0, {1, 0, 0})
      length(events)
    end)

    benchmarks = Map.put(benchmarks, "saxy_full", fn ->
      Saxy.parse_string(large, NullHandler, nil)
    end)

    Benchee.run(
      benchmarks,
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_comparison do
    large = File.read!(@large_file)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("DIRECT PARSER COMPARISON (large file)")
    IO.puts("Non-streaming only - raw parsing speed")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: large.xml (#{byte_size(large)} bytes)")
    IO.puts("")

    # Warm up
    _ = FnXML.NifParser.parse("<root/>", nil, 0, {1, 0, 0})

    Benchee.run(
      %{
        "saxy" => fn ->
          Saxy.parse_string(large, NullHandler, nil)
        end,
        "fnxml_elixir" => fn ->
          FnXML.Parser.parse(large) |> Stream.run()
        end,
        "fnxml_sax" => fn ->
          FnXML.SAX.parse(large, FnXMLSaxHandler, nil, namespaces: false)
        end,
        "fnxml_zig" => fn ->
          {events, _, _} = FnXML.NifParser.parse(large, nil, 0, {1, 0, 0})
          length(events)
        end
      },
      warmup: 2,
      time: 5,
      memory_time: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end
end

case System.argv() do
  ["--quick"] -> StreamingBench.run_quick()
  ["--chunks"] -> StreamingBench.run_by_chunk_size()
  ["--compare"] -> StreamingBench.run_comparison()
  _ -> StreamingBench.run()
end
