defmodule FnXML.Stream.NativeDataStruct.Format.XMLTest do
  use ExUnit.Case

  alias FnXML.Stream.NativeDataStruct, as: NDS

  doctest NDS.Format.XML

  describe "Format NDS to XML Stream:" do
    test "value" do
      assert NDS.encode("world", tag: "hello") == [
        open: [tag: "hello"],
        text: ["world"],
        close: [tag: "hello"]
      ]
    end

    test "basic map" do
      map = %{ "text" => "hi", :a => "1" }
      assert NDS.encode(map, tag: "foo") == [
        open: [tag: "foo", attributes: [{"a", "1"}]],
        text: ["hi"],
        close: [tag: "foo"]
      ]
    end

    test "nested map" do
      map = %{
        :a => "1",
        "text" => "world",
        "child" => %{
          :b => "2",
          "text" => "child world"
        }
      }

      assert NDS.encode(map, tag_from_parent: "hello") == [
        open: [tag: "hello", attributes: [{"a", "1"}]],
        text: ["world"],
        open: [tag: "child", attributes: [{"b", "2"}]],
        text: ["child world"],
        close: [tag: "child"],
        close: [tag: "hello"]
      ]
    end

    test "nested map with child list" do
      map = %{
        :a => "1",
        "text" => "world",
        "child" => [
          %{ :b => "1", "text" => "child world" },
          %{ :b => "2", "text" => "child alt world" },
          %{ :b => "3", "text" => "child other world" }
        ]
      }

      assert NDS.encode(map, tag_from_parent: "hello") == [
        open: [tag: "hello", attributes: [{"a", "1"}]],
        text: ["world"],
        open: [tag: "child", attributes: [{"b", "1"}]],
        text: ["child world"],
        close: [tag: "child"],
        open: [tag: "child", attributes: [{"b", "2"}]],
        text: ["child alt world"],
        close: [tag: "child"],
        open: [tag: "child", attributes: [{"b", "3"}]],
        text: ["child other world"],
        close: [tag: "child"],
        close: [tag: "hello"]
      ]
    end
  end
end
