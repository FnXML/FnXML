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
      [ open: [tag: "a", namespace: "ns"], close: [tag: "a", namespace: "ns"] ]
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
      [ open: [tag: "a"], text: ["b"], close: [tag: "a"] ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result == %NDS{tag: "a", content: ["b"]}
  end

  test "tag with all meta" do
    result =
      [
        open: [tag: "hello", namespace: "ns", attributes: [{"a", "1"}]],
        text: ["world"],
        close: [tag: "hello", namespace: "ns"]
      ]
      |> NDS.Decoder.decode([])
      |> Enum.at(0)

    assert result == %NDS{tag: "hello", namespace: "ns", attributes: [{"a", "1"}], content: ["world"]}
  end
  
  test "decode with child" do
    result =
      [
        open: [tag: "hello", namespace: "ns", attributes: [{"a", "1"}]],
        text: ["hello"],
        open: [tag: "child", attributes: [{"b", "2"}]],
        text: ["child world"],
        close: [tag: "child"],
        text: ["world"],
        close: [tag: "hello", namespace: "ns"]
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

  @tag focus: true
  test "decode with child list" do
    result =
      [
        open: [tag: "hello", namespace: "ns", attributes: [{"a", "1"}]],
        text: ["hello"],
        open: [tag: "child1", attributes: [{"b", "2"}]],
        text: ["child world"],
        close: [tag: "child1"],
        open: [tag: "child1", attributes: [{"b", "2"}]],
        text: ["alt world"],
        close: [tag: "child1"],
        open: [tag: "child2", attributes: [{"b", "2"}]],
        text: ["other worldly"],
        close: [tag: "child2"],
        text: ["world"],
        close: [tag: "hello", namespace: "ns"]
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
          %NDS{tag: "child1", attributes: [{"b", "2"}], content: ["child world"]},
          %NDS{tag: "child1", attributes: [{"b", "2"}], content: ["alt world"]},
          %NDS{tag: "child2", attributes: [{"b", "2"}], content: ["other worldly"]},
          "world"
        ]
      }
  end
  
end
