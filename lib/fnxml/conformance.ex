defmodule FnXML.Conformance do
  @moduledoc """
  XML Conformance Testing against W3C/OASIS Test Suite.

  Implements `FnConformance.Runner` and `FnConformance.Reportable` behaviours
  to integrate with the fnconformance framework.

  The XML Conformance Test Suite contains ~2,000 tests organized by:

  - **Valid documents**: Must be accepted by validating and non-validating parsers
  - **Invalid documents**: Well-formed but violate validity constraints (DTD)
  - **Not well-formed documents**: Must be rejected by all conforming parsers
  - **Error documents**: May be rejected or accepted with error recovery

  ## Running Tests

      FnXML.Conformance.run()
      FnXML.Conformance.run(filter: "ibm")
      FnXML.Conformance.run(verbose: true)
  """

  @behaviour FnConformance.Runner
  @behaviour FnConformance.Reportable

  alias FnXML.Conformance.{Catalog, TestSuite}

  @impl FnConformance.Runner
  def component_name, do: :xml

  @impl FnConformance.Runner
  def run(opts \\ []) do
    IO.puts("XML 1.0 Conformance Tests")
    IO.puts(String.duplicate("=", 50))

    suite_path = find_suite_path()

    unless File.dir?(suite_path) do
      IO.puts("\nTest suite not found at: #{suite_path}")
      IO.puts("Run `mix conformance.xml --download` to download the test suite.")
      []
    else
      tests = Catalog.load(suite_path, opts)
      IO.puts("Loaded #{length(tests)} tests\n")

      results = run_all(tests, opts)
      print_summary(results)
      results
    end
  end

  @impl FnConformance.Reportable
  def version do
    Application.spec(:fnxml, :vsn) |> to_string()
  end

  @impl FnConformance.Reportable
  def summarize(results) do
    FnConformance.ResultsSummary.basic_summary(results)
  end

  @doc """
  Run a single test by ID.
  """
  def run_test(test_id, opts \\ []) do
    suite_path = find_suite_path()
    tests = Catalog.load(suite_path, opts)

    case Enum.find(tests, &(&1.id == test_id)) do
      nil ->
        IO.puts("Test not found: #{test_id}")
        {:error, :not_found}

      test ->
        execute_test(test, Keyword.put(opts, :verbose, true))
    end
  end

  @doc """
  List available test collections.
  """
  def list_collections(opts \\ []) do
    suite_path = find_suite_path()
    Catalog.list_collections(suite_path, opts)
  end

  @doc """
  Quick check - run only valid/invalid tests.
  """
  def quick(opts \\ []) do
    suite_path = find_suite_path()

    tests =
      Catalog.load(suite_path, opts)
      |> Enum.filter(&(&1.type in [:valid, :invalid]))

    IO.puts("Quick check: #{length(tests)} valid/invalid tests\n")

    results = run_all(tests, opts)
    print_summary(results)
    results
  end

  # Find the test suite, checking local first then fnconformance fallback
  defp find_suite_path do
    local = TestSuite.suite_path()

    cond do
      File.dir?(local) -> local
      File.dir?("../fnconformance/priv/test_suites/xmlconf") -> "../fnconformance/priv/test_suites/xmlconf"
      true -> local
    end
  end

  # Run all tests sequentially with progress reporting
  defp run_all(tests, opts) do
    verbose = Keyword.get(opts, :verbose, false)
    total = length(tests)

    results =
      tests
      |> Enum.with_index(1)
      |> Enum.map(fn {test, idx} ->
        if verbose do
          IO.write("\r[#{idx}/#{total}] #{test.id}...")
        else
          if rem(idx, 100) == 0, do: IO.write("\r#{idx}/#{total} tests...")
        end

        execute_test(test, opts)
      end)

    IO.puts("\r#{total} tests completed.#{String.duplicate(" ", 20)}")
    results
  end

  # Execute a single test and return a Result struct
  defp execute_test(%Catalog{} = test, opts) do
    file_path = Path.join(test.base_path, test.uri)
    start = System.monotonic_time(:microsecond)

    result =
      case File.read(file_path) do
        {:ok, content} ->
          run_xml_test(test, content, start)

        {:error, reason} ->
          FnConformance.Result.skip(test.id, {:file_error, reason},
            group: to_string(test.type),
            elapsed_us: elapsed(start)
          )
      end

    if Keyword.get(opts, :verbose, false), do: print_result(result)
    result
  end

  defp run_xml_test(test, content, start) do
    # Preprocessing
    content = maybe_convert_utf16(content)
    content = maybe_convert_iso8859(content)
    content = FnXML.Preprocess.Normalize.line_endings(content)

    # Parse with timeout
    timeout_ms = 5000

    task =
      Task.async(fn ->
        try do
          FnXML.Parser.parse(content) |> Enum.to_list()
        rescue
          e -> {:exception, e}
        end
      end)

    events =
      case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        nil -> {:timeout, timeout_ms}
      end

    {status, details} = evaluate_result(test.type, events)
    group = to_string(test.type)

    case status do
      :pass ->
        FnConformance.Result.pass(test.id,
          group: group,
          elapsed_us: elapsed(start),
          details: details
        )

      :fail ->
        FnConformance.Result.fail(test.id, details,
          group: group,
          elapsed_us: elapsed(start)
        )

      :skip ->
        FnConformance.Result.skip(test.id, details,
          group: group,
          elapsed_us: elapsed(start)
        )
    end
  end

  # Evaluate test result based on expected type
  defp evaluate_result(_expected_type, {:timeout, ms}) do
    {:fail, {:timeout, ms}}
  end

  defp evaluate_result(:error, {:exception, _e}) do
    {:pass, :error_handling_exception}
  end

  defp evaluate_result(_expected_type, {:exception, e}) do
    {:fail, {:exception, Exception.message(e)}}
  end

  defp evaluate_result(expected_type, events) when is_list(events) do
    has_errors =
      Enum.any?(events, fn
        {:error, _, _, _, _, _} -> true
        _ -> false
      end)

    case {expected_type, has_errors} do
      {:valid, false} -> {:pass, :parsed_ok}
      {:valid, true} -> {:fail, :unexpected_error}
      {:invalid, false} -> {:pass, :parsed_ok}
      {:invalid, true} -> {:fail, :unexpected_error}
      {:not_wf, true} -> {:pass, :correctly_rejected}
      {:not_wf, false} -> {:fail, :should_have_error}
      {:error, _} -> {:pass, :error_handling}
      {type, _} -> {:skip, {:unknown_type, type}}
    end
  end

  # UTF-16 conversion
  defp maybe_convert_utf16(<<0xFE, 0xFF, _rest::binary>> = content) do
    try do
      FnXML.Preprocess.Utf16.to_utf8(content)
    rescue
      _ -> content
    end
  end

  defp maybe_convert_utf16(<<0xFF, 0xFE, _rest::binary>> = content) do
    try do
      FnXML.Preprocess.Utf16.to_utf8(content)
    rescue
      _ -> content
    end
  end

  defp maybe_convert_utf16(content), do: content

  # ISO-8859-1 conversion
  defp maybe_convert_iso8859(content) do
    if has_iso8859_encoding?(content) do
      iso8859_to_utf8(content)
    else
      content
    end
  end

  defp has_iso8859_encoding?(content) do
    ascii_prefix =
      content
      |> :binary.bin_to_list()
      |> Enum.take(200)
      |> Enum.take_while(fn b -> b < 128 end)
      |> :binary.list_to_bin()
      |> String.downcase()

    String.contains?(ascii_prefix, "encoding") and
      (String.contains?(ascii_prefix, "iso-8859-1") or
         String.contains?(ascii_prefix, "iso_8859_1") or
         String.contains?(ascii_prefix, "latin-1") or
         String.contains?(ascii_prefix, "latin1"))
  end

  defp iso8859_to_utf8(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn byte ->
      cond do
        byte == 0x85 -> <<?\n>>
        byte < 0x80 -> <<byte>>
        byte < 0xC0 -> <<0xC2, byte>>
        true -> <<0xC3, byte - 0x40>>
      end
    end)
    |> IO.iodata_to_binary()
  end

  defp elapsed(start), do: System.monotonic_time(:microsecond) - start

  defp print_result(%FnConformance.Result{status: :pass, name: name}) do
    IO.puts("  PASS: #{name}")
  end

  defp print_result(%FnConformance.Result{status: :fail, name: name, details: details}) do
    IO.puts("  FAIL: #{name} - #{inspect(details)}")
  end

  defp print_result(%FnConformance.Result{status: :skip, name: name, details: reason}) do
    IO.puts("  SKIP: #{name} - #{inspect(reason)}")
  end

  defp print_summary(results) do
    summary = summarize(results)

    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("Results Summary")
    IO.puts(String.duplicate("-", 50))
    IO.puts("  Passed:  #{summary.pass}")
    IO.puts("  Failed:  #{summary.fail}")
    IO.puts("  Skipped: #{summary.skip}")
    IO.puts("  Total:   #{summary.total}")
    IO.puts("  Pass Rate: #{summary.pass_rate}%")
    IO.puts(String.duplicate("-", 50))

    if summary.by_group != [] do
      IO.puts("\nBy Test Type:")

      Enum.each(summary.by_group, fn {type, %{pass: p, total: t}} ->
        pct = if t > 0, do: Float.round(p / t * 100, 1), else: 0
        IO.puts("  #{type}: #{p}/#{t} (#{pct}%)")
      end)
    end

    summary
  end
end
