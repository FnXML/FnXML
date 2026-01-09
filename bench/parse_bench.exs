# Parse Benchmarks
# Run with: mix run bench/parse_bench.exs
#           mix run bench/parse_bench.exs --quick
#
# Compares FnXML parsing performance against Saxy, erlsom, and xmerl

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

defmodule ParseBench do
  @small_path "bench/data/small.xml"
  @medium_path "bench/data/medium.xml"
  @large_path "bench/data/large.xml"

  @small File.read!(@small_path)
  @medium File.read!(@medium_path)
  @large File.read!(@large_path)

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("PARSE BENCHMARKS")
    IO.puts("Comparing: FnXML (string & stream) vs Saxy (string & stream) vs others")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File sizes:")
    IO.puts("  small.xml:  #{byte_size(@small)} bytes")
    IO.puts("  medium.xml: #{byte_size(@medium)} bytes")
    IO.puts("  large.xml:  #{byte_size(@large)} bytes")
    IO.puts("")

    Benchee.run(
      %{
        # FnXML - string mode (binary input)
        "fnxml_string" => fn {xml, _path} ->
          FnXML.Parser.parse(xml) |> Stream.run()
        end,

        # FnXML - stream mode (file stream input)
        "fnxml_stream" => fn {_xml, path} ->
          File.stream!(path, [], 65536)
          |> FnXML.ParserStream.parse(mode: :lazy)
          |> Stream.run()
        end,

        # Saxy - string mode
        "saxy_string" => fn {xml, _path} ->
          Saxy.parse_string(xml, NullHandler, nil)
        end,

        # Saxy - stream mode
        "saxy_stream" => fn {_xml, path} ->
          File.stream!(path, [], 65536)
          |> Saxy.parse_stream(NullHandler, nil)
        end,

        # erlsom
        "erlsom" => fn {xml, _path} ->
          :erlsom.simple_form(xml)
        end,

        # xmerl
        "xmerl" => fn {xml, _path} ->
          :xmerl_scan.string(String.to_charlist(xml))
        end
      },
      inputs: %{
        "small" => {@small, @small_path},
        "medium" => {@medium, @medium_path},
        "large" => {@large, @large_path}
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
    IO.puts("Comparing: FnXML (string & stream) vs Saxy (string & stream) vs others")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: medium.xml (#{byte_size(@medium)} bytes)\n")

    Benchee.run(
      %{
        "fnxml_string" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,
        "fnxml_stream" => fn ->
          File.stream!(@medium_path, [], 65536)
          |> FnXML.ParserStream.parse(mode: :lazy)
          |> Stream.run()
        end,
        "saxy_string" => fn ->
          Saxy.parse_string(@medium, NullHandler, nil)
        end,
        "saxy_stream" => fn ->
          File.stream!(@medium_path, [], 65536)
          |> Saxy.parse_stream(NullHandler, nil)
        end,
        "erlsom" => fn ->
          :erlsom.simple_form(@medium)
        end,
        "xmerl" => fn ->
          :xmerl_scan.string(String.to_charlist(@medium))
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
