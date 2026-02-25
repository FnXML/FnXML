defmodule FnXML.Conformance.Namespaces do
  @moduledoc """
  XML Namespaces 1.0/1.1 Conformance Testing against W3C Test Suite.

  The XML Namespaces Test Suite (Edinburgh) contains ~64 tests organized by:

  - **NS 1.0**: Namespaces in XML 1.0 tests (48 tests)
  - **NS 1.1**: Namespaces in XML 1.1 tests (8 tests)
  - **Errata**: First Edition errata tests (8 tests)

  ## Running Tests

      FnXML.Conformance.Namespaces.run()
      FnXML.Conformance.Namespaces.run(version: "1.0")
      FnXML.Conformance.Namespaces.run(verbose: true)
  """

  alias FnXML.Conformance.Namespaces.Catalog

  @doc """
  Run namespace conformance tests and return results.
  """
  def run(opts \\ []) do
    IO.puts("XML Namespaces Conformance Tests")
    IO.puts(String.duplicate("=", 50))

    suite_path = namespace_test_path()

    unless File.dir?(suite_path) do
      IO.puts("\nTest suite not found at: #{suite_path}")
      IO.puts("Run `mix conformance.xml --download` to download the test suite first.")
      []
    else
      tests = Catalog.load(suite_path, opts)
      IO.puts("Loaded #{length(tests)} tests\n")

      results = run_all(tests, opts)
      print_summary(results)
      results
    end
  end

  @doc """
  Run a single test by ID.
  """
  def run_test(test_id, opts \\ []) do
    tests = Catalog.load(namespace_test_path(), opts)

    case Enum.find(tests, &(&1.id == test_id)) do
      nil ->
        IO.puts("Test not found: #{test_id}")
        {:error, :not_found}

      test ->
        execute_test(test, Keyword.put(opts, :verbose, true))
    end
  end

  @doc """
  List all namespace tests.
  """
  def list_tests(opts \\ []) do
    tests = Catalog.load(namespace_test_path(), opts)

    tests
    |> Enum.group_by(& &1.recommendation)
    |> Enum.each(fn {rec, rec_tests} ->
      IO.puts("\n#{rec} (#{length(rec_tests)} tests):")

      Enum.each(rec_tests, fn t ->
        IO.puts("  #{t.id}: #{t.type}")
      end)
    end)

    tests
  end

  defp namespace_test_path do
    base = FnXML.Conformance.TestSuite.suite_path()
    local = Path.join(base, "eduni/namespaces")

    if File.dir?(local) do
      local
    else
      # Fallback to fnconformance location
      fallback = "../fnconformance/priv/test_suites/xmlconf/eduni/namespaces"
      if File.dir?(fallback), do: fallback, else: local
    end
  end

  defp run_all(tests, opts) do
    verbose = Keyword.get(opts, :verbose, false)
    total = length(tests)

    results =
      tests
      |> Enum.with_index(1)
      |> Enum.map(fn {test, idx} ->
        if verbose do
          IO.write("\r[#{idx}/#{total}] #{test.id}...")
        end

        execute_test(test, opts)
      end)

    IO.puts("\r#{total} tests completed.#{String.duplicate(" ", 20)}")
    results
  end

  defp execute_test(%Catalog{} = test, opts) do
    file_path = Path.join(test.base_path, test.uri)
    start = System.monotonic_time(:microsecond)

    result =
      case File.read(file_path) do
        {:ok, content} ->
          run_namespace_test(test, content, start)

        {:error, reason} ->
          FnConformance.Result.skip(test.id, {:file_error, reason},
            group: "ns-#{test.type}",
            elapsed_us: elapsed(start)
          )
      end

    if Keyword.get(opts, :verbose, false), do: print_result(result)
    result
  end

  defp run_namespace_test(test, content, start) do
    events =
      try do
        # Parse and collect events
        parsed_events = FnXML.Parser.parse(content) |> Enum.to_list()

        # Build processing pipeline with namespace validation
        parsed_events
        |> FnXML.Namespaces.validate()
        |> Enum.to_list()
      rescue
        e -> {:exception, e}
      end

    {status, details} = evaluate_result(test.type, events)
    group = "ns-#{test.type}"

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

  defp evaluate_result(_type, {:exception, e}) do
    {:fail, {:exception, Exception.message(e)}}
  end

  defp evaluate_result(expected_type, events) when is_list(events) do
    has_xml_errors =
      Enum.any?(events, fn
        {:error, _, _, _, _, _} -> true
        {:error, %FnXML.Error{}} -> true
        {:error, _} -> true
        _ -> false
      end)

    has_ns_errors =
      Enum.any?(events, fn
        {:ns_error, _, _, _} -> true
        {:dtd_error, _, _, _} -> true
        _ -> false
      end)

    has_errors = has_xml_errors or has_ns_errors

    case {expected_type, has_errors} do
      {:valid, false} -> {:pass, :parsed_ok}
      {:valid, true} -> {:fail, :unexpected_error}
      {:invalid, false} -> {:pass, :parsed_ok}
      {:invalid, true} when has_xml_errors -> {:fail, :unexpected_xml_error}
      {:invalid, true} -> {:pass, :correctly_invalid}
      {:not_wf, true} -> {:pass, :correctly_rejected}
      {:not_wf, false} -> {:fail, :should_have_error}
      {:error, _} -> {:pass, :error_handling}
      {type, _} -> {:skip, {:unknown_type, type}}
    end
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
    summary = FnConformance.ResultsSummary.basic_summary(results)

    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("Namespace Conformance Results")
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
