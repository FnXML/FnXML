# Operations Benchmarks
# Run with: mix run bench/operations_bench.exs
#
# Benchmarks FnXML stream operations and pipeline performance

defmodule OperationsBench do
  @medium File.read!("bench/data/medium.xml")

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("OPERATIONS BENCHMARKS")
    IO.puts("Testing FnXML stream pipeline performance")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: medium.xml (#{byte_size(@medium)} bytes)")
    IO.puts("")

    Benchee.run(
      %{
        # Baseline: just parse
        "parse_only" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,

        # Parse + validation
        "parse_validate_structure" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.well_formed()
          |> Stream.run()
        end,

        "parse_validate_all" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.all()
          |> Stream.run()
        end,

        # Parse + entity resolution
        "parse_entities" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Entities.resolve()
          |> Stream.run()
        end,

        # Full pipeline
        "parse_validate_entities" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.all()
          |> FnXML.Entities.resolve()
          |> Stream.run()
        end,

        # With filtering
        "parse_filter_opens" => fn ->
          FnXML.Parser.parse(@medium)
          |> Stream.filter(&match?({:open, _}, &1))
          |> Stream.run()
        end,

        # Extract specific data
        "parse_extract_attrs" => fn ->
          FnXML.Parser.parse(@medium)
          |> Stream.flat_map(fn
            {:open, meta} -> [Keyword.get(meta, :attributes, [])]
            _ -> []
          end)
          |> Stream.run()
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end

  def run_validation_breakdown do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("VALIDATION BREAKDOWN")
    IO.puts("Cost of each validation step")
    IO.puts(String.duplicate("=", 70) <> "\n")

    Benchee.run(
      %{
        "baseline_parse" => fn ->
          FnXML.Parser.parse(@medium) |> Stream.run()
        end,

        "structure_only" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.well_formed()
          |> Stream.run()
        end,

        "attributes_only" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.attributes()
          |> Stream.run()
        end,

        "namespaces_only" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.namespaces()
          |> Stream.run()
        end,

        "all_validators" => fn ->
          FnXML.Parser.parse(@medium)
          |> FnXML.Validate.all()
          |> Stream.run()
        end
      },
      warmup: 1,
      time: 3,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end
end

if "--validation" in System.argv() do
  OperationsBench.run_validation_breakdown()
else
  OperationsBench.run()
end
