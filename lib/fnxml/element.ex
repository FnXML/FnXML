defmodule FnXML.Element do
  @moduledoc """
  This module provides functions for working with elements of an XML stream.

  Event formats:
  - `{:start_document, nil}` - Document start marker
  - `{:end_document, nil}` - Document end marker
  - `{:start_element, tag, attrs, loc}` - Opening tag with attributes
  - `{:end_element, tag}` or `{:end_element, tag, loc}` - Closing tag
  - `{:characters, content, loc}` - Text content
  - `{:comment, content, loc}` - Comment
  - `{:prolog, "xml", attrs, loc}` - XML prolog
  - `{:processing_instruction, name, content, loc}` - Processing instruction
  - `{:error, message, loc}` - Parse error
  """

  def id_list(),
    do: [
      :start_document,
      :end_document,
      :prolog,
      :start_element,
      :end_element,
      :characters,
      :comment,
      :processing_instruction,
      :error
    ]

  @doc """
  Given a tag's open/close element, return the tag id as a tuple of
  the form {tag_id, namespace}.

  ## Examples

      iex> FnXML.Element.tag({:start_element, "foo", [], {1, 0, 1}})
      {"foo", ""}

      iex> FnXML.Element.tag({:start_element, "matrix:foo", [], {1, 0, 1}})
      {"foo", "matrix"}

      iex> FnXML.Element.tag({:end_element, "foo"})
      {"foo", ""}
  """
  def tag(id) when is_binary(id) do
    case String.split(id, ":", parts: 2) do
      [tag] -> {tag, ""}
      [ns, tag] -> {tag, ns}
    end
  end

  def tag({:start_element, tag, _attrs, _loc}), do: tag(tag)
  def tag({:end_element, tag}), do: tag(tag)
  def tag({:end_element, tag, _loc}), do: tag(tag)

  @doc """
  Given a tag name tuple returned from the tag function,
  return a string representation of the tag name, which
  includes the namespace.

  ## Examples

      iex> FnXML.Element.tag_name({"foo", ""})
      "foo"

      iex> FnXML.Element.tag_name({"foo", "matrix"})
      "matrix:foo"
  """
  def tag_name({tag, ""}), do: tag
  def tag_name({tag, nil}), do: tag
  def tag_name({tag, namespace}), do: namespace <> ":" <> tag

  @doc """
  Given an open element, return the raw tag string.

  ## Examples

      iex> FnXML.Element.tag_string({:start_element, "foo", [], {1, 0, 1}})
      "foo"

      iex> FnXML.Element.tag_string({:end_element, "bar"})
      "bar"
  """
  def tag_string({:start_element, tag, _attrs, _loc}), do: tag
  def tag_string({:end_element, tag}), do: tag
  def tag_string({:end_element, tag, _loc}), do: tag

  @doc """
  Given an open element, return its list of attributes,
  or an empty list if there are none.

  ## Examples

      iex> FnXML.Element.attributes({:start_element, "foo", [{"bar", "baz"}, {"qux", "quux"}], {1, 0, 1}})
      [{"bar", "baz"}, {"qux", "quux"}]

      iex> FnXML.Element.attributes({:start_element, "foo", [], {1, 0, 1}})
      []
  """
  def attributes({:start_element, _tag, attrs, _loc}), do: attrs
  def attributes({:prolog, _tag, attrs, _loc}), do: attrs

  @doc """
  Same as attributes/1 but returns a map of the attributes instead
  of a list.

  ## Examples

      iex> FnXML.Element.attribute_map({:start_element, "foo", [{"bar", "baz"}, {"qux", "quux"}], {1, 0, 1}})
      %{"bar" => "baz", "qux" => "quux"}
  """
  def attribute_map(element), do: attributes(element) |> Enum.into(%{})

  @doc """
  Given a text or comment element, retrieve the content.

  ## Examples

      iex> FnXML.Element.content({:characters, "hello world", {1, 0, 5}})
      "hello world"

      iex> FnXML.Element.content({:comment, " a comment ", {1, 0, 1}})
      " a comment "
  """
  def content({:characters, content, _loc}), do: content
  def content({:comment, content, _loc}), do: content
  def content({:processing_instruction, _name, content, _loc}), do: content

  @doc """
  Given an element, return a tuple with `{line, column}` position
  of the element in the XML stream.

  ## Examples

      iex> FnXML.Element.position({:start_element, "foo", [], {2, 15, 19}})
      {2, 4}

      iex> FnXML.Element.position({:characters, "hello", {1, 0, 5}})
      {1, 5}
  """
  def position({:start_document, _}), do: {0, 0}
  def position({:end_document, _}), do: {0, 0}
  def position({:start_element, _tag, _attrs, loc}), do: loc_to_position(loc)
  def position({:end_element, _tag, loc}), do: loc_to_position(loc)
  def position({:end_element, _tag}), do: {0, 0}
  def position({:characters, _content, loc}), do: loc_to_position(loc)
  def position({:comment, _content, loc}), do: loc_to_position(loc)
  def position({:prolog, _tag, _attrs, loc}), do: loc_to_position(loc)
  def position({:processing_instruction, _name, _content, loc}), do: loc_to_position(loc)
  def position({:error, _msg, loc}), do: loc_to_position(loc)

  defp loc_to_position(nil), do: {0, 0}
  defp loc_to_position({line, line_start, abs_pos}), do: {line, abs_pos - line_start}

  @doc """
  Given an element, return the raw location tuple `{line, line_start, byte_offset}`.

  ## Examples

      iex> FnXML.Element.loc({:start_element, "foo", [], {2, 15, 19}})
      {2, 15, 19}
  """
  def loc({:start_document, _}), do: nil
  def loc({:end_document, _}), do: nil
  def loc({:start_element, _tag, _attrs, loc}), do: loc
  def loc({:end_element, _tag, loc}), do: loc
  def loc({:end_element, _tag}), do: nil
  def loc({:characters, _content, loc}), do: loc
  def loc({:comment, _content, loc}), do: loc
  def loc({:prolog, _tag, _attrs, loc}), do: loc
  def loc({:processing_instruction, _name, _content, loc}), do: loc
  def loc({:error, _msg, loc}), do: loc
end
