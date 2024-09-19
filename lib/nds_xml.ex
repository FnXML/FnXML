defmodule FnXML.Stream.NativeDataStruct.Format.XML do
  alias FnXML.Stream.NativeDataStruct, as: NDS

  @behaviour NDS.Formatter

  @doc """
  Emit returns a list of XML stream elements.

  ## Examples

      iex> data = %{"a" => "hi", "b" => %{"info" => "info", a: 1, b: 1}, c: "hi", d: 4}
      iex> nds = NDS.Encoder.encode(data, [tag_from_parent: "foo"])
      iex> NDS.Format.XML.emit(nds)
      [
        open: [tag: "foo", attributes: [{"c", "hi"}, {"d", "4"}]],
        open: [tag: "a"],
        text: [content: "hi"],
        close: [tag: "a"],
        open: [tag: "b", attributes: [{"a", "1"}, {"b",  "1"}]],
        open: [tag: "info"],
        text: [content: "info"],
        close: [tag: "info"],
        close: [tag: "b"],
        close: [tag: "foo"]
      ]      
  """
  @impl NDS.Formatter
  def emit(nds, opts \\ [])
  def emit(%NDS{content: []} = nds, _opts), do: [open_tag(nds) |> close()]

  def emit(%NDS{} = nds, _opts),
    do: [open_tag(nds)] ++ content_list(nds.content) ++ [close_tag(nds)]

  def open_tag(%NDS{tag: tag, namespace: "", attributes: []}), do: {:open, [tag: tag]}

  def open_tag(%NDS{tag: tag, namespace: "", attributes: attrs}),
    do: {:open, [tag: tag, attributes: attrs]}

  def open_tag(%NDS{tag: tag, namespace: namespace, attributes: []}),
    do: {:open, [tag: "#{namespace}:#{tag}"]}

  def open_tag(%NDS{tag: tag, namespace: namespace, attributes: attrs}),
    do: {:open, [tag: "#{namespace}:#{tag}", attributes: attrs]}

  def close({el, [tag | rest]}), do: {el, [tag | [{:close, true} | rest]]}

  def close_tag(%NDS{tag: tag, namespace: ""}), do: {:close, [tag: tag]}
  def close_tag(%NDS{tag: tag, namespace: namespace}), do: {:close, [tag: "#{namespace}:#{tag}"]}

  @doc """
  this iterates over content and generates content elements.  It needs to track the order of the content
  using the order_id_list.  For text items which are lists, it needs to take the first element from the
  list each time that id is referenced.

  ## Examples

      iex> data = %{"a" => ["hello", "world"]}
      iex> nds = [{:child, "a", NDS.Encoder.encode(data, [tag_from_parent: "foo"])}]
      iex> NDS.Format.XML.content_list(nds)
      [
        {:open, [tag: "foo"]},
        {:open, [tag: "a"]},
        {:text, [content: "hello"]},
        {:close, [tag: "a"]},
        {:open, [tag: "a"]},
        {:text, [content: "world"]},
        {:close, [tag: "a"]},
        {:close, [tag: "foo"]}
      ]
  """

  def content_list(list) do
    Enum.map(list, &content/1) |> List.flatten()
  end

  def content({:text, _k, text}), do: {:text, [content: text]}
  def content({:child, _k, %NDS{} = nds}), do: emit(nds)
end
