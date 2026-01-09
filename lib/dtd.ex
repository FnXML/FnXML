defmodule FnXML.DTD do
  @moduledoc """
  Document Type Definition (DTD) processing from XML streams.

  This module provides functions to extract and parse DTD declarations
  from XML parser event streams, supporting both internal and external subsets.

  ## Specifications

  - W3C XML 1.0 DTD: https://www.w3.org/TR/xml/#dt-doctype
  - W3C DTD Declarations: https://www.w3.org/TR/xml/#sec-prolog-dtd

  ## Overview

  A Document Type Definition defines the legal building blocks of an XML document.
  It declares:
  - **Elements** - What elements can appear and their content models
  - **Attributes** - What attributes each element can have
  - **Entities** - Reusable content substitutions
  - **Notations** - External non-XML content references

  ## Use Cases

  ### Extract DTD from XML

      xml = \"\"\"
      <!DOCTYPE note [
        <!ELEMENT note (#PCDATA)>
        <!ATTLIST note date CDATA #REQUIRED>
      ]>
      <note date="2024-01-01">Hello</note>
      \"\"\"

      {:ok, model} = FnXML.Parser.parse(xml) |> FnXML.DTD.from_stream()
      model.elements["note"]   # => :pcdata
      model.attributes["note"] # => [{"date", :cdata, :required, nil}]

  ### Entity Resolution

      # Parse XML with entity definitions
      {:ok, model} = FnXML.Parser.parse(xml_with_dtd) |> FnXML.DTD.from_stream()

      # Resolve entity references using the model
      FnXML.Parser.parse(xml)
      |> FnXML.DTD.EntityResolver.resolve(model)
      |> Enum.to_list()

  ### External DTD Loading

      # Provide a resolver function for external DTDs
      resolver = fn system_id, _public_id ->
        {:ok, File.read!(system_id)}
      end

      FnXML.DTD.parse_doctype("DOCTYPE root SYSTEM \\"schema.dtd\\"",
        external_resolver: resolver)

  ## DTD Event Format

  The XML parser emits DTD events in the format:

      {:dtd, content, loc}

  Where `content` is the raw DOCTYPE declaration without the `<!` prefix
  and `>` suffix, e.g.:

      "DOCTYPE root [\\n  <!ELEMENT root EMPTY>\\n]"

  ## DTD Model Structure

  The `FnXML.DTD.Model` struct contains:
  - `root_element` - Name of the document root element
  - `elements` - Map of element name to content model
  - `attributes` - Map of element name to attribute definitions
  - `entities` - Map of general entity name to value
  - `param_entities` - Map of parameter entity name to value
  - `notations` - Map of notation name to external ID
  """

  alias FnXML.DTD.{Model, Parser}

  @doc """
  Extract and parse DTD from an XML event stream.

  Finds the first `:dtd` event in the stream, parses it, and returns
  the resulting `FnXML.DTD.Model`.

  ## Options

  - `:external_resolver` - Function to fetch external DTD content

  ## Examples

      iex> xml = \"""
      ...> <!DOCTYPE note [
      ...>   <!ELEMENT note (#PCDATA)>
      ...> ]>
      ...> <note>Hello</note>
      ...> \"""
      iex> {:ok, model} = FnXML.Parser.parse(xml) |> FnXML.DTD.from_stream()
      iex> model.elements["note"]
      :pcdata

  """
  @spec from_stream(Enumerable.t(), keyword()) ::
          {:ok, Model.t()} | {:error, String.t()} | :no_dtd
  def from_stream(stream, opts \\ []) do
    stream
    |> Enum.find(&match?({:dtd, _, _}, &1))
    |> case do
      {:dtd, content, _loc} ->
        parse_doctype(content, opts)

      nil ->
        :no_dtd
    end
  end

  @doc """
  Parse a DOCTYPE declaration string.

  The string should be in the format emitted by the parser (without `<!` and `>`):

      "DOCTYPE root [...]"
      "DOCTYPE root SYSTEM \\"file.dtd\\""
      "DOCTYPE root PUBLIC \\"-//...//\\" \\"file.dtd\\" [...]"

  ## Examples

      iex> FnXML.DTD.parse_doctype("DOCTYPE note [<!ELEMENT note (#PCDATA)>]")
      {:ok, %FnXML.DTD.Model{root_element: "note", elements: %{"note" => :pcdata}}}

  """
  @spec parse_doctype(String.t(), keyword()) :: {:ok, Model.t()} | {:error, String.t()}
  def parse_doctype(content, opts \\ []) do
    case parse_doctype_parts(content) do
      {:ok, root_name, external_id, internal_subset} ->
        model = Model.new() |> Model.set_root_element(root_name)

        # Parse external DTD if resolver provided
        model =
          case {external_id, Keyword.get(opts, :external_resolver)} do
            {nil, _} ->
              model

            {_, nil} ->
              model

            {{system_id, public_id}, resolver} ->
              case resolver.(system_id, public_id) do
                {:ok, external_content} ->
                  case Parser.parse(external_content) do
                    {:ok, external_model} -> merge_models(model, external_model)
                    {:error, _} -> model
                  end

                {:error, _} ->
                  model
              end
          end

        # Parse internal subset (takes precedence over external)
        case internal_subset do
          nil ->
            {:ok, model}

          subset ->
            case Parser.parse(subset) do
              {:ok, subset_model} -> {:ok, merge_models(model, subset_model)}
              {:error, _} = err -> err
            end
        end

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Parse DOCTYPE parts: root name, external identifier, and internal subset.

  Returns `{:ok, root_name, external_id, internal_subset}` where:
  - `root_name` is the document element name
  - `external_id` is `nil` or `{system_id, public_id}`
  - `internal_subset` is `nil` or the string content between `[` and `]`
  """
  @spec parse_doctype_parts(String.t()) ::
          {:ok, String.t(), {String.t(), String.t() | nil} | nil, String.t() | nil}
          | {:error, String.t()}
  def parse_doctype_parts(content) do
    content = String.trim(content)

    # Remove "DOCTYPE " prefix
    case content do
      <<"DOCTYPE", rest::binary>> ->
        parse_after_doctype(String.trim(rest))

      _ ->
        {:error, "Expected DOCTYPE declaration"}
    end
  end

  # Parse after "DOCTYPE ": root_name [external_id] [internal_subset]
  defp parse_after_doctype(rest) do
    # Extract root element name
    case Regex.run(~r/^(\S+)(.*)$/s, rest) do
      [_, root_name, remainder] ->
        parse_external_and_subset(String.trim(remainder), root_name)

      nil ->
        {:error, "Expected root element name in DOCTYPE"}
    end
  end

  # Parse external identifier and/or internal subset
  defp parse_external_and_subset("", root_name) do
    {:ok, root_name, nil, nil}
  end

  defp parse_external_and_subset(<<"[", rest::binary>>, root_name) do
    # Internal subset only
    case extract_internal_subset(rest) do
      {:ok, subset} -> {:ok, root_name, nil, subset}
      {:error, _} = err -> err
    end
  end

  defp parse_external_and_subset(<<"SYSTEM", rest::binary>>, root_name) do
    rest = String.trim(rest)

    case extract_quoted_string(rest) do
      {:ok, system_id, remainder} ->
        parse_optional_subset(String.trim(remainder), root_name, {system_id, nil})

      {:error, _} = err ->
        err
    end
  end

  defp parse_external_and_subset(<<"PUBLIC", rest::binary>>, root_name) do
    rest = String.trim(rest)

    case extract_quoted_string(rest) do
      {:ok, public_id, remainder} ->
        remainder = String.trim(remainder)

        case extract_quoted_string(remainder) do
          {:ok, system_id, final_remainder} ->
            parse_optional_subset(String.trim(final_remainder), root_name, {system_id, public_id})

          {:error, _} = err ->
            err
        end

      {:error, _} = err ->
        err
    end
  end

  defp parse_external_and_subset(_, _root_name) do
    {:error, "Invalid DOCTYPE: expected SYSTEM, PUBLIC, or ["}
  end

  # Parse optional internal subset after external identifier
  defp parse_optional_subset("", root_name, external_id) do
    {:ok, root_name, external_id, nil}
  end

  defp parse_optional_subset(<<"[", rest::binary>>, root_name, external_id) do
    case extract_internal_subset(rest) do
      {:ok, subset} -> {:ok, root_name, external_id, subset}
      {:error, _} = err -> err
    end
  end

  defp parse_optional_subset(_, _root_name, _external_id) do
    {:error, "Invalid DOCTYPE: expected [ or end"}
  end

  # Extract content between [ and ]
  defp extract_internal_subset(content) do
    # Find matching ] - need to handle nested < > but not nested [ ]
    case find_closing_bracket(content, 0, 0) do
      {:ok, subset_end} ->
        subset = String.slice(content, 0, subset_end) |> String.trim()
        {:ok, subset}

      :error ->
        {:error, "Unterminated internal subset"}
    end
  end

  # Find the closing ] accounting for nested < > in declarations
  defp find_closing_bracket(<<"]", _::binary>>, pos, 0), do: {:ok, pos}

  defp find_closing_bracket(<<"]", rest::binary>>, pos, depth),
    do: find_closing_bracket(rest, pos + 1, depth - 1)

  defp find_closing_bracket(<<"<", rest::binary>>, pos, depth),
    do: find_closing_bracket(rest, pos + 1, depth + 1)

  defp find_closing_bracket(<<">", rest::binary>>, pos, depth),
    do: find_closing_bracket(rest, pos + 1, max(0, depth - 1))

  defp find_closing_bracket(<<_, rest::binary>>, pos, depth),
    do: find_closing_bracket(rest, pos + 1, depth)

  defp find_closing_bracket(<<>>, _pos, _depth), do: :error

  # Extract a quoted string (single or double quotes)
  defp extract_quoted_string(<<?", rest::binary>>) do
    case :binary.match(rest, "\"") do
      {pos, 1} ->
        value = binary_part(rest, 0, pos)
        remainder = binary_part(rest, pos + 1, byte_size(rest) - pos - 1)
        {:ok, value, remainder}

      :nomatch ->
        {:error, "Unterminated quoted string"}
    end
  end

  defp extract_quoted_string(<<?\', rest::binary>>) do
    case :binary.match(rest, "'") do
      {pos, 1} ->
        value = binary_part(rest, 0, pos)
        remainder = binary_part(rest, pos + 1, byte_size(rest) - pos - 1)
        {:ok, value, remainder}

      :nomatch ->
        {:error, "Unterminated quoted string"}
    end
  end

  defp extract_quoted_string(_) do
    {:error, "Expected quoted string"}
  end

  # Merge two models, second takes precedence
  defp merge_models(base, override) do
    %Model{
      elements: Map.merge(base.elements, override.elements),
      attributes: Map.merge(base.attributes, override.attributes),
      entities: Map.merge(base.entities, override.entities),
      param_entities: Map.merge(base.param_entities, override.param_entities),
      notations: Map.merge(base.notations, override.notations),
      root_element: override.root_element || base.root_element
    }
  end
end
