defmodule FnXML.Conformance.Catalog do
  @moduledoc """
  Parses W3C/OASIS XML Conformance Test Suite catalog files.

  Uses regex-based XML parsing to avoid circular dependency on FnXML
  for parsing the test catalog files themselves.

  Supports all standard test sets: xmltest, sun, oasis, ibm, japanese, eduni.
  Extracts test metadata including ID, URI, TYPE, EDITION, ENTITIES,
  SECTIONS, and NAMESPACE attributes.
  """

  @doc """
  Load all test cases from the conformance test suite.

  ## Options

  - `:suite_path` — path to xmlconf directory (default: from TestSuite)
  - `:set` — filter by test set name (e.g., "xmltest", "sun", "ibm")
  - `:type` — filter by test type ("valid", "not-wf", "invalid", "error")
  - `:filter` — filter by test ID pattern
  - `:edition` — filter by XML edition (4 or 5)
  - `:category` — filter by category (set name or "edition-4", "edition-5")
  - `:limit` — maximum number of tests to return
  """
  @spec load(keyword()) :: [map()]
  def load(opts \\ []) do
    suite_path = Keyword.get_lazy(opts, :suite_path, fn ->
      FnXML.Conformance.TestSuite.suite_path()
    end)

    unless File.dir?(suite_path) do
      IO.puts("XML conformance test suite not found at #{suite_path}")
      IO.puts("Download with: mix conformance.xml.download")
      []
    else
      test_files()
      |> Enum.flat_map(fn {set_name, rel_path} ->
        full_path = Path.join(suite_path, rel_path)
        base_dir = Path.dirname(full_path)

        if File.exists?(full_path) do
          parse_test_file(full_path, base_dir, set_name)
        else
          []
        end
      end)
      |> filter_tests(opts)
      |> maybe_limit(opts)
    end
  end

  @doc """
  List available test categories.

  Returns a sorted list of category names combining test set names
  and edition identifiers.
  """
  @spec list_categories() :: [String.t()]
  def list_categories do
    set_categories =
      test_files()
      |> Enum.map(fn {set_name, _} -> set_name end)
      |> Enum.uniq()
      |> Enum.sort()

    edition_categories = ["edition-4", "edition-5"]

    type_categories = ["valid", "not-wf", "invalid", "error"]

    set_categories ++ edition_categories ++ type_categories
  end

  # Catalog files for each test set
  defp test_files do
    [
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
  end

  defp parse_test_file(path, base_dir, set_name) do
    case File.read(path) do
      {:ok, content} ->
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
          name: id,
          uri: Path.join(base_dir, uri),
          type: String.downcase(type),
          set: set_name,
          category: set_name,
          description: String.trim(description),
          entities: attrs["ENTITIES"] || "none",
          sections: attrs["SECTIONS"],
          target_editions: parse_editions(attrs["EDITION"]),
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
    |> filter_by_edition(opts[:edition])
    |> filter_by_category(opts[:category])
  end

  defp filter_by_set(tests, nil), do: tests

  defp filter_by_set(tests, set) do
    pattern = String.downcase(set)
    Enum.filter(tests, fn t -> String.contains?(String.downcase(t.set), pattern) end)
  end

  defp filter_by_type(tests, nil), do: tests

  defp filter_by_type(tests, type) do
    Enum.filter(tests, fn t -> t.type == String.downcase(type) end)
  end

  defp filter_by_pattern(tests, nil), do: tests

  defp filter_by_pattern(tests, pattern) do
    Enum.filter(tests, fn t -> String.contains?(t.name, pattern) end)
  end

  defp filter_by_edition(tests, nil), do: tests

  defp filter_by_edition(tests, edition) when is_integer(edition) do
    Enum.filter(tests, fn t -> edition in t.target_editions end)
  end

  defp filter_by_category(tests, nil), do: tests

  defp filter_by_category(tests, "edition-4") do
    Enum.filter(tests, fn t -> 4 in t.target_editions end)
  end

  defp filter_by_category(tests, "edition-5") do
    Enum.filter(tests, fn t -> 5 in t.target_editions end)
  end

  defp filter_by_category(tests, category) do
    cat_lower = String.downcase(category)

    Enum.filter(tests, fn t ->
      String.contains?(String.downcase(t.category), cat_lower) or
        t.type == cat_lower
    end)
  end

  defp maybe_limit(tests, opts) do
    case Keyword.get(opts, :limit) do
      nil -> tests
      limit -> Enum.take(tests, limit)
    end
  end
end
