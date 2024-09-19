defmodule FnXML.StreamTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  doctest FnXML.Stream

  def all_lines_start_with?(lines, prefix) do
    String.split(lines, "\n")
    |> Enum.filter(fn line -> String.trim(line) != "" end)
    |> Enum.all?(fn line -> String.starts_with?(line, prefix) end)
  end

  def strip_ws(str), do: String.replace(str, ~r/[\s\r\n]+/, "")

  test "test tap" do
    xml = "<foo a='1'>first element<bar>nested element</bar></foo>"

    assert capture_io(fn -> 
      FnXML.Parser.parse(xml)
      |> FnXML.Stream.tap(label: "test_stream")
      |> Enum.map(fn x -> x end)
    end)
    |> all_lines_start_with?("test_stream:")
  end

  describe "to_xml" do
    @tag focus: true
    test "basic" do
      xml = "<foo a=\"1\">first element<bar>nested element</bar></foo>"
      
      assert (FnXML.Parser.parse(xml) |> FnXML.Stream.to_xml()) |> Enum.join() == xml
    end

    test "with all elements" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <foo a=\"1\">first element
        <!--comment-->
        <?pi-test this is processing instruction?>
        <bar>nested element</bar>
        <![CDATA[<bar>nested element</bar>]]>
      </foo>
      """
      
      assert FnXML.Parser.parse(xml) |> FnXML.Stream.to_xml() |> Enum.join() |> strip_ws() == strip_ws(xml)
    end
  end


  describe "transform" do
    test "remove location meta transform" do
      xml = "<foo a='1'>first element<bar>nested element</bar></foo>"
      
      result =
        FnXML.Parser.parse(xml)
        |> FnXML.Stream.transform(fn {id, [tag | meta]}, _path, acc -> {{id, [tag | meta |> Keyword.drop([:loc])]}, acc} end)
        |> Enum.to_list()
      
      assert result == [
        open: [tag: "foo", attributes: [{"a", "1"}]],
        text: [content: "first element"],
        open: [tag: "bar"],
        text: [content: "nested element"],
        close: [tag: "bar"],
        close: [tag: "foo"]
      ]
    end

    test "transform empty tag" do
      result = [ open: [tag: "a"], open: [tag: "b", close: true], close: [tag: "a"]] |> FnXML.Stream.to_xml() |> Enum.join()

      assert result == "<a><b/></a>"
    end
  end

  describe "filter" do

    test "whitespace 0" do
      stream = [
        open: [tag: "foo"],
        text: [content: "first element"],
        text: [content: " \t"],
        text: [content: "  \n\t"],
        close: [tag: "foo"]
      ]
      assert FnXML.Stream.filter_ws(stream) |> Enum.to_list() == [
        open: [tag: "foo"],
        text: [content: "first element"],
        close: [tag: "foo"]
      ]
    end

    test "namespace 0" do
      stream = [
        open: [tag: "foo"],
        open: [tag: "biz:bar"], close: [tag: "biz:bar"],
        open: [tag: "bar:baz"], close: [tag: "bar:baz"],
        open: [tag: "bar"], close: [tag: "bar"],
        open: [tag: "baz:buz"], close: [tag: "baz:buz"],
        close: [tag: "foo"]
      ]

      result = FnXML.Stream.filter_namespaces(stream, ["bar", "baz"], exclude: true) |> Enum.to_list()
      assert result == [
        open: [tag: "foo"],
        open: [tag: "biz:bar"], close: [tag: "biz:bar"],
        open: [tag: "bar"], close: [tag: "bar"],
        close: [tag: "foo"]
      ]
    end
  end
end
