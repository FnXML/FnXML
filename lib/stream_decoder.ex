defmodule FnXML.Stream.Decoder do

  @moduledoc """
  A simple XML stream decoder, implemented using behaviours.
  """

  @callback handle_prolog(meta :: list, path :: list, acc :: list, opts :: list) :: list
  @callback handle_open(meta :: list, path :: list, acc :: list, opts :: list) :: list
  @callback handle_close(meta :: list, path :: list, acc :: list, opts :: list) :: list
  @callback handle_text(meta :: list, path :: list, acc :: list, opts :: list) :: list
  @callback handle_comment(meta :: list, path :: list, acc :: list, opts :: list) :: list
  @callback handle_proc_inst(meta :: list, path :: list, acc :: list, opts :: list) :: list

  def decode(stream, module \\ FnXML.Stream.Decoder.Default, opts \\ []) do
    FnXML.Stream.transform(stream, fn
      {id, meta}, path, acc -> apply(module, :"handle_#{id}", [meta, path, acc, opts])
    end)
  end
end
