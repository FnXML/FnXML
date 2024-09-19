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

  def handle_close(_meta, _path, [h, p | anc], _opts),
    do: [[{:child, h |> Enum.reverse()} | p] | anc]

  @impl true
  def handle_prolog(_meta, _path, acc, _opts), do: acc

  @impl true
  def handle_comment(_meta, _path, acc, _opts), do: acc

  @impl true
  def handle_proc_inst(_meta, _path, acc, _opts), do: acc
end
