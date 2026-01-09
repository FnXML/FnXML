defmodule FnXML.DTD.Parser do
  @moduledoc """
  Parse DTD (Document Type Definition) declarations.

  This module provides functions to parse DTD declarations from strings,
  producing structured data that can be added to a `FnXML.DTD.Model`.

  ## Supported Declarations

  ### Element Declarations

      <!ELEMENT name EMPTY>
      <!ELEMENT name ANY>
      <!ELEMENT name (#PCDATA)>
      <!ELEMENT name (child1, child2)>
      <!ELEMENT name (child1 | child2)>
      <!ELEMENT name (#PCDATA | child)*>

  ### Entity Declarations

      <!ENTITY name "value">
      <!ENTITY name SYSTEM "uri">
      <!ENTITY name PUBLIC "pubid" "uri">
      <!ENTITY % name "value">

  ### Attribute List Declarations

      <!ATTLIST element attr CDATA #REQUIRED>
      <!ATTLIST element attr (a|b|c) "default">

  ## Examples

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT note EMPTY>")
      {:ok, {"note", :empty}}

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT note (to, from, body)>")
      {:ok, {"note", {:seq, ["to", "from", "body"]}}}

  """

  alias FnXML.DTD.Model

  @type parse_result :: {:ok, term()} | {:error, String.t()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Parse a complete DTD string into a Model.

  ## Examples

      iex> dtd = \"\"\"
      ...> <!ELEMENT note (to, from, body)>
      ...> <!ELEMENT to (#PCDATA)>
      ...> <!ELEMENT from (#PCDATA)>
      ...> <!ELEMENT body (#PCDATA)>
      ...> \"\"\"
      iex> {:ok, model} = FnXML.DTD.Parser.parse(dtd)
      iex> model.elements["note"]
      {:seq, ["to", "from", "body"]}

  """
  @spec parse(String.t()) :: {:ok, Model.t()} | {:error, String.t()}
  def parse(dtd_string) when is_binary(dtd_string) do
    dtd_string
    |> extract_declarations()
    |> Enum.reduce_while({:ok, Model.new()}, fn decl, {:ok, model} ->
      case parse_declaration(decl) do
        {:ok, {:element, name, content_model}} ->
          {:cont, {:ok, Model.add_element(model, name, content_model)}}

        {:ok, {:entity, name, definition}} ->
          {:cont, {:ok, Model.add_entity(model, name, definition)}}

        {:ok, {:param_entity, name, value}} ->
          {:cont, {:ok, Model.add_param_entity(model, name, value)}}

        {:ok, {:attlist, element_name, attr_defs}} ->
          {:cont, {:ok, Model.add_attributes(model, element_name, attr_defs)}}

        {:ok, {:notation, name, system_id, public_id}} ->
          {:cont, {:ok, Model.add_notation(model, name, system_id, public_id)}}

        {:ok, :skip} ->
          {:cont, {:ok, model}}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  @doc """
  Parse a single DTD declaration.

  Returns a tagged tuple indicating the declaration type:
  - `{:element, name, content_model}`
  - `{:entity, name, definition}`
  - `{:param_entity, name, value}`
  - `{:attlist, element_name, [attr_def]}`
  - `{:notation, name, system_id, public_id}`
  """
  @spec parse_declaration(String.t()) :: {:ok, term()} | {:error, String.t()}
  def parse_declaration(decl) when is_binary(decl) do
    trimmed = String.trim(decl)

    cond do
      String.starts_with?(trimmed, "<!ELEMENT") ->
        parse_element(trimmed)

      String.starts_with?(trimmed, "<!ENTITY") ->
        parse_entity(trimmed)

      String.starts_with?(trimmed, "<!ATTLIST") ->
        parse_attlist(trimmed)

      String.starts_with?(trimmed, "<!NOTATION") ->
        parse_notation(trimmed)

      trimmed == "" or String.starts_with?(trimmed, "<!--") ->
        {:ok, :skip}

      true ->
        {:error, "Unknown declaration: #{String.slice(trimmed, 0, 50)}..."}
    end
  end

  @doc """
  Parse an ELEMENT declaration.

  ## Examples

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT br EMPTY>")
      {:ok, {:element, "br", :empty}}

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT container ANY>")
      {:ok, {:element, "container", :any}}

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT p (#PCDATA)>")
      {:ok, {:element, "p", :pcdata}}

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT note (to, from)>")
      {:ok, {:element, "note", {:seq, ["to", "from"]}}}

      iex> FnXML.DTD.Parser.parse_element("<!ELEMENT choice (a | b | c)>")
      {:ok, {:element, "choice", {:choice, ["a", "b", "c"]}}}

  """
  @spec parse_element(String.t()) ::
          {:ok, {:element, String.t(), Model.content_model()}} | {:error, String.t()}
  def parse_element(decl) do
    # Remove <!ELEMENT and trailing >
    case Regex.run(~r/^<!ELEMENT\s+(\S+)\s+(.+)>$/s, String.trim(decl)) do
      [_, name, content_spec] ->
        case parse_content_model(String.trim(content_spec)) do
          {:ok, model} -> {:ok, {:element, name, model}}
          {:error, _} = err -> err
        end

      nil ->
        {:error, "Invalid ELEMENT declaration: #{decl}"}
    end
  end

  @doc """
  Parse a content model specification.

  ## Examples

      iex> FnXML.DTD.Parser.parse_content_model("EMPTY")
      {:ok, :empty}

      iex> FnXML.DTD.Parser.parse_content_model("ANY")
      {:ok, :any}

      iex> FnXML.DTD.Parser.parse_content_model("(#PCDATA)")
      {:ok, :pcdata}

      iex> FnXML.DTD.Parser.parse_content_model("(a, b, c)")
      {:ok, {:seq, ["a", "b", "c"]}}

      iex> FnXML.DTD.Parser.parse_content_model("(a | b)")
      {:ok, {:choice, ["a", "b"]}}

      iex> FnXML.DTD.Parser.parse_content_model("(a, b)*")
      {:ok, {:zero_or_more, {:seq, ["a", "b"]}}}

  """
  @spec parse_content_model(String.t()) :: {:ok, Model.content_model()} | {:error, String.t()}
  def parse_content_model("EMPTY"), do: {:ok, :empty}
  def parse_content_model("ANY"), do: {:ok, :any}

  def parse_content_model(spec) do
    spec = String.trim(spec)

    cond do
      spec == "(#PCDATA)" ->
        {:ok, :pcdata}

      String.starts_with?(spec, "(#PCDATA") and String.ends_with?(spec, ")*") ->
        # Mixed content: (#PCDATA | a | b)*
        parse_mixed_content(spec)

      String.starts_with?(spec, "(") ->
        parse_group(spec)

      true ->
        {:error, "Invalid content model: #{spec}"}
    end
  end

  @doc """
  Parse an ENTITY declaration.

  ## Examples

      iex> FnXML.DTD.Parser.parse_entity("<!ENTITY copyright \\"(c) 2024\\">")
      {:ok, {:entity, "copyright", {:internal, "(c) 2024"}}}

      iex> FnXML.DTD.Parser.parse_entity("<!ENTITY logo SYSTEM \\"logo.gif\\">")
      {:ok, {:entity, "logo", {:external, "logo.gif", nil}}}

      iex> FnXML.DTD.Parser.parse_entity("<!ENTITY % colors \\"red | green | blue\\">")
      {:ok, {:param_entity, "colors", "red | green | blue"}}

  """
  @spec parse_entity(String.t()) :: {:ok, term()} | {:error, String.t()}
  def parse_entity(decl) do
    trimmed = String.trim(decl)

    cond do
      # Parameter entity: <!ENTITY % name "value">
      match = Regex.run(~r/^<!ENTITY\s+%\s+(\S+)\s+["'](.*)["']>$/s, trimmed) ->
        [_, name, value] = match
        {:ok, {:param_entity, name, value}}

      # Internal entity: <!ENTITY name "value">
      match = Regex.run(~r/^<!ENTITY\s+(\S+)\s+["'](.*)["']>$/s, trimmed) ->
        [_, name, value] = match
        {:ok, {:entity, name, {:internal, value}}}

      # External SYSTEM entity: <!ENTITY name SYSTEM "uri">
      match = Regex.run(~r/^<!ENTITY\s+(\S+)\s+SYSTEM\s+["']([^"']+)["']>$/s, trimmed) ->
        [_, name, system_id] = match
        {:ok, {:entity, name, {:external, system_id, nil}}}

      # External PUBLIC entity: <!ENTITY name PUBLIC "pubid" "uri">
      match =
          Regex.run(
            ~r/^<!ENTITY\s+(\S+)\s+PUBLIC\s+["']([^"']+)["']\s+["']([^"']+)["']>$/s,
            trimmed
          ) ->
        [_, name, public_id, system_id] = match
        {:ok, {:entity, name, {:external, system_id, public_id}}}

      # External entity with NDATA: <!ENTITY name SYSTEM "uri" NDATA notation>
      match =
          Regex.run(~r/^<!ENTITY\s+(\S+)\s+SYSTEM\s+["']([^"']+)["']\s+NDATA\s+(\S+)>$/s, trimmed) ->
        [_, name, system_id, notation] = match
        {:ok, {:entity, name, {:external_unparsed, system_id, nil, notation}}}

      true ->
        {:error, "Invalid ENTITY declaration: #{decl}"}
    end
  end

  @doc """
  Parse an ATTLIST declaration.

  ## Examples

      iex> FnXML.DTD.Parser.parse_attlist("<!ATTLIST note id ID #REQUIRED>")
      {:ok, {:attlist, "note", [%{name: "id", type: :id, default: :required}]}}

      iex> FnXML.DTD.Parser.parse_attlist("<!ATTLIST img src CDATA #REQUIRED alt CDATA #IMPLIED>")
      {:ok, {:attlist, "img", [%{name: "src", type: :cdata, default: :required}, %{name: "alt", type: :cdata, default: :implied}]}}

  """
  @spec parse_attlist(String.t()) ::
          {:ok, {:attlist, String.t(), [Model.attr_def()]}} | {:error, String.t()}
  def parse_attlist(decl) do
    # Remove <!ATTLIST and trailing >
    case Regex.run(~r/^<!ATTLIST\s+(\S+)\s+(.+)>$/s, String.trim(decl)) do
      [_, element_name, attr_specs] ->
        case parse_attr_defs(String.trim(attr_specs)) do
          {:ok, attrs} -> {:ok, {:attlist, element_name, attrs}}
          {:error, _} = err -> err
        end

      nil ->
        {:error, "Invalid ATTLIST declaration: #{decl}"}
    end
  end

  @doc """
  Parse a NOTATION declaration.
  """
  @spec parse_notation(String.t()) ::
          {:ok, {:notation, String.t(), String.t() | nil, String.t() | nil}}
          | {:error, String.t()}
  def parse_notation(decl) do
    trimmed = String.trim(decl)

    cond do
      # SYSTEM notation
      match = Regex.run(~r/^<!NOTATION\s+(\S+)\s+SYSTEM\s+["']([^"']+)["']>$/s, trimmed) ->
        [_, name, system_id] = match
        {:ok, {:notation, name, system_id, nil}}

      # PUBLIC notation with SYSTEM
      match =
          Regex.run(
            ~r/^<!NOTATION\s+(\S+)\s+PUBLIC\s+["']([^"']+)["']\s+["']([^"']+)["']>$/s,
            trimmed
          ) ->
        [_, name, public_id, system_id] = match
        {:ok, {:notation, name, system_id, public_id}}

      # PUBLIC notation without SYSTEM
      match = Regex.run(~r/^<!NOTATION\s+(\S+)\s+PUBLIC\s+["']([^"']+)["']>$/s, trimmed) ->
        [_, name, public_id] = match
        {:ok, {:notation, name, nil, public_id}}

      true ->
        {:error, "Invalid NOTATION declaration: #{decl}"}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  # Extract individual declarations from a DTD string
  defp extract_declarations(dtd_string) do
    # Match declarations like <!ELEMENT ...>, <!ENTITY ...>, etc.
    Regex.scan(~r/<![A-Z]+[^>]*>/, dtd_string)
    |> List.flatten()
  end

  # Parse mixed content: (#PCDATA | a | b | c)*
  defp parse_mixed_content(spec) do
    # Remove outer parens and trailing *
    inner =
      spec
      |> String.trim_leading("(")
      |> String.trim_trailing(")*")
      |> String.trim()

    # Split by | and extract element names (skip #PCDATA)
    elements =
      inner
      |> String.split("|")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "#PCDATA"))

    if Enum.empty?(elements) do
      {:ok, :pcdata}
    else
      {:ok, {:mixed, elements}}
    end
  end

  # Parse a parenthesized group: (a, b, c) or (a | b | c) with optional occurrence
  defp parse_group(spec) do
    # Check for occurrence indicator at end
    {inner, occurrence} = extract_occurrence(spec)

    # Remove outer parens
    inner = inner |> String.trim_leading("(") |> String.trim_trailing(")")

    # Determine if sequence or choice
    result =
      cond do
        String.contains?(inner, ",") and not String.contains?(inner, "|") ->
          items = parse_group_items(inner, ",")
          {:ok, {:seq, items}}

        String.contains?(inner, "|") and not String.contains?(inner, ",") ->
          items = parse_group_items(inner, "|")
          {:ok, {:choice, items}}

        not String.contains?(inner, ",") and not String.contains?(inner, "|") ->
          # Single item
          item = String.trim(inner)
          {:ok, item}

        true ->
          # Mixed operators - need more sophisticated parsing
          parse_complex_group(inner)
      end

    case result do
      {:ok, model} when occurrence != nil ->
        {:ok, {occurrence, model}}

      other ->
        other
    end
  end

  # Extract occurrence indicator (?, *, +) from end of spec
  defp extract_occurrence(spec) do
    spec = String.trim(spec)

    cond do
      String.ends_with?(spec, ")?") ->
        {String.trim_trailing(spec, "?"), :optional}

      String.ends_with?(spec, ")*") ->
        {String.trim_trailing(spec, "*"), :zero_or_more}

      String.ends_with?(spec, ")+") ->
        {String.trim_trailing(spec, "+"), :one_or_more}

      true ->
        {spec, nil}
    end
  end

  # Split group items, respecting nested parens
  defp parse_group_items(inner, separator) do
    inner
    |> split_respecting_parens(separator)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_item/1)
  end

  # Parse a single item which may have occurrence indicator
  defp parse_item(item) do
    item = String.trim(item)

    cond do
      String.ends_with?(item, "?") ->
        {:optional, String.trim_trailing(item, "?")}

      String.ends_with?(item, "*") ->
        {:zero_or_more, String.trim_trailing(item, "*")}

      String.ends_with?(item, "+") ->
        {:one_or_more, String.trim_trailing(item, "+")}

      String.starts_with?(item, "(") ->
        # Nested group
        case parse_group(item) do
          {:ok, model} -> model
          _ -> item
        end

      true ->
        item
    end
  end

  # Split a string by separator, but respect nested parentheses
  defp split_respecting_parens(string, separator) do
    do_split(string, separator, 0, "", [])
  end

  defp do_split("", _sep, _depth, current, acc) do
    Enum.reverse([current | acc])
  end

  defp do_split(<<?(, rest::binary>>, sep, depth, current, acc) do
    do_split(rest, sep, depth + 1, current <> "(", acc)
  end

  defp do_split(<<?), rest::binary>>, sep, depth, current, acc) do
    do_split(rest, sep, depth - 1, current <> ")", acc)
  end

  defp do_split(<<c, rest::binary>>, sep, 0, current, acc) when <<c>> == sep do
    do_split(rest, sep, 0, "", [current | acc])
  end

  defp do_split(<<c, rest::binary>>, sep, depth, current, acc) do
    do_split(rest, sep, depth, current <> <<c>>, acc)
  end

  # Parse complex groups with mixed operators (needs recursive descent)
  defp parse_complex_group(_inner) do
    # For now, return error - full implementation in Phase 4
    {:error, "Complex content models with mixed operators not yet supported"}
  end

  # Parse attribute definitions from the spec after element name
  defp parse_attr_defs(spec) do
    # Simple tokenizer for attribute definitions
    parse_attr_defs_impl(String.trim(spec), [])
  end

  defp parse_attr_defs_impl("", acc), do: {:ok, Enum.reverse(acc)}

  defp parse_attr_defs_impl(spec, acc) do
    case parse_single_attr_def(spec) do
      {:ok, attr_def, rest} ->
        parse_attr_defs_impl(String.trim(rest), [attr_def | acc])

      {:error, _} = err ->
        err
    end
  end

  # Parse a single attribute definition: name type default
  defp parse_single_attr_def(spec) do
    # Extract attribute name
    case Regex.run(~r/^(\S+)\s+(.+)$/s, spec) do
      [_, name, rest] ->
        case parse_attr_type_and_default(String.trim(rest)) do
          {:ok, type, default, remaining} ->
            {:ok, %{name: name, type: type, default: default}, remaining}

          {:error, _} = err ->
            err
        end

      nil ->
        {:error, "Invalid attribute definition: #{spec}"}
    end
  end

  # Parse attribute type and default value
  defp parse_attr_type_and_default(spec) do
    cond do
      # Enumeration type: (a|b|c) ...
      String.starts_with?(spec, "(") ->
        parse_enum_attr(spec)

      # NOTATION type
      String.starts_with?(spec, "NOTATION") ->
        parse_notation_attr(spec)

      # Keyword types
      true ->
        parse_keyword_attr(spec)
    end
  end

  # Parse enumeration attribute: (a|b|c) default
  defp parse_enum_attr(spec) do
    case Regex.run(~r/^\(([^)]+)\)\s+(.+)$/s, spec) do
      [_, values, rest] ->
        enum_values = values |> String.split("|") |> Enum.map(&String.trim/1)

        case parse_attr_default(String.trim(rest)) do
          {:ok, default, remaining} ->
            {:ok, {:enum, enum_values}, default, remaining}

          {:error, _} = err ->
            err
        end

      nil ->
        {:error, "Invalid enumeration attribute: #{spec}"}
    end
  end

  # Parse NOTATION attribute
  defp parse_notation_attr(spec) do
    case Regex.run(~r/^NOTATION\s+\(([^)]+)\)\s+(.+)$/s, spec) do
      [_, notations, rest] ->
        notation_names = notations |> String.split("|") |> Enum.map(&String.trim/1)

        case parse_attr_default(String.trim(rest)) do
          {:ok, default, remaining} ->
            {:ok, {:notation, notation_names}, default, remaining}

          {:error, _} = err ->
            err
        end

      nil ->
        {:error, "Invalid NOTATION attribute: #{spec}"}
    end
  end

  # Parse keyword type attribute: CDATA, ID, IDREF, etc.
  defp parse_keyword_attr(spec) do
    type_keywords = [
      {"IDREFS", :idrefs},
      {"IDREF", :idref},
      {"ID", :id},
      {"ENTITIES", :entities},
      {"ENTITY", :entity},
      {"NMTOKENS", :nmtokens},
      {"NMTOKEN", :nmtoken},
      {"CDATA", :cdata}
    ]

    Enum.find_value(type_keywords, {:error, "Unknown attribute type: #{spec}"}, fn {keyword, type} ->
      if String.starts_with?(spec, keyword) do
        rest = String.trim_leading(spec, keyword) |> String.trim()

        case parse_attr_default(rest) do
          {:ok, default, remaining} ->
            {:ok, type, default, remaining}

          {:error, _} = err ->
            err
        end
      end
    end)
  end

  # Parse attribute default: #REQUIRED, #IMPLIED, #FIXED "value", or "default"
  defp parse_attr_default(spec) do
    cond do
      String.starts_with?(spec, "#REQUIRED") ->
        {:ok, :required, String.trim_leading(spec, "#REQUIRED") |> String.trim()}

      String.starts_with?(spec, "#IMPLIED") ->
        {:ok, :implied, String.trim_leading(spec, "#IMPLIED") |> String.trim()}

      String.starts_with?(spec, "#FIXED") ->
        rest = String.trim_leading(spec, "#FIXED") |> String.trim()

        case extract_quoted_value(rest) do
          {:ok, value, remaining} -> {:ok, {:fixed, value}, remaining}
          {:error, _} = err -> err
        end

      String.starts_with?(spec, "\"") or String.starts_with?(spec, "'") ->
        case extract_quoted_value(spec) do
          {:ok, value, remaining} -> {:ok, {:default, value}, remaining}
          {:error, _} = err -> err
        end

      true ->
        {:error, "Invalid attribute default: #{spec}"}
    end
  end

  # Extract a quoted value from the beginning of a string
  defp extract_quoted_value(spec) do
    case Regex.run(~r/^["']([^"']*)["'](.*)$/s, spec) do
      [_, value, rest] ->
        {:ok, value, String.trim(rest)}

      nil ->
        {:error, "Expected quoted value: #{spec}"}
    end
  end
end
