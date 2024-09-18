defmodule FnXML.Stream.NativeDataStruct.DecoderTest do
  use ExUnit.Case

  alias FnXML.Stream.NativeDataStruct, as: NDS

  doctest NDS.Decoder

  test "tag" do
    result = 
      [ open: [tag: "a"], close: [tag: "a"] ]
      |> NDS.Decoder.decode()
      |> Enum.at(0)

    assert result == %NDS{tag: "a"}
  end

  test "tag with namespace" do
    result = 
      [ open: [tag: "ns:a"], close: [tag: "ns:a"] ]
      |> NDS.Decoder.decode()
      |> Enum.at(0)

    assert result == %NDS{tag: "a", namespace: "ns"}
  end

  test "tag with attributes" do
    result = 
      [ open: [tag: "a", attributes: [{"b", "c"}, {"d", "e"}]], close: [tag: "a"] ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result == %NDS{tag: "a", attributes: [{"b", "c"}, {"d", "e"}]}
  end

  test "tag with text" do
    result = 
      [ open: [tag: "a"], text: [content: "b"], close: [tag: "a"] ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result == %NDS{tag: "a", content: ["b"]}
  end

  test "tag with all meta" do
    result =
      [
        open: [tag: "ns:hello", attributes: [{"a", "1"}]],
        text: [content: "world"],
        close: [tag: "ns:hello"]
      ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result == %NDS{tag: "hello", namespace: "ns", attributes: [{"a", "1"}], content: ["world"]}
  end
  
  test "decode with child" do
    result =
      [
        open: [tag: "ns:hello", attributes: [{"a", "1"}]],
        text: [content: "hello"],
        open: [tag: "child", attributes: [{"b", "2"}]],
        text: [content: "child world"],
        close: [tag: "child"],
        text: [content: "world"],
        close: [tag: "ns:hello"]
      ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result == 
      %NDS{
        tag: "hello",
        attributes: [{"a", "1"}],
        namespace: "ns",
        content: [
          "hello",
          %NDS{tag: "child", attributes: [{"b", "2"}], content: ["child world"]},
          "world"
        ]
      }
  end

  test "decode with child list" do
    result =
      [
        open: [tag: "ns:hello", attributes: [{"a", "1"}], loc: {1, 0, 1}],
        text: [content: "hello"],
        open: [tag: "child1", attributes: [{"b", "2"}], loc: {2, 13, 14}],
        text: [content: "child world"],
        close: [tag: "child1"],
        open: [tag: "child1", attributes: [{"b", "2"}], loc: {2, 13, 34}],
        text: [content: "alt world"],
        close: [tag: "child1"],
        open: [tag: "child2", attributes: [{"b", "2"}], loc: {3, 35, 36}],
        text: [content: "other worldly"],
        close: [tag: "child2"],
        text: [content: "world"],
        close: [tag: "ns:hello"]
      ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result ==
      %NDS{
        tag: "hello",
        namespace: "ns",
        attributes: [{"a", "1"}],
        content: [
          "hello",
          %NDS{tag: "child1", attributes: [{"b", "2"}], content: ["child world"], source: [{2, 1}]},
          %NDS{tag: "child1", attributes: [{"b", "2"}], content: ["alt world"], source: [{2, 21}]},
          %NDS{tag: "child2", attributes: [{"b", "2"}], content: ["other worldly"], source: [{3, 1}]},
          "world"
        ],
        source: [{1, 1}]
      }
  end
  
end
