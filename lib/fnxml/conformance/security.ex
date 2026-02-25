defmodule FnXML.Conformance.Security do
  @moduledoc """
  XML Security Conformance Testing for XML Signature and XML Encryption.

  Tests implementation conformance against W3C XML Security specifications:

  - **Canonical XML 1.0/1.1**: Canonicalization algorithms
  - **Exclusive C14N**: Exclusive canonicalization
  - **XML Signature 1.0/1.1**: Digital signature structure validation
  - **XML Encryption 1.0/1.1**: Encryption structure validation

  ## Running Tests

      FnXML.Conformance.Security.run()
      FnXML.Conformance.Security.run(category: :c14n)
      FnXML.Conformance.Security.run(verbose: true)
  """

  alias FnXML.Conformance.Security.{Catalog, Runner}

  @doc """
  Run XML Security conformance tests and return results.
  """
  def run(opts \\ []) do
    IO.puts("XML Security Conformance Tests")
    IO.puts(String.duplicate("=", 50))

    suite_path = security_test_path()

    unless File.dir?(suite_path) do
      IO.puts("Creating test suite with built-in test vectors...")
      setup_test_suite(suite_path)
    end

    tests = Catalog.load(suite_path, opts)
    IO.puts("Loaded #{length(tests)} tests\n")

    results = Runner.run_all(tests, opts)
    print_summary(results)
    results
  end

  @doc """
  Run a single test by ID.
  """
  def run_test(test_id, opts \\ []) do
    suite_path = security_test_path()
    ensure_test_suite(suite_path)
    tests = Catalog.load(suite_path, opts)

    case Enum.find(tests, &(&1.id == test_id)) do
      nil ->
        IO.puts("Test not found: #{test_id}")
        {:error, :not_found}

      test ->
        Runner.run_one(test, Keyword.put(opts, :verbose, true))
    end
  end

  @doc """
  Run tests from a specific category.
  """
  def run_category(category, opts \\ []) when is_atom(category) do
    suite_path = security_test_path()
    ensure_test_suite(suite_path)
    tests = Catalog.load(suite_path, Keyword.put(opts, :category, category))

    IO.puts("Running #{length(tests)} tests from category '#{category}'\n")

    results = Runner.run_all(tests, opts)
    print_summary(results)
    results
  end

  @doc """
  List available test categories.
  """
  def list_categories(opts \\ []) do
    suite_path = security_test_path()
    ensure_test_suite(suite_path)
    Catalog.list_categories(suite_path, opts)
  end

  defp security_test_path do
    Path.join([File.cwd!(), "priv", "test_suites", "security"])
  end

  defp ensure_test_suite(suite_path) do
    unless File.dir?(suite_path) do
      setup_test_suite(suite_path)
    end
  end

  defp setup_test_suite(suite_path) do
    File.mkdir_p!(suite_path)
    Catalog.generate_builtin_tests(suite_path)
    IO.puts("Test suite created at: #{suite_path}\n")
  end

  defp print_summary(results) do
    summary = FnConformance.ResultsSummary.basic_summary(results)

    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("XML Security Conformance Results")
    IO.puts(String.duplicate("-", 50))
    IO.puts("  Passed:  #{summary.pass}")
    IO.puts("  Failed:  #{summary.fail}")
    IO.puts("  Skipped: #{summary.skip}")
    IO.puts("  Total:   #{summary.total}")
    IO.puts("  Pass Rate: #{summary.pass_rate}%")
    IO.puts(String.duplicate("-", 50))

    if summary.by_group != [] do
      IO.puts("\nBy Category:")

      Enum.each(summary.by_group, fn {category, %{pass: p, total: t}} ->
        pct = if t > 0, do: Float.round(p / t * 100, 1), else: 0
        IO.puts("  #{category}: #{p}/#{t} (#{pct}%)")
      end)
    end

    summary
  end
end

