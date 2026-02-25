defmodule FnXML.Conformance.Catalog do
  @moduledoc """
  Parse W3C XML Test Suite catalog files.

  The test suite uses XML catalog files (xmlconf.xml) that describe:
  - Test ID and description
  - Test type (valid, invalid, not-wf, error)
  - Input file path
  - Expected output (for valid tests)
  - Edition (XML 1.0 edition the test applies to)
  """

  defstruct [
    :id,
    :type,
    :uri,
    :description,
    :sections,
    :edition,
    :namespace,
    :output,
    :base_path
  ]

  @doc """
  Load all tests from the test suite catalog.
  """
  def load(suite_path, opts \\ []) do
    catalog_path = Path.join(suite_path, "xmlconf.xml")

    unless File.exists?(catalog_path) do
      raise "Catalog not found: #{catalog_path}"
    end

    parse_catalog(catalog_path, suite_path, opts)
  end

  @doc """
  List available test collections (TESTCASES elements).
  """
  def list_collections(suite_path, _opts \\ []) do
    catalog_path = Path.join(suite_path, "xmlconf.xml")
    extract_collections(catalog_path)
  end

  defp parse_catalog(catalog_path, suite_path, opts) do
    filter = Keyword.get(opts, :filter)
    limit = Keyword.get(opts, :limit)

    catalog_path
    |> parse_catalog_file(suite_path)
    |> maybe_filter(filter)
    |> maybe_limit(limit)
  end

  defp parse_catalog_file(file_path, _suite_path) do
    xml = File.read!(file_path)
    base_dir = Path.dirname(file_path)

    entity_files = extract_entity_files(xml)

    entity_files
    |> Enum.flat_map(fn rel_path ->
      full_path = Path.join(base_dir, rel_path)

      if File.exists?(full_path) do
        parse_subcatalog_file(full_path)
      else
        []
      end
    end)
  end

  defp extract_entity_files(xml) do
    ~r/<!ENTITY\s+\S+\s+SYSTEM\s+"([^"]+\.xml)"/
    |> Regex.scan(xml, capture: :all_but_first)
    |> List.flatten()
  end

  defp parse_subcatalog_file(file_path) do
    xml = File.read!(file_path)
    base_dir = Path.dirname(file_path)

    xml
    |> FnXML.Parser.parse()
    |> Enum.to_list()
    |> extract_tests_from_events(base_dir)
  end

  defp extract_tests_from_events(events, base_dir) do
    extract_tests_from_events(events, base_dir, [], nil)
  end

  defp extract_tests_from_events([], _base_dir, tests, _current_base) do
    Enum.reverse(tests)
  end

  defp extract_tests_from_events([event | rest], base_dir, tests, current_base) do
    case event do
      {:start_element, "TESTCASES", attrs, _line, _ls, _pos} ->
        new_base = get_attr_value(attrs, "xml:base") || current_base
        extract_tests_from_events(rest, base_dir, tests, new_base)

      {:end_element, "TESTCASES", _line, _ls, _pos} ->
        extract_tests_from_events(rest, base_dir, tests, nil)

      {:start_element, "TEST", attrs, _line, _ls, _pos} ->
        test = parse_test_from_attrs(attrs, current_base, base_dir)
        extract_tests_from_events(rest, base_dir, [test | tests], current_base)

      _ ->
        extract_tests_from_events(rest, base_dir, tests, current_base)
    end
  end

  defp parse_test_from_attrs(attrs, xml_base, base_dir) do
    full_base = if xml_base, do: Path.join(base_dir, xml_base), else: base_dir

    %__MODULE__{
      id: get_attr_value(attrs, "ID"),
      type: parse_type(get_attr_value(attrs, "TYPE") || "valid"),
      uri: get_attr_value(attrs, "URI"),
      sections: get_attr_value(attrs, "SECTIONS"),
      edition: get_attr_value(attrs, "EDITION"),
      namespace: get_attr_value(attrs, "NAMESPACE") == "yes",
      output: get_attr_value(attrs, "OUTPUT"),
      base_path: full_base,
      description: nil
    }
  end

  defp get_attr_value(attrs, name) do
    Enum.find_value(attrs, fn
      {^name, value} -> value
      _ -> nil
    end)
  end

  defp parse_type("valid"), do: :valid
  defp parse_type("invalid"), do: :invalid
  defp parse_type("not-wf"), do: :not_wf
  defp parse_type("error"), do: :error
  defp parse_type(other), do: String.to_atom(other)

  defp extract_collections(catalog_path) do
    xml = File.read!(catalog_path)
    base_dir = Path.dirname(catalog_path)

    extract_entity_files(xml)
    |> Enum.map(fn rel_path ->
      full_path = Path.join(base_dir, rel_path)

      if File.exists?(full_path) do
        get_collection_info(full_path, rel_path)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_collection_info(file_path, rel_path) do
    xml = File.read!(file_path)

    events =
      xml
      |> FnXML.Parser.parse()
      |> Enum.to_list()

    profile =
      Enum.find_value(events, "", fn
        {:start_element, "TESTCASES", attrs, _line, _ls, _pos} ->
          get_attr_value(attrs, "PROFILE")

        _ ->
          nil
      end)

    test_count =
      Enum.count(events, fn
        {:start_element, "TEST", _, _, _, _} -> true
        _ -> false
      end)

    base = Path.dirname(rel_path)
    %{profile: profile || base, base: base, tests: test_count}
  end

  defp maybe_filter(tests, nil), do: tests

  defp maybe_filter(tests, filter) when is_binary(filter) do
    filter_lower = String.downcase(filter)

    Enum.filter(tests, fn test ->
      String.contains?(String.downcase(test.id || ""), filter_lower) or
        String.contains?(String.downcase(test.base_path || ""), filter_lower)
    end)
  end

  defp maybe_limit(tests, nil), do: tests
  defp maybe_limit(tests, limit), do: Enum.take(tests, limit)
end
