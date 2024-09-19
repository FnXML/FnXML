defmodule FnXML.Parser do
  @moduledoc """
  XML Parser: This parser emits a stream of XML tags and text.

  This parser attempts to follow the spcification at: https://www.w3.org/TR/xml

  It is designed to be used with Streams.  The parser emits 3 different types of items:
  {:open, [... open tag data...]}
  {:close, [... close tag data...]}
  {:text, [... text data...]}

  These are available as a stream of items which can be processed by other stream functions.
  """
  import NimbleParsec

  alias FnXML.Parser.Element

  @doc """
  Basic XML Parser, parses to a stream of tags and text.  This makes it possible to process XML as a stream.
  """

  defparsec(:prolog, optional(Element.prolog()))

  defparsec(:next_element, Element.next())

  def parse_prolog(xml) do
    case prolog(xml) do
      {:ok, [prolog], xml, %{}, line, abs_char} -> {[prolog], xml, line, abs_char}
      {:ok, [], xml, %{}, line, abs_char} -> {xml, line, abs_char}
    end
  end

  def parse_next({"", line, abs_char}), do: {:halt, {"", line, abs_char}}

  def parse_next({xml, line, abs_char}) do
    {:ok, [{id, meta} | elements] = items, rest, _, line, abs_char} =
      next_element__0(xml, [], [], [], line, abs_char)

    state = {rest, line, abs_char}

    # Note about the following logic:
    #   XML has a special notation for an empty tag: "<a/>" which is equivalent to "<a></a>".
    #   My choice here is to always emit the empty tag as "<a></a>" because it removes
    #   special case logic from the code downstream.  Code that formats XML can easily
    #   detect and emit "<a/>" if it wants to.
    if id == :open and Keyword.get(meta, :close, false) do
      tag = Keyword.get(meta, :tag)
      new_meta = Enum.filter(meta, fn {k, _} -> k != :close end)

      {[{:open, new_meta}, {:close, [tag: tag]} | elements], state}
    else
      {items, state}
    end
  end

  def parse_next({[prolog], xml, line, abs_char}) do
    {:ok, next_item, rest, _, line, abs_char} = next_element__0(xml, [], [], [], line, abs_char)
    {[prolog | next_item], {rest, line, abs_char}}
  end

  def parse(xml), do: Stream.resource(fn -> parse_prolog(xml) end, &parse_next/1, fn _ -> :ok end)
end
