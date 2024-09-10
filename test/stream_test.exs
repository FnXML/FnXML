defmodule FnXML.StreamTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  doctest FnXML.Stream

  def all_lines_start_with?(lines, prefix) do
    String.split(lines, "\n")
    |> Enum.filter(fn line -> String.trim(line) != "" end)
    |> Enum.all?(fn line -> String.starts_with?(line, prefix) end)
  end

  test "test tap" do
    xml = "<foo a='1'>first element<bar>nested element</bar></foo>"

    assert capture_io(fn -> 
      FnXML.Parser.parse(xml)
      |> FnXML.Stream.tap(label: "test_stream")
      |> Enum.map(fn x -> x end)
    end)
    |> all_lines_start_with?("test_stream:")
  end

  test "test to_xml_text" do
    xml = "<foo a=\"1\">first element<bar>nested element</bar></foo>"

    assert (FnXML.Parser.parse(xml) |> FnXML.Stream.to_xml()) |> Enum.join() == xml
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
        text: ["first element"],
        open: [tag: "bar"],
        text: ["nested element"],
        close: [tag: "bar"],
        close: [tag: "foo"]
      ]
    end

    test "transform empty tag" do
      result = [ open: [tag: "a"], open: [tag: "b", close: true], close: [tag: "a"]] |> FnXML.Stream.to_xml() |> Enum.join()

      assert result == "<a><b/></a>"
    end
  end
end
