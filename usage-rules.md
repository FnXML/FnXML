# FnXML Usage Rules for LLMs

Concise rules for using the FnXML library correctly.

## API Selection

| Scenario | Use This |
|----------|----------|
| Build tree, query/modify nodes | `FnXML.DOM` |
| Large file, extract specific data | `FnXML.SAX` |
| Large file, stateful processing | `FnXML.StAX` |
| Custom stream transformations | `FnXML.Parser` + `FnXML.Stream` |

## DOM Rules

```elixir
# CORRECT: Parse and access
doc = FnXML.DOM.parse(xml_string)
doc.root.tag
doc.root.children
FnXML.DOM.Element.get_attribute(element, "attr_name")

# CORRECT: Serialize
FnXML.DOM.to_string(doc)
FnXML.DOM.to_string(doc, pretty: true)

# CORRECT: Build elements
FnXML.DOM.Element.new("tag", [{"attr", "val"}], ["child text"])
```

**Memory:** O(n) - entire document in memory

## SAX Rules

```elixir
# CORRECT: Define handler module
defmodule MyHandler do
  use FnXML.SAX.Handler  # Provides default implementations

  @impl true
  def start_element(_uri, local_name, _qname, _attrs, state) do
    {:ok, new_state}  # Must return {:ok, state}, {:halt, state}, or {:error, reason}
  end
end

# CORRECT: Parse with handler
{:ok, final_state} = FnXML.SAX.parse(xml, MyHandler, initial_state)

# CORRECT: Parse with options
FnXML.SAX.parse(xml, MyHandler, state, namespaces: true)
```

**Callbacks (all receive state, return `{:ok, state}`):**
- `start_document(state)`
- `end_document(state)`
- `start_element(uri, local_name, qname, attrs, state)`
- `end_element(uri, local_name, qname, state)`
- `characters(text, state)`

**Early termination:** Return `{:halt, state}` from any callback

**Memory:** O(1) - streaming

## StAX Rules

```elixir
# CORRECT: Create reader and pull events
reader = FnXML.StAX.Reader.new(xml_string)
reader = FnXML.StAX.Reader.next(reader)  # Must call next() to advance

# CORRECT: Check event type before accessing data
if FnXML.StAX.Reader.start_element?(reader) do
  name = FnXML.StAX.Reader.local_name(reader)
  attr = FnXML.StAX.Reader.attribute_value(reader, nil, "id")
end

# CORRECT: Iteration pattern
defp process(reader) do
  if FnXML.StAX.Reader.has_next?(reader) do
    reader = FnXML.StAX.Reader.next(reader)
    # process current event...
    process(reader)
  else
    reader
  end
end

# CORRECT: Get all text in element
{text, reader} = FnXML.StAX.Reader.element_text(reader)

# CORRECT: Writer usage
xml = FnXML.StAX.Writer.new()
|> FnXML.StAX.Writer.start_element("root")
|> FnXML.StAX.Writer.attribute("id", "1")  # Attributes before content
|> FnXML.StAX.Writer.characters("text")
|> FnXML.StAX.Writer.end_element()
|> FnXML.StAX.Writer.to_string()
```

**Event types:** `:start_element`, `:end_element`, `:characters`, `:comment`, `:cdata`, `:processing_instruction`, `:end_document`

**Memory:** O(1) - lazy stream

## Low-Level Stream Rules

```elixir
# CORRECT: Get event stream
stream = FnXML.Parser.parse(xml_string)

# CORRECT: With namespaces
stream = FnXML.Parser.parse(xml_string) |> FnXML.Namespaces.resolve()

# CORRECT: Convert to XML
xml = stream |> FnXML.Stream.to_xml() |> Enum.join()

# Event tuple formats (W3C StAX-compatible):
{:start_element, "tag", [{"attr", "val"}], {line, line_start, byte_offset}}
{:end_element, "tag", {line, line_start, byte_offset}}
{:characters, "content", location}
{:comment, "content", location}
{:cdata, "content", location}

# With namespace resolution, tag becomes tuple:
{:start_element, {"http://ns.uri", "local_name"}, attrs, location}
```

## SimpleForm (Saxy Compatibility)

```elixir
# Tuple format: {tag, attrs, children}
{"root", [{"id", "1"}], ["text", {"child", [], []}]}

# CORRECT: Parse to SimpleForm
simple = FnXML.Stream.SimpleForm.decode(xml_string)

# CORRECT: Encode to XML
xml = FnXML.Stream.SimpleForm.encode(simple_form_tuple)

# CORRECT: Convert to/from DOM
element = FnXML.Stream.SimpleForm.to_dom(simple_form_tuple)
tuple = FnXML.Stream.SimpleForm.from_dom(element)
```

## Common Mistakes

```elixir
# WRONG: Accessing reader without calling next()
reader = FnXML.StAX.Reader.new(xml)
FnXML.StAX.Reader.local_name(reader)  # Returns nil!

# CORRECT: Call next() first
reader = FnXML.StAX.Reader.new(xml)
reader = FnXML.StAX.Reader.next(reader)
FnXML.StAX.Reader.local_name(reader)  # Works

# WRONG: SAX handler not returning proper tuple
def start_element(_, _, _, _, state) do
  state  # Missing {:ok, ...} wrapper!
end

# CORRECT: Return {:ok, state}
def start_element(_, _, _, _, state) do
  {:ok, state}
end

# WRONG: Writer attributes after content
writer
|> FnXML.StAX.Writer.start_element("root")
|> FnXML.StAX.Writer.characters("text")
|> FnXML.StAX.Writer.attribute("id", "1")  # Too late!

# CORRECT: Attributes immediately after start_element
writer
|> FnXML.StAX.Writer.start_element("root")
|> FnXML.StAX.Writer.attribute("id", "1")
|> FnXML.StAX.Writer.characters("text")
```

## Namespace Handling

```elixir
# SAX with namespaces (default: true)
FnXML.SAX.parse(xml, Handler, state, namespaces: true)
# Handler receives: start_element("http://ns", "local", "prefix:local", attrs, state)

# SAX without namespaces
FnXML.SAX.parse(xml, Handler, state, namespaces: false)
# Handler receives: start_element(nil, "prefix:local", "prefix:local", attrs, state)

# StAX with namespaces
reader = FnXML.StAX.Reader.new(xml, namespaces: true)
FnXML.StAX.Reader.namespace_uri(reader)  # => "http://ns"

# Low-level with namespaces
FnXML.Parser.parse(xml) |> FnXML.Namespaces.resolve()
```

## Performance Guidelines

1. **Large files (>10MB):** Use SAX or StAX, not DOM
2. **Extract single value:** SAX with `{:halt, value}`
3. **Complex state machine:** StAX with explicit control flow
4. **Transform and output:** Low-level stream pipeline
5. **Small files with queries:** DOM for convenience
