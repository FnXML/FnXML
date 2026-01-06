# Parse Benchmarks
# Run with: mix run benchmarks/parse_bench.exs
#
# Compares FnXML parsing performance against Saxy and :xmerl

defmodule NullHandler do
  @moduledoc "Minimal Saxy handler for fair comparison"
  @behaviour Saxy.Handler

  @impl true
  def handle_event(:start_document, _prolog, state), do: {:ok, state}

  @impl true
  def handle_event(:end_document, _data, state), do: {:ok, state}

  @impl true
  def handle_event(:start_element, {_name, _attrs}, state), do: {:ok, state}

  @impl true
  def handle_event(:end_element, _name, state), do: {:ok, state}

  @impl true
  def handle_event(:characters, _chars, state), do: {:ok, state}

  @impl true
  def handle_event(:cdata, _cdata, state), do: {:ok, state}

  @impl true
  def handle_event(:comment, _comment, state), do: {:ok, state}
end

defmodule CountHandler do
  @moduledoc "Saxy handler that counts elements"
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

defmodule ParseBench do
  @small File.read!("benchmarks/data/small.xml")
  @medium File.read!("benchmarks/data/medium.xml")
  @large File.read!("benchmarks/data/large.xml")

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("PARSE BENCHMARKS")
    IO.puts("Comparing: FnXML vs Saxy vs :xmerl")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File sizes:")
    IO.puts("  small.xml:  #{byte_size(@small)} bytes")
    IO.puts("  medium.xml: #{byte_size(@medium)} bytes")
    IO.puts("  large.xml:  #{byte_size(@large)} bytes")
    IO.puts("")

    Benchee.run(
      %{
        # Small file benchmarks
        "fnxml_small" => fn ->
          FnXML.Parser.parse(@small) |> Stream.run()
        end,
        "saxy_small" => fn ->
          Saxy.parse_string(@small, NullHandler, nil)
        end,
        "xmerl_small" => fn ->
          :xmerl_scan.string(String.to_charlist(@small))
        end,
        "erlsom_small" => fn ->
          :erlsom.simple_form(@small)
        end,

        # Medium file benchmarks
        "fnxml_medium" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,
        "saxy_medium" => fn ->
          Saxy.parse_string(@medium, NullHandler, nil)
        end,
        "xmerl_medium" => fn ->
          :xmerl_scan.string(String.to_charlist(@medium))
        end,
        "erlsom_medium" => fn ->
          :erlsom.simple_form(@medium)
        end,

        # Large file benchmarks
        "fnxml_large" => fn ->
          FnXML.Parser.parse(@large) |> Stream.run()
        end,
        "saxy_large" => fn ->
          Saxy.parse_string(@large, NullHandler, nil)
        end,
        "xmerl_large" => fn ->
          :xmerl_scan.string(String.to_charlist(@large))
        end,
        "erlsom_large" => fn ->
          :erlsom.simple_form(@large)
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
    IO.puts("QUICK PARSE BENCHMARKS (medium file only)")
    IO.puts("Comparing: FnXML vs Saxy vs xmerl vs erlsom")
    IO.puts(String.duplicate("=", 70) <> "\n")

    Benchee.run(
      %{
        "fnxml" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,
        "saxy" => fn ->
          Saxy.parse_string(@medium, NullHandler, nil)
        end,
        "xmerl" => fn ->
          :xmerl_scan.string(String.to_charlist(@medium))
        end,
        "erlsom" => fn ->
          :erlsom.simple_form(@medium)
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
end

# Run full benchmarks by default, or quick with --quick flag
if "--quick" in System.argv() do
  ParseBench.run_quick()
else
  ParseBench.run()
end
