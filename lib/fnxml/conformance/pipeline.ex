defmodule FnXML.Conformance.Pipeline do
  @moduledoc """
  XML conformance test execution pipeline.

  Runs individual XML test files through the FnXML parser with
  edition-appropriate settings and evaluates the outcome against
  the expected test type (valid, not-well-formed, invalid, error).
  """

  alias FnConformance.Result

  @doc """
  Execute a single conformance test and return a `FnConformance.Result`.

  The test map must include `:name`, `:uri`, `:type`, `:set`,
  `:target_editions`, `:entities`, and `:namespace`.
  """
  @spec run_test(map(), keyword()) :: Result.t()
  def run_test(test, opts \\ []) do
    edition = Keyword.get(opts, :edition, 5)
    start = System.monotonic_time(:microsecond)

    {status, details} =
      if edition in test.target_editions do
        execute(test, edition)
      else
        {:skip, "edition #{edition} not applicable (test targets: #{inspect(test.target_editions)})"}
      end

    elapsed = System.monotonic_time(:microsecond) - start

    case status do
      :pass ->
        Result.pass(test.name,
          elapsed_us: elapsed,
          group: test.set,
          metadata: %{edition: edition, type: test.type}
        )

      :fail ->
        Result.fail(test.name, details,
          elapsed_us: elapsed,
          group: test.set,
          metadata: %{edition: edition, type: test.type}
        )

      :skip ->
        Result.skip(test.name, details,
          group: test.set,
          metadata: %{edition: edition, type: test.type}
        )

      :error ->
        Result.error(test.name, details,
          elapsed_us: elapsed,
          group: test.set,
          metadata: %{edition: edition, type: test.type}
        )
    end
  end

  defp execute(test, edition) do
    case File.read(test.uri) do
      {:ok, content} ->
        effective_edition = min(edition, Enum.max(test.target_editions))
        parse_result = parse_xml(content, effective_edition)
        evaluate(test.type, parse_result)

      {:error, reason} ->
        {:error, "file read error: #{inspect(reason)}"}
    end
  rescue
    e ->
      {:error, "exception: #{Exception.message(e)}"}
  catch
    :exit, reason ->
      {:error, "exit: #{inspect(reason)}"}
  end

  defp parse_xml(content, edition) do
    events =
      content
      |> FnXML.process(edition: edition)
      |> FnXML.halt_on_error()
      |> Enum.to_list()

    # Check if the last event is an error
    case List.last(events) do
      {:error, _, _, _, _, _} = err -> {:error, err}
      {:error, _, _} = err -> {:error, err}
      _ -> {:ok, events}
    end
  end

  # Valid tests should parse without errors
  defp evaluate("valid", {:ok, _events}), do: {:pass, nil}
  defp evaluate("valid", {:error, reason}), do: {:fail, "expected valid but got error: #{inspect(reason)}"}

  # Not-well-formed tests should produce parse errors
  defp evaluate("not-wf", {:ok, _events}), do: {:fail, "expected error but parsed successfully"}
  defp evaluate("not-wf", {:error, _reason}), do: {:pass, nil}

  # Invalid tests are DTD-invalid but well-formed; we accept either outcome
  # since full DTD validation is optional for non-validating parsers
  defp evaluate("invalid", {:ok, _events}), do: {:pass, nil}
  defp evaluate("invalid", {:error, _reason}), do: {:pass, nil}

  # Error tests: errors are optional, both outcomes are acceptable
  defp evaluate("error", {:ok, _events}), do: {:pass, nil}
  defp evaluate("error", {:error, _reason}), do: {:pass, nil}

  defp evaluate(type, _result), do: {:error, "unknown test type: #{type}"}
end
