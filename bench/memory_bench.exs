# Memory Benchmarks
# Run with: mix run bench/memory_bench.exs
#
# Compares memory usage patterns between parsers

defmodule CountHandler do
  @behaviour Saxy.Handler

  @impl true
  def handle_event(:start_document, _prolog, state), do: {:ok, state}
  @impl true
  def handle_event(:end_document, _data, state), do: {:ok, state}
  @impl true
  def handle_event(:start_element, _data, count), do: {:ok, count + 1}
  @impl true
  def handle_event(:end_element, _name, state), do: {:ok, state}
  @impl true
  def handle_event(:characters, _chars, state), do: {:ok, state}
  @impl true
  def handle_event(:cdata, _cdata, state), do: {:ok, state}
  @impl true
  def handle_event(:comment, _comment, state), do: {:ok, state}
end

defmodule MemoryBench do
  @large File.read!("bench/data/large.xml")

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("MEMORY BENCHMARKS")
    IO.puts("Comparing memory usage: streaming vs full parse")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: large.xml (#{byte_size(@large)} bytes)")
    IO.puts("")

    Benchee.run(
      %{
        # FnXML streaming - count only (minimal memory)
        "fnxml_stream_count" => fn ->
          FnXML.Parser.parse(@large)
          |> Enum.count()
        end,

        # FnXML streaming - to list (holds all tokens)
        "fnxml_stream_to_list" => fn ->
          FnXML.Parser.parse(@large)
          |> Enum.to_list()
        end,

        # Saxy SAX parsing - count only
        "saxy_count" => fn ->
          {:ok, count} = Saxy.parse_string(@large, CountHandler, 0)
          count
        end,

        # xmerl full DOM parse
        "xmerl_full" => fn ->
          :xmerl_scan.string(String.to_charlist(@large))
        end,

        # erlsom simple form
        "erlsom_simple" => fn ->
          :erlsom.simple_form(@large)
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 3,
      reduction_time: 1,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end

  def run_streaming_comparison do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("STREAMING VS ACCUMULATING")
    IO.puts("Shows benefit of streaming for large data")
    IO.puts(String.duplicate("=", 70) <> "\n")

    Benchee.run(
      %{
        # Just count - constant memory regardless of size
        "fnxml_count_only" => fn ->
          FnXML.Parser.parse(@large) |> Enum.count()
        end,

        # Filter then count - still streaming
        "fnxml_filter_count" => fn ->
          FnXML.Parser.parse(@large)
          |> Stream.filter(&match?({:open, _}, &1))
          |> Enum.count()
        end,

        # Take first N - stops early
        "fnxml_take_100" => fn ->
          FnXML.Parser.parse(@large)
          |> Enum.take(100)
        end,

        # Full accumulation - memory proportional to size
        "fnxml_to_list" => fn ->
          FnXML.Parser.parse(@large) |> Enum.to_list()
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 3,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end
end

if "--streaming" in System.argv() do
  MemoryBench.run_streaming_comparison()
else
  MemoryBench.run()
end
