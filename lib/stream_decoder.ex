defmodule FnXML.Stream.Decoder do

  @moduledoc """
  A simple XML stream decoder, implemented using behaviours.
  """

  @callback handle_open(meta :: list, path :: list, acc :: list, opts :: list) :: list
  @callback handle_text(text :: binary, path :: list, acc :: list, opts :: list) :: list
  @callback handle_close(meta :: list, path :: list, acc :: list, opts :: list) :: list

  def decode(stream, module \\ FnXML.Stream.Decoder.Default, opts \\ []) do
    # the fn map creates callback functions for the module which include the options.
    fn_map = %{
      open_fn: fn element, path, acc -> module.handle_open(element, path, acc, opts) end,
      text_fn: fn element, path, acc -> module.handle_text(element, path, acc, opts) end,
      close_fn: fn element, path, acc -> module.handle_close(element, path, acc, opts) end,
    }
    
    stream |> FnXML.Stream.transform(decode_fn(fn_map))
  end

  def decode_fn(fn_map) do
    fn element, path, acc -> decode_element(element, path, acc, fn_map) end
  end

  def decode_element(element, path, acc, fn_map)

  def decode_element({:open, meta}, path, acc, fn_map), do: fn_map.open_fn.(meta, path, acc)

  def decode_element({:text, [text | _]}, path, acc, fn_map), do: fn_map.text_fn.(text, path, acc)

  def decode_element({:close, meta}, path, acc, fn_map), do: fn_map.close_fn.(meta, path, acc)
end


defmodule FnXML.Stream.Decoder.Default do
  @moduledoc """
  Default implementation of the stream decoder behaviour.
  """
  @behaviour FnXML.Stream.Decoder

  @impl true
  @doc """
  pushes the current element on to the accumulator
  """
  def handle_open(meta, _path, acc, _opts), do: [meta |> Enum.reverse() | acc]

  @impl true
  @doc """
  pushes the current text on to the top element of the accumulator
  """
  def handle_text(text, _path, [h | t], _opts), do: [[{:text, text} | h] | t]

  @impl true
  @doc """
  case 1: only one element on the stack, reverse the element and return it
  case 2: more than one element on the stack, reverse the top element and add it to the second element
  """
  def handle_close(_meta, _path, [h], _opts), do: {h |> Enum.reverse(), []}
  def handle_close(_meta, _path, [h, p | anc], _opts), do: [[{:child, h |> Enum.reverse()} | p] | anc ]
end
