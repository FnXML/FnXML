defmodule ListyTest do
  use ExUnit.Case

  test "listy insert" do
    assert Listy.insert(nil, 1) == 1
    assert Listy.insert([], 1) == 1
    assert Listy.insert(1, 2) == [2, 1]
    assert Listy.insert([1, 2], 3) == [3, 1, 2]
  end

  test "listy append" do
    assert Listy.append(nil, 1) == 1
    assert Listy.append([], 1) == 1
    assert Listy.append(1, 2) == [1, 2]
    assert Listy.append([1, 2], 3) == [1, 2, 3]
  end

  test "listy push" do
    assert Listy.push(nil, 1) == 1
    assert Listy.push([], 1) == 1
    assert Listy.push(1, 2) == [2, 1]
    assert Listy.push([1, 2], 3) == [3, 1, 2]
  end

  test "listy pop" do
    assert Listy.pop(nil) == {nil, nil}
    assert Listy.pop([]) == {nil, nil}
    assert Listy.pop([1]) == {1, nil}
    assert Listy.pop([1, 2]) == {1, 2}
  end

  test "listy enqueue" do
    assert Listy.enqueue(nil, 1) == 1
    assert Listy.enqueue([], 1) == 1
    assert Listy.enqueue(1, 2) == [1, 2]
    assert Listy.enqueue([1, 2], 3) == [1, 2, 3]
  end

  test "listy dequeue" do
    assert Listy.dequeue(nil) == {nil, nil}
    assert Listy.dequeue([]) == {nil, nil}
    assert Listy.dequeue([1]) == {1, nil}
    assert Listy.dequeue([1, 2]) == {1, 2}
    assert Listy.dequeue([1, 2, 3]) == {1, [2, 3]}
  end

  test "listy first" do
    assert Listy.first(nil) == nil
    assert Listy.first([]) == nil
    assert Listy.first(1) == 1
    assert Listy.first([1, 2]) == 1
  end

  test "listy peek" do
    assert Listy.peek(nil) == nil
    assert Listy.peek([]) == nil
    assert Listy.peek(1) == 1
    assert Listy.peek([1, 2]) == 1
  end

  test "listy last" do
    assert Listy.last(nil) == nil
    assert Listy.last([]) == nil
    assert Listy.last(1) == 1
    assert Listy.last([1, 2]) == 2
  end
end
