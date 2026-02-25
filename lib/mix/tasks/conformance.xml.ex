defmodule Mix.Tasks.Conformance.Xml do
  @moduledoc """
  Run XML conformance tests against FnXML parser.

  Uses the W3C XML Conformance Test Suite to validate parser behavior.

  ## Usage

      # Run tests for both Edition 4 and Edition 5 parsers (default)
      mix conformance.xml

      # Run tests for a specific edition only
      mix conformance.xml --edition 4
      mix conformance.xml --edition 5

      # Run specific test set
      mix conformance.xml --set xmltest

      # Run with verbose output
      mix conformance.xml --verbose

      # Quick check (100 tests)
      mix conformance.xml --quick

      # Run only specific test types
      mix conformance.xml --type valid
      mix conformance.xml --type not-wf

  ## Options

      --set NAME      Run tests from specific test set (xmltest, sun, oasis, ibm, etc.)
      --type TYPE     Run only tests of specific type (valid, not-wf, invalid, error)
      --filter PATTERN Filter tests by ID pattern
      --verbose       Print each test result
      --quick         Quick check with first 100 tests
      --limit N       Limit number of tests to run
      --suite PATH    Path to xmlconf test suite (default: searches common locations)
      --edition N     XML 1.0 edition to use: 4 or 5 (default: both)
      --download      Download the test suite to priv/test_suites/xmlconf
  """

  use Mix.Task

  # These modules are .exs files loaded at runtime by load_conformance_modules/0
  @compile {:no_warn_undefined, [FnXML.Conformance.Pipeline, FnXML.Conformance.TestSuite]}

  @shortdoc "Run XML conformance tests"

  @impl Mix.Task
  def run(args) do
    # Start required applications
    Mix.Task.run("app.start")

    # Load conformance support modules (.exs files not compiled into the library)
    load_conformance_modules()

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          set: :string,
          type: :string,
          filter: :string,
          verbose: :boolean,
          quick: :boolean,
          limit: :integer,
          suite: :string,
          edition: :integer,
          download: :boolean
        ],
        aliases: [
          s: :set,
          t: :type,
          f: :filter,
          v: :verbose,
          q: :quick,
          l: :limit,
          e: :edition,
          d: :download
        ]
      )

    if opts[:download] do
      download_suite()
    else
      suite_path = find_test_suite(opts[:suite])

      case suite_path do
        nil ->
          Mix.shell().error("Could not find XML conformance test suite.")

          Mix.shell().error("Run `mix conformance.xml --download` or specify path with --suite.")

          System.halt(1)

        path ->
          Mix.shell().info("Using test suite at: #{path}")

          # Determine which editions to test
          editions =
            case opts[:edition] do
              nil -> [4, 5]
              edition -> [edition]
            end

          run_tests_for_editions(path, editions, opts)
      end
    end
  end

  defp run_tests_for_editions(suite_path, editions, opts) do
    # Run tests for each edition and collect results
    all_edition_results =
      Enum.map(editions, fn edition ->
        Mix.shell().info("\n" <> String.duplicate("=", 60))
        Mix.shell().info("Testing Edition #{edition} Parser")
        Mix.shell().info(String.duplicate("=", 60))

        results = run_tests(suite_path, Keyword.put(opts, :edition, edition))
        {edition, results}
      end)

    # Print combined summary if testing multiple editions
    if length(editions) > 1 do
      print_combined_summary(all_edition_results)
    end
  end

  defp download_suite do
    alias FnXML.Conformance.TestSuite

    if TestSuite.available?() do
      IO.puts("Test suite already downloaded at: #{TestSuite.suite_path()}")
    else
      IO.puts("Downloading #{TestSuite.name()}...")

      case TestSuite.download() do
        :ok -> IO.puts("Download complete.")
        {:error, reason} -> IO.puts("Download failed: #{inspect(reason)}")
      end
    end
  end

  defp find_test_suite(explicit_path) do
    paths =
      [
        explicit_path,
        "priv/test_suites/xmlconf",
        "../fnconformance/priv/test_suites/xmlconf",
        "../../fnconformance/priv/test_suites/xmlconf",
        Path.expand("~/Projects/elixir/xml/fnconformance/priv/test_suites/xmlconf")
      ]
      |> Enum.filter(& &1)

    Enum.find(paths, fn path ->
      File.exists?(Path.join(path, "xmlconf.xml"))
    end)
  end

  defp run_tests(suite_path, opts) do
    edition = opts[:edition]
    Mix.shell().info("Loading test catalog...")

    tests =
      load_tests(suite_path)
      |> filter_tests(opts)
      |> maybe_limit(opts)

    total = length(tests)
    Mix.shell().info("Running #{total} tests for Edition #{edition}...\n")

    results = run_all_tests(tests, suite_path, opts)

    print_summary(results, edition)

    # Return results for combined summary
    results
  end

  defp load_tests(suite_path) do
    # Parse individual test files directly instead of the master catalog
    # (which has external entity references that are complex to handle)
    test_files = [
      {"xmltest", "xmltest/xmltest.xml"},
      {"sun-valid", "sun/sun-valid.xml"},
      {"sun-invalid", "sun/sun-invalid.xml"},
      {"sun-not-wf", "sun/sun-not-wf.xml"},
      {"sun-error", "sun/sun-error.xml"},
      {"oasis", "oasis/oasis.xml"},
      {"ibm-valid", "ibm/ibm_oasis_valid.xml"},
      {"ibm-invalid", "ibm/ibm_oasis_invalid.xml"},
      {"ibm-not-wf", "ibm/ibm_oasis_not-wf.xml"},
      {"japanese", "japanese/japanese.xml"},
      {"eduni-errata2e", "eduni/errata-2e/errata2e.xml"},
      {"eduni-errata3e", "eduni/errata-3e/errata3e.xml"},
      {"eduni-errata4e", "eduni/errata-4e/errata4e.xml"},
      {"eduni-ns10", "eduni/namespaces/1.0/rmt-ns10.xml"},
      {"eduni-ns11", "eduni/namespaces/1.1/rmt-ns11.xml"}
    ]

    test_files
    |> Enum.flat_map(fn {set_name, rel_path} ->
      full_path = Path.join(suite_path, rel_path)
      base_dir = Path.dirname(full_path)

      if File.exists?(full_path) do
        parse_test_file(full_path, base_dir, set_name)
      else
        []
      end
    end)
  end

  defp parse_test_file(path, base_dir, set_name) do
    case File.read(path) do
      {:ok, content} ->
        # Simple regex-based parsing for TEST elements
        # This avoids needing a full XML parser with DTD support
        ~r/<TEST\s+([^>]+)>([^<]*)<\/TEST>/s
        |> Regex.scan(content)
        |> Enum.map(fn [_full, attrs, description] ->
          parse_test_attrs(attrs, description, base_dir, set_name)
        end)
        |> Enum.filter(& &1)

      {:error, _} ->
        []
    end
  end

  defp parse_test_attrs(attrs_str, description, base_dir, set_name) do
    attrs = parse_xml_attrs(attrs_str)

    case {attrs["ID"], attrs["URI"], attrs["TYPE"]} do
      {id, uri, type} when id != nil and uri != nil and type != nil ->
        %{
          id: id,
          uri: Path.join(base_dir, uri),
          type: String.downcase(type),
          set: set_name,
          description: String.trim(description),
          entities: attrs["ENTITIES"] || "none",
          sections: attrs["SECTIONS"],
          # Parse EDITION attribute (e.g., "5", "1 2 3 4", etc.)
          target_editions: parse_editions(attrs["EDITION"]),
          # NAMESPACE="no" means skip namespace validation
          namespace: attrs["NAMESPACE"] != "no"
        }

      _ ->
        nil
    end
  end

  # Parse EDITION attribute into list of integers
  # "5" -> [5], "1 2 3 4" -> [1, 2, 3, 4], nil -> [1, 2, 3, 4, 5] (all editions)
  defp parse_editions(nil), do: [1, 2, 3, 4, 5]

  defp parse_editions(edition_str) do
    edition_str
    |> String.split()
    |> Enum.map(&String.to_integer/1)
  end

  defp parse_xml_attrs(attrs_str) do
    ~r/(\w+)\s*=\s*"([^"]*)"/
    |> Regex.scan(attrs_str)
    |> Enum.map(fn [_, name, value] -> {name, value} end)
    |> Map.new()
  end

  defp filter_tests(tests, opts) do
    tests
    |> filter_by_set(opts[:set])
    |> filter_by_type(opts[:type])
    |> filter_by_pattern(opts[:filter])
  end

  defp filter_by_set(tests, nil), do: tests

  defp filter_by_set(tests, set) do
    pattern = String.downcase(set)

    Enum.filter(tests, fn t ->
      String.contains?(String.downcase(t.set), pattern)
    end)
  end

  defp filter_by_type(tests, nil), do: tests

  defp filter_by_type(tests, type) do
    Enum.filter(tests, fn t -> t.type == String.downcase(type) end)
  end

  defp filter_by_pattern(tests, nil), do: tests

  defp filter_by_pattern(tests, pattern) do
    Enum.filter(tests, fn t -> String.contains?(t.id, pattern) end)
  end

  defp maybe_limit(tests, opts) do
    cond do
      opts[:quick] -> Enum.take(tests, 100)
      opts[:limit] -> Enum.take(tests, opts[:limit])
      true -> tests
    end
  end

  defp run_all_tests(tests, _suite_path, opts) do
    verbose = opts[:verbose]
    edition = opts[:edition]
    total = length(tests)

    tests
    |> Enum.with_index(1)
    |> Enum.map(fn {test, idx} ->
      result = run_single_test(test, edition)

      if verbose do
        status =
          cond do
            result[:skipped] -> "SKIP"
            result.pass -> "PASS"
            true -> "FAIL"
          end

        Mix.shell().info("[#{idx}/#{total}] #{status} #{test.id}")
      else
        # Progress indicator
        if rem(idx, 100) == 0 do
          Mix.shell().info("  Completed #{idx}/#{total} tests...")
        end
      end

      result
    end)
  end

  defp run_single_test(test, requested_edition) do
    start_time = System.monotonic_time(:millisecond)

    # Check if this test is applicable to the requested edition
    result =
      if requested_edition in test.target_editions do
        case File.read(test.uri) do
          {:ok, content} ->
            # Use the highest applicable edition for this test
            effective_edition = min(requested_edition, Enum.max(test.target_editions))

            test_meta = %{
              type: test.type,
              entities: test.entities,
              namespace: test.namespace,
              uri: test.uri
            }

            pipeline_result =
              FnXML.Conformance.Pipeline.run_test(content, test_meta, effective_edition)

            evaluate_result(test.type, pipeline_result)

          {:error, reason} ->
            %{pass: false, error: {:file_error, reason}}
        end
      else
        # Test not applicable to this edition - skip with note
        %{pass: true, skipped: true, note: {:edition_mismatch, test.target_editions}}
      end

    elapsed = System.monotonic_time(:millisecond) - start_time

    Map.merge(result, %{
      id: test.id,
      type: test.type,
      set: test.set,
      elapsed_ms: elapsed,
      target_editions: test.target_editions
    })
  end

  defp evaluate_result("valid", {:ok, _events}), do: %{pass: true}

  defp evaluate_result("valid", {:error, reason}),
    do: %{pass: false, error: {:unexpected_error, reason}}

  defp evaluate_result("not-wf", {:ok, _events}),
    do: %{pass: false, error: :expected_error_but_passed}

  defp evaluate_result("not-wf", {:error, _reason}), do: %{pass: true}
  defp evaluate_result("invalid", {:ok, _events}), do: %{pass: true, note: :no_dtd_validation}

  defp evaluate_result("invalid", {:error, reason}),
    do: %{pass: false, error: {:unexpected_error, reason}}

  defp evaluate_result("error", {:ok, _events}), do: %{pass: true, note: :optional_error}
  defp evaluate_result("error", {:error, _reason}), do: %{pass: true}
  defp evaluate_result(_type, result), do: %{pass: false, error: {:unknown_type, result}}

  defp print_summary(results, edition) do
    total = length(results)
    skipped = Enum.count(results, fn r -> r[:skipped] == true end)
    passed = Enum.count(results, fn r -> r.pass and r[:skipped] != true end)
    failed = total - passed - skipped

    # Group by type (excluding skipped)
    active_results = Enum.reject(results, fn r -> r[:skipped] == true end)
    by_type = Enum.group_by(active_results, & &1.type)

    # Group by set (excluding skipped)
    by_set = Enum.group_by(active_results, & &1.set)

    Mix.shell().info("\n" <> String.duplicate("=", 60))
    Mix.shell().info("XML CONFORMANCE TEST RESULTS - Edition #{edition}")
    Mix.shell().info(String.duplicate("=", 60))

    Mix.shell().info("\nOverall:")
    Mix.shell().info("  Passed:    #{passed}")
    Mix.shell().info("  Failed:    #{failed}")
    if skipped > 0, do: Mix.shell().info("  Skipped:   #{skipped} (edition mismatch)")
    active_total = passed + failed

    Mix.shell().info(
      "  Total:     #{active_total}#{if skipped > 0, do: " (#{total} including skipped)", else: ""}"
    )

    pass_rate = if active_total > 0, do: Float.round(passed / active_total * 100, 1), else: 0.0
    Mix.shell().info("  Pass Rate: #{pass_rate}%")

    Mix.shell().info("\nBy Type:")

    for {type, type_results} <- Enum.sort(by_type) do
      type_passed = Enum.count(type_results, & &1.pass)
      type_total = length(type_results)
      Mix.shell().info("  #{String.pad_trailing(type, 12)} #{type_passed}/#{type_total}")
    end

    Mix.shell().info("\nBy Test Set:")

    by_set
    |> Enum.sort_by(fn {_set, results} -> -length(results) end)
    |> Enum.take(15)
    |> Enum.each(fn {set, set_results} ->
      set_passed = Enum.count(set_results, & &1.pass)
      set_total = length(set_results)
      rate = if set_total > 0, do: Float.round(set_passed / set_total * 100, 1), else: 0.0
      Mix.shell().info("  #{String.pad_trailing(set, 20)} #{set_passed}/#{set_total} (#{rate}%)")
    end)

    # Show some failures if any
    failures = Enum.filter(results, &(!&1.pass))

    if length(failures) > 0 do
      Mix.shell().info("\nSample Failures (first 10):")

      failures
      |> Enum.take(10)
      |> Enum.each(fn f ->
        Mix.shell().info("  #{f.id}: #{inspect(f.error)}")
      end)
    end

    Mix.shell().info(String.duplicate("=", 60) <> "\n")
  end

  # Print combined summary comparing results across editions
  defp print_combined_summary(edition_results) do
    Mix.shell().info("\n" <> String.duplicate("=", 60))
    Mix.shell().info("COMBINED CONFORMANCE SUMMARY - All Parsers")
    Mix.shell().info(String.duplicate("=", 60))

    # Calculate stats for each edition
    edition_stats =
      Enum.map(edition_results, fn {edition, results} ->
        total = length(results)
        skipped = Enum.count(results, fn r -> r[:skipped] == true end)
        passed = Enum.count(results, fn r -> r.pass and r[:skipped] != true end)
        failed = total - passed - skipped
        active_total = passed + failed

        pass_rate =
          if active_total > 0, do: Float.round(passed / active_total * 100, 1), else: 0.0

        {edition,
         %{passed: passed, failed: failed, skipped: skipped, total: active_total, rate: pass_rate}}
      end)

    # Print comparison table
    Mix.shell().info("\nParser Comparison:")

    Mix.shell().info(
      "  #{String.pad_trailing("Edition", 10)} #{String.pad_trailing("Passed", 10)} #{String.pad_trailing("Failed", 10)} #{String.pad_trailing("Rate", 10)}"
    )

    Mix.shell().info("  #{String.duplicate("-", 40)}")

    for {edition, stats} <- edition_stats do
      Mix.shell().info(
        "  #{String.pad_trailing("Edition #{edition}", 10)} " <>
          "#{String.pad_trailing("#{stats.passed}", 10)} " <>
          "#{String.pad_trailing("#{stats.failed}", 10)} " <>
          "#{String.pad_trailing("#{stats.rate}%", 10)}"
      )
    end

    # Find tests that pass in one edition but fail in another
    if length(edition_results) == 2 do
      [{ed1, results1}, {ed2, results2}] = edition_results

      # Build maps of test results by ID
      results1_map = Map.new(results1, fn r -> {r.id, r.pass} end)
      results2_map = Map.new(results2, fn r -> {r.id, r.pass} end)

      # Find differences
      pass_in_1_fail_in_2 =
        results1
        |> Enum.filter(fn r ->
          r.pass and r[:skipped] != true and Map.get(results2_map, r.id) == false
        end)
        |> Enum.map(& &1.id)

      pass_in_2_fail_in_1 =
        results2
        |> Enum.filter(fn r ->
          r.pass and r[:skipped] != true and Map.get(results1_map, r.id) == false
        end)
        |> Enum.map(& &1.id)

      if length(pass_in_1_fail_in_2) > 0 or length(pass_in_2_fail_in_1) > 0 do
        Mix.shell().info("\nEdition Differences:")

        if length(pass_in_1_fail_in_2) > 0 do
          Mix.shell().info(
            "  Pass in Edition #{ed1}, Fail in Edition #{ed2}: #{length(pass_in_1_fail_in_2)} tests"
          )

          pass_in_1_fail_in_2
          |> Enum.take(5)
          |> Enum.each(fn id -> Mix.shell().info("    - #{id}") end)

          if length(pass_in_1_fail_in_2) > 5 do
            Mix.shell().info("    ... and #{length(pass_in_1_fail_in_2) - 5} more")
          end
        end

        if length(pass_in_2_fail_in_1) > 0 do
          Mix.shell().info(
            "  Pass in Edition #{ed2}, Fail in Edition #{ed1}: #{length(pass_in_2_fail_in_1)} tests"
          )

          pass_in_2_fail_in_1
          |> Enum.take(5)
          |> Enum.each(fn id -> Mix.shell().info("    - #{id}") end)

          if length(pass_in_2_fail_in_1) > 5 do
            Mix.shell().info("    ... and #{length(pass_in_2_fail_in_1) - 5} more")
          end
        end
      else
        Mix.shell().info("\nNo differences found between editions (same tests pass/fail)")
      end
    end

    Mix.shell().info(String.duplicate("=", 60) <> "\n")
  end

  defp load_conformance_modules do
    conformance_dir = find_conformance_dir()

    # Load in dependency order: catalogs first, then pipeline, then runners
    for file <- [
          "catalog.exs",
          "pipeline.exs",
          "test_suite.exs",
          "namespaces/catalog.exs",
          "namespaces.exs",
          "security/catalog.exs",
          "security/runner.exs",
          "security.exs",
          "conformance.exs"
        ] do
      path = Path.join(conformance_dir, file)
      if File.exists?(path), do: Code.require_file(path)
    end
  end

  defp find_conformance_dir do
    # Primary: load from fnconformance dependency's priv/xml directory
    priv_dir =
      try do
        Application.app_dir(:fnconformance, "priv/xml")
      rescue
        _ -> nil
      end

    cond do
      priv_dir && File.dir?(priv_dir) ->
        priv_dir

      # Fallback: workspace-relative path for development
      File.dir?("../fnconformance/priv/xml") ->
        Path.expand("../fnconformance/priv/xml")

      true ->
        # Legacy: local conformance directory (should not be needed after migration)
        Path.expand("../../fnxml/conformance", __DIR__)
    end
  end
end
