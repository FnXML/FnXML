defmodule Mix.Tasks.Conformance.Xml do
  @moduledoc """
  Run XML conformance tests against FnXML parser.

  Uses the W3C/OASIS XML Conformance Test Suite to validate parser behavior
  across Edition 4 (strict) and Edition 5 (permissive) parsers.

  ## Usage

      # Run tests for Edition 5 parser (default)
      mix conformance.xml

      # Run tests for a specific edition
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

      # Filter by test ID pattern
      mix conformance.xml --filter rmt-e2e

      # Parallel execution
      mix conformance.xml --concurrency 8

      # Analyze previous results
      mix conformance.xml --summary results/xml_conformance.jsonl

      # List available categories
      mix conformance.xml --categories

  ## Options

      --set NAME         Run tests from specific test set (xmltest, sun, oasis, ibm, etc.)
      --type TYPE        Run only tests of specific type (valid, not-wf, invalid, error)
      --filter PATTERN   Filter tests by ID pattern
      --category CAT     Filter by category
      --edition N        XML 1.0 edition to use: 4 or 5 (default: 5)
      --verbose          Print each test result
      --quick            Quick check with first 100 tests
      --limit N          Limit number of tests to run
      --concurrency N    Number of parallel workers (default: CPU cores)
      --output PATH      JSONL output path (default: results/xml_conformance.jsonl)
      --summary PATH     Analyze results from a previous run
      --categories       List available test categories

  ## Download

  Use `mix conformance.xml.download` to download the test suite.
  """

  use Mix.Task

  @shortdoc "Run XML conformance tests"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          set: :string,
          type: :string,
          filter: :string,
          category: :string,
          verbose: :boolean,
          quick: :boolean,
          limit: :integer,
          edition: :integer,
          concurrency: :integer,
          output: :string,
          summary: :string,
          categories: :boolean
        ],
        aliases: [
          s: :set,
          t: :type,
          f: :filter,
          v: :verbose,
          q: :quick,
          l: :limit,
          e: :edition,
          c: :concurrency
        ]
      )

    Mix.Task.run("app.start")

    cond do
      opts[:categories] ->
        run_categories()

      Keyword.has_key?(opts, :summary) ->
        run_summary(opts[:summary])

      true ->
        run_conformance(opts)
    end
  end

  defp run_categories do
    categories = FnXML.Conformance.list_categories()

    IO.puts("\nXML Conformance Test Categories (#{length(categories)}):")

    Enum.each(categories, fn cat ->
      IO.puts("  #{cat}")
    end)
  end

  defp run_summary(path) do
    unless File.exists?(path) do
      Mix.raise("Results file not found: #{path}")
    end

    FnConformance.ResultWriter.print_summary_from_file(path)
  end

  defp run_conformance(opts) do
    unless FnXML.Conformance.TestSuite.available?() do
      Mix.shell().error("XML conformance test suite not found.")
      Mix.shell().error("Download with: mix conformance.xml.download")
      System.halt(1)
    end

    # Handle --quick as --limit 100
    opts =
      if opts[:quick] do
        Keyword.put_new(opts, :limit, 100)
      else
        opts
      end

    FnXML.Conformance.run(opts)
  end
end
