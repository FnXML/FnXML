defmodule Listy do
  @moduledoc """
  Listy is a module which adds functionality to treat items in a listy sort of way.

  typically, each function takes either a listy value or a listy value and an value to update the list with.

  insert, append, push, enqueue all take a listy value and a value to add the the listy value.

  pop and dequeue, all take a listy value and return a tuple with the value removed and the new listy value.

  first, last, and peek all take a listy value and return the first, last, or next value

  if a not list item is passed to a function it is treated as if it were a list of one item.

  lists of one item are always returned as a single item, not a list.
  """
  def insert(nil, elem), do: elem
  def insert([], elem), do: elem
  def insert(item, elem) when not is_list(item), do: [elem, item]
  def insert(list, elem) when is_list(list), do: [elem | list]

  def append(nil, elem), do: elem
  def append([], elem), do: elem
  def append(item, elem) when not is_list(item), do: [item, elem]
  def append(list, elem) when is_list(list), do: list ++ [elem]

  def push(item, elem), do: insert(item, elem)

  def pop(nil), do: {nil, nil}
  def pop(item) when not is_list(item), do: {item, nil}
  def pop([]), do: {nil, nil}
  def pop([h | []]), do: {h, nil}
  def pop([h | [t]]), do: {h, t}
  def pop([h | t]), do: {h, t}

  def first(nil), do: nil
  def first([]), do: nil
  def first(item) when not is_list(item), do: item
  def first([h | _]), do: h

  def last(nil), do: nil
  def last([]), do: nil
  def last(item) when not is_list(item), do: item
  def last(list), do: List.last(list)

  def peek(list), do: first(list)

  def enqueue(item, elem), do: append(item, elem)
  def dequeue(list), do: pop(list)
end
