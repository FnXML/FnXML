defmodule FnXML.Stream.Decoder do
  @moduledoc """
  A simple XML stream decoder, implemented using behaviours.

  Event formats:
  - `{:start_document, nil}` - Document start marker
  - `{:end_document, nil}` - Document end marker
  - `{:start_element, tag, attrs, loc}` - Opening tag with attributes
  - `{:end_element, tag}` or `{:end_element, tag, loc}` - Closing tag
  - `{:characters, content, loc}` - Text content
  - `{:comment, content, loc}` - Comment
  - `{:prolog, "xml", attrs, loc}` - XML prolog
  - `{:processing_instruction, name, content, loc}` - Processing instruction
  """

  @callback handle_prolog(element :: tuple, path :: list, acc :: list, opts :: list) :: list
  @callback handle_open(element :: tuple, path :: list, acc :: list, opts :: list) :: list
  @callback handle_close(element :: tuple, path :: list, acc :: list, opts :: list) :: list
  @callback handle_text(element :: tuple, path :: list, acc :: list, opts :: list) :: list
  @callback handle_comment(element :: tuple, path :: list, acc :: list, opts :: list) :: list
  @callback handle_proc_inst(element :: tuple, path :: list, acc :: list, opts :: list) :: list

  def decode(stream, module \\ FnXML.Stream.Decoder.Default, opts \\ []) do
    FnXML.Stream.transform(stream, fn
      {:start_document, _}, _path, acc ->
        acc

      {:end_document, _}, _path, acc ->
        acc

      {:prolog, _, _, _} = elem, path, acc ->
        module.handle_prolog(elem, path, acc, opts)

      {:start_element, _, _, _} = elem, path, acc ->
        module.handle_open(elem, path, acc, opts)

      {:end_element, _} = elem, path, acc ->
        module.handle_close(elem, path, acc, opts)

      {:end_element, _, _} = elem, path, acc ->
        module.handle_close(elem, path, acc, opts)

      {:characters, _, _} = elem, path, acc ->
        module.handle_text(elem, path, acc, opts)

      {:comment, _, _} = elem, path, acc ->
        module.handle_comment(elem, path, acc, opts)

      {:processing_instruction, _, _, _} = elem, path, acc ->
        module.handle_proc_inst(elem, path, acc, opts)
    end)
  end
end
