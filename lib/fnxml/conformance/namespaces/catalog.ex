defmodule FnXML.Conformance.Namespaces.Catalog do
  @moduledoc """
  Parse W3C XML Namespaces Test Suite catalog files.
  """

  defstruct [
    :id,
    :type,
    :uri,
    :description,
    :sections,
    :recommendation,
    :base_path
  ]

  @doc """
  Load all namespace tests from the test suite catalog.
  """
  def load(suite_path, opts \\ []) do
    catalog_path = Path.join(suite_path, "xmlconf.xml")

    unless File.exists?(catalog_path) do
      raise "Namespace catalog not found: #{catalog_path}"
    end

    parse_catalog(catalog_path, opts)
  end

  defp parse_catalog(catalog_path, opts) do
    version_filter = Keyword.get(opts, :version)

    xml = File.read!(catalog_path)
    base_dir = Path.dirname(catalog_path)

    entity_files = extract_entity_files(xml)

    entity_files
    |> Enum.flat_map(fn rel_path ->
      full_path = Path.join(base_dir, rel_path)

      if File.exists?(full_path) do
        parse_subcatalog(full_path)
      else
        []
      end
    end)
    |> maybe_filter_version(version_filter)
  end

  defp extract_entity_files(xml) do
    ~r/<!ENTITY\s+\S+\s+SYSTEM\s+"([^"]+\.xml)"/
    |> Regex.scan(xml, capture: :all_but_first)
    |> List.flatten()
  end

  defp parse_subcatalog(file_path) do
    xml = File.read!(file_path)
    base_dir = Path.dirname(file_path)

    recommendation =
      case Regex.run(~r/PROFILE="([^"]+)"/, xml) do
        [_, profile] -> extract_recommendation(profile)
        nil -> "NS1.0"
      end

    ~r/<TEST\s+([^>]+)>/s
    |> Regex.scan(xml, capture: :all_but_first)
    |> Enum.map(fn [attrs_str] ->
      attrs = parse_attributes(attrs_str)

      %__MODULE__{
        id: attrs["ID"],
        type: parse_type(attrs["TYPE"] || "valid"),
        uri: attrs["URI"],
        sections: attrs["SECTIONS"],
        recommendation: attrs["RECOMMENDATION"] || recommendation,
        base_path: base_dir
      }
    end)
  end

  defp extract_recommendation(profile) do
    cond do
      String.contains?(profile, "1.1") -> "NS1.1"
      String.contains?(profile, "errata") -> "NS1.0-errata"
      true -> "NS1.0"
    end
  end

  defp parse_attributes(attrs_str) do
    ~r/(\w+)="([^"]*)"/
    |> Regex.scan(attrs_str, capture: :all_but_first)
    |> Map.new(fn [key, val] -> {key, val} end)
  end

  defp parse_type("valid"), do: :valid
  defp parse_type("invalid"), do: :invalid
  defp parse_type("not-wf"), do: :not_wf
  defp parse_type("error"), do: :error
  defp parse_type(other), do: String.to_atom(other)

  defp maybe_filter_version(tests, nil), do: tests

  defp maybe_filter_version(tests, "1.0") do
    Enum.filter(tests, &(&1.recommendation == "NS1.0"))
  end

  defp maybe_filter_version(tests, "1.1") do
    Enum.filter(tests, &(&1.recommendation == "NS1.1"))
  end

  defp maybe_filter_version(tests, _), do: tests
end
