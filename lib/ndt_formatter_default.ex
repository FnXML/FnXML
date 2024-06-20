defmodule XMLStreamTools.XMLStream.NDT_Formatter do
  alias XMLStreamTools.NativeDataType.Meta, as: NDT_Meta

  @behaviour XMLStreamTools.NativeDataType.Formatter

  @impl XMLStreamTools.NativeDataType.Formatter
  def emit(%NDT_Meta{} = meta) do
   [open_tag(meta) | [content_list(meta) | [close_tag(meta)]]]
  end

  def open_tag(%NDT_Meta{tag: tag, namespace: "", attr_list: []}), do: {:open_tag, [tag: tag]}
  def open_tag(%NDT_Meta{tag: tag, namespace: "", attr_list: attrs}), do: {:open_tag, [tag: tag, attr: attrs]}
  def open_tag(%NDT_Meta{tag: tag, namespace: namespace, attr_list: []}), do: {:open_tag, [tag: tag, namespace: namespace]}
  def open_tag(%NDT_Meta{tag: tag, namespace: namespace, attr_list: attrs}),
    do: {:open_tag, [tag: tag, namespace: namespace, attrs: attrs]}

  def close_tag(%NDT_Meta{tag: tag, namespace: ""}), do: {:close_tag, [tag: tag]}
  def close_tag(%NDT_Meta{tag: tag, namespace: namespace}), do: {:close_tag, [tag: tag, namespace: namespace]}

  def content_list(meta) do
    Enum.reduce(meta.order_id_list, [], fn key, acc -> [content(meta.child_list[key]) | acc] end)
  end

  def content(meta, item) when is_map(item) or is_list(item), do: emit(item)
  def content(meta, item) when is_binary(item), do: {:text, [item]}
end
