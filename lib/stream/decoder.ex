defmodule FnXML.Stream.Decoder do
  @moduledoc """
  A simple XML stream decoder, implemented using behaviours.

  The decoder accepts parser format (flat position) events as input and passes them to callbacks.

  ## Callback Event Formats

  Callbacks receive events in parser format with flat position parameters:

  - `{:start_element, tag, attrs, line, ls, pos}` - Opening tag
  - `{:end_element, tag, line, ls, pos}` - Closing tag
  - `{:characters, content, line, ls, pos}` - Text content
  - `{:comment, content, line, ls, pos}` - Comment
  - `{:prolog, "xml", attrs, line, ls, pos}` - XML prolog
  - `{:processing_instruction, name, content, line, ls, pos}` - Processing instruction

  ## Implementing a Decoder

  Implement the behaviour callbacks to process XML events:

      defmodule MyDecoder do
        @behaviour FnXML.Stream.Decoder

        @impl true
        def handle_open({:start_element, tag, attrs, _loc}, path, acc, _opts) do
          # Process opening tag
          acc
        end

        @impl true
        def handle_close(_elem, _path, acc, _opts), do: acc

        @impl true
        def handle_text({:characters, content, _loc}, _path, acc, _opts), do: acc

        # ... other callbacks
      end

  ## Usage

      FnXML.Parser.parse(xml)
      |> FnXML.Stream.Decoder.decode(MyDecoder, opts)
      |> Enum.to_list()
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

      # 6-tuple prolog (from parser)
      {:prolog, tag, attrs, line, ls, pos} = elem, path, acc ->
        module.handle_prolog(elem, path, acc, opts)

      # 6-tuple start_element (from parser)
      {:start_element, tag, attrs, line, ls, pos} = elem, path, acc ->
        module.handle_open(elem, path, acc, opts)

      # 5-tuple end_element (from parser)
      {:end_element, tag, line, ls, pos} = elem, path, acc ->
        module.handle_close(elem, path, acc, opts)

      # 2-tuple end_element (legacy format with no position)
      {:end_element, _} = elem, path, acc ->
        module.handle_close(elem, path, acc, opts)

      # 5-tuple characters (from parser)
      {:characters, content, line, ls, pos} = elem, path, acc ->
        module.handle_text(elem, path, acc, opts)

      # 5-tuple comment (from parser)
      {:comment, content, line, ls, pos} = elem, path, acc ->
        module.handle_comment(elem, path, acc, opts)

      # 6-tuple processing_instruction (from parser)
      {:processing_instruction, name, content, line, ls, pos} = elem, path, acc ->
        module.handle_proc_inst(elem, path, acc, opts)

      # Ignore other events (space, cdata, dtd, etc.)
      _, _path, acc ->
        acc
    end)
  end
end
