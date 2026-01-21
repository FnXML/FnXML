defmodule FnXML.DOM do
  @moduledoc """
  Document Object Model (DOM) for XML.

  Provides an in-memory tree representation of XML documents with APIs
  inspired by the W3C DOM specification. The DOM loads the entire document
  into memory, enabling random access and modification of any node.

  ## Specifications

  - W3C DOM Level 1 Core: https://www.w3.org/TR/REC-DOM-Level-1/
  - W3C DOM Level 2 Core: https://www.w3.org/TR/DOM-Level-2-Core/

  ## Memory Characteristics

  DOM uses O(n) memory where n is the document size. Use `FnXML.SAX` or
  `FnXML.StAX` for large documents where streaming is preferred.

  ## Usage

      # Build DOM from parser stream (recommended)
      doc = FnXML.parse_stream("<root><child id='1'>text</child></root>")
            |> FnXML.DOM.build()
      doc.root.tag  # => "root"

      # With validation/transformation pipeline
      doc = FnXML.parse_stream(xml)
            |> FnXML.Validate.well_formed()
            |> FnXML.Namespaces.resolve()
            |> FnXML.DOM.build()

      # Quick parse (convenience, skips pipeline)
      doc = FnXML.DOM.parse("<root><child id='1'>text</child></root>")

      # Serialize back to XML
      FnXML.DOM.to_string(doc)  # => "<root><child id=\"1\">text</child></root>"

  ## Node Types

  The DOM uses these node type constants (compatible with W3C DOM):

  - `element_node/0` (1) - Element nodes
  - `text_node/0` (3) - Text content
  - `cdata_node/0` (4) - CDATA sections
  - `comment_node/0` (8) - Comments
  - `document_node/0` (9) - Document root
  - `document_fragment_node/0` (11) - Document fragments

  ## Related Modules

  - `FnXML.DOM.Document` - Document struct and operations
  - `FnXML.DOM.Element` - Element struct and operations
  - `FnXML.DOM.Builder` - Build DOM from events
  - `FnXML.DOM.Serializer` - Convert DOM to XML

  ## Comparison with SimpleForm

  `FnXML.DOM` uses structs while `FnXML.Stream.SimpleForm` uses tuples:

      # DOM
      %FnXML.DOM.Element{tag: "div", attributes: [{"id", "1"}], children: ["text"]}

      # SimpleForm
      {"div", [{"id", "1"}], ["text"]}

  DOM provides richer functionality (namespace support, element methods),
  while SimpleForm is simpler and compatible with the Saxy library.
  """

  alias FnXML.DOM.{Builder, Document, Element, Serializer}

  # Node type constants (W3C DOM compatible)
  @element_node 1
  @text_node 3
  @cdata_node 4
  @comment_node 8
  @document_node 9
  @document_fragment_node 11

  @doc "Node type constant for elements (1)"
  def element_node, do: @element_node

  @doc "Node type constant for text (3)"
  def text_node, do: @text_node

  @doc "Node type constant for CDATA sections (4)"
  def cdata_node, do: @cdata_node

  @doc "Node type constant for comments (8)"
  def comment_node, do: @comment_node

  @doc "Node type constant for documents (9)"
  def document_node, do: @document_node

  @doc "Node type constant for document fragments (11)"
  def document_fragment_node, do: @document_fragment_node

  @doc """
  Parse XML string to DOM Document.

  ## Options

  - `:include_comments` - Include comment nodes (default: false)
  - `:include_prolog` - Parse XML declaration (default: true)

  ## Examples

      iex> doc = FnXML.DOM.parse("<root><child>text</child></root>")
      iex> doc.root.tag
      "root"

      iex> doc = FnXML.DOM.parse("<?xml version='1.0'?><root/>")
      iex> FnXML.DOM.Document.version(doc)
      "1.0"
  """
  @spec parse(String.t(), keyword()) :: Document.t()
  defdelegate parse(xml, opts \\ []), to: Builder

  @doc """
  Parse XML string to DOM Document, raising on error.
  """
  @spec parse!(String.t(), keyword()) :: Document.t()
  defdelegate parse!(xml, opts \\ []), to: Builder

  @doc """
  Build DOM from an FnXML event stream.

  This is the primary way to create a DOM from parsed XML, enabling
  stream transformations before building the tree.

  ## Options

  - `:include_comments` - Include comment nodes (default: false)
  - `:include_prolog` - Parse XML declaration (default: true)

  ## Examples

      iex> FnXML.parse_stream("<root>text</root>")
      ...> |> FnXML.DOM.build()
      ...> |> then(& &1.root.tag)
      "root"

      # With validation
      FnXML.parse_stream(xml)
      |> FnXML.Validate.well_formed()
      |> FnXML.DOM.build()

      # With namespace resolution
      FnXML.parse_stream(xml)
      |> FnXML.Namespaces.resolve()
      |> FnXML.DOM.build()
  """
  @spec build(Enumerable.t(), keyword()) :: Document.t()
  def build(stream, opts \\ []) do
    Builder.from_stream(stream, opts)
  end

  @doc """
  Serialize DOM to XML string.

  ## Options

  - `:pretty` - Format with indentation (default: false)
  - `:indent` - Indentation string or spaces count (default: 2)
  - `:xml_declaration` - Include XML declaration (default: false)

  ## Examples

      iex> doc = FnXML.DOM.parse("<root><child/></root>")
      iex> FnXML.DOM.to_string(doc)
      "<root><child/></root>"

      iex> doc = FnXML.DOM.parse("<root><child/></root>")
      iex> FnXML.DOM.to_string(doc, pretty: true)
      "<root>\\n  <child/>\\n</root>"
  """
  @spec to_string(Document.t() | Element.t(), keyword()) :: String.t()
  defdelegate to_string(node, opts \\ []), to: Serializer

  @doc """
  Convert DOM to iodata (more efficient for large documents).
  """
  @spec to_iodata(Document.t() | Element.t(), keyword()) :: iodata()
  defdelegate to_iodata(node, opts \\ []), to: Serializer

  @doc """
  Convert DOM to an FnXML event stream.

  Useful for piping DOM through stream transformations.

  ## Examples

      iex> FnXML.DOM.parse("<root>text</root>")
      ...> |> FnXML.DOM.to_stream()
      ...> |> Enum.to_list()
      ...> |> Enum.map(&elem(&1, 0))
      [:start_element, :characters, :end_element]
  """
  @spec to_stream(Document.t() | Element.t()) :: Enumerable.t()
  defdelegate to_stream(node), to: Serializer

  # Convenience aliases for creating nodes

  @doc """
  Create a new element.

  ## Examples

      iex> FnXML.DOM.element("div", [{"class", "container"}], ["Hello"])
      %FnXML.DOM.Element{tag: "div", attributes: [{"class", "container"}], children: ["Hello"]}
  """
  @spec element(String.t(), [{String.t(), String.t()}], [Element.child()]) :: Element.t()
  def element(tag, attributes \\ [], children \\ []) do
    Element.new(tag, attributes, children)
  end

  @doc """
  Create a new document.

  ## Examples

      iex> root = FnXML.DOM.element("html")
      iex> doc = FnXML.DOM.document(root)
      iex> doc.root.tag
      "html"
  """
  @spec document(Element.t(), keyword()) :: Document.t()
  def document(root, opts \\ []) do
    Document.new(root, opts)
  end
end
