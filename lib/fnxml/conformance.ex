defmodule FnXML.Conformance do
  @moduledoc """
  XML conformance test runner.

  Implements `FnConformance.Runner` behaviour with full viewer support.
  Tests FnXML against the W3C/OASIS XML Conformance Test Suite, which
  includes ~2,000 tests from multiple vendors.

  ## Usage

      mix conformance.xml                         # Run all tests (Edition 5)
      mix conformance.xml --edition 4             # Test Edition 4 parser
      mix conformance.xml --edition 5             # Test Edition 5 parser
      mix conformance.xml --set xmltest           # Filter by test set
      mix conformance.xml --type valid            # Filter by test type
      mix conformance.xml --filter pattern        # Filter by test ID
      mix conformance.xml --limit 100             # Limit test count
      mix conformance.xml --verbose               # Per-test output
      mix conformance.xml --concurrency 8         # Parallel workers

  ## Viewer Integration

  This module implements the optional viewer callbacks from
  `FnConformance.Runner`, making it discoverable by the Conformance
  Viewer (`mix conformance.viewer`).
  """

  @behaviour FnConformance.Runner

  alias FnXML.Conformance.{Catalog, Pipeline}

  @impl true
  def component_name, do: :xml

  @impl true
  def run(opts \\ []) do
    # Default to edition 5 if not specified
    edition = Keyword.get(opts, :edition, 5)
    opts = Keyword.put(opts, :edition, edition)

    tests = Catalog.load(opts)

    if tests == [] do
      IO.puts("No matching XML conformance tests found.")
      []
    else
      IO.puts("Found #{length(tests)} XML tests (Edition #{edition}).")

      worker_fn = fn test ->
        Pipeline.run_test(test, opts)
      end

      output = Keyword.get(opts, :output, "results/xml_conformance.jsonl")
      concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())

      FnConformance.ParallelRunner.run(tests, worker_fn,
        output: output,
        concurrency: concurrency,
        component: "XML Conformance (Edition #{edition})",
        name_fn: fn t -> t.name end,
        verbose: Keyword.get(opts, :verbose, false)
      )
    end
  end

  @impl true
  def list_tests(opts \\ []) do
    Catalog.load(opts)
    |> Enum.map(fn test ->
      %{
        name: test.name,
        category: test.category,
        data: test
      }
    end)
  end

  @impl true
  def run_one(test, opts \\ []) do
    Pipeline.run_test(test.data, opts)
  end

  @impl true
  def list_categories do
    Catalog.list_categories()
  end

  @impl true
  def artifact_paths(_test, _result) do
    # XML conformance tests are text-based — no image artifacts
    %{reference: nil, rendered: nil, diff: nil}
  end
end
