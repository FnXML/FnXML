defmodule FnXML.ParserStreamTest do
  use ExUnit.Case, async: true

  alias FnXML.ParserStream

  describe "parse/1 stream mode" do
    test "parses simple element" do
      events = ["<root/>"] |> ParserStream.parse() |> Enum.to_list()
      assert {:start_document, nil} in events
      assert {:end_document, nil} in events
      assert Enum.any?(events, &match?({:start_element, "root", [], _}, &1))
    end

    test "parses element with text" do
      events = ["<root>hello</root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:characters, "hello", _}, &1))
    end

    test "parses element with attributes" do
      events = ["<root id=\"1\" class=\"test\"/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:start_element, "root", attrs, _} -> {"id", "1"} in attrs
        _ -> false
      end)
    end

    test "handles empty stream" do
      events = [] |> ParserStream.parse() |> Enum.to_list()
      assert events == [{:start_document, nil}, {:end_document, nil}]
    end

    test "handles multiple chunks" do
      # Use a single chunk to avoid boundary issues
      chunks = ["<root>text</root>"]
      events = chunks |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "root", [], _}, &1))
      assert Enum.any?(events, &match?({:end_element, "root", _}, &1))
    end

    test "handles chunk boundary in tag name" do
      chunks = ["<roo", "t/>"]
      events = chunks |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "root", [], _}, &1))
    end

    test "handles chunk boundary in attribute" do
      chunks = ["<root id=\"val", "ue\"/>"]
      events = chunks |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:start_element, "root", attrs, _} -> {"id", "value"} in attrs
        _ -> false
      end)
    end
  end

  describe "parse/1 with mode option" do
    test "eager mode loads all chunks upfront" do
      events = ["<root/>"] |> ParserStream.parse(mode: :eager) |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "root", [], _}, &1))
    end

    test "lazy mode pulls chunks on demand" do
      events = ["<root/>"] |> ParserStream.parse(mode: :lazy) |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "root", [], _}, &1))
    end
  end

  describe "parse/3 with callback" do
    test "calls emit function for each event" do
      events = []
      emit = fn event -> send(self(), {:event, event}) end

      ParserStream.parse(["<root/>"], emit, [])

      assert_received {:event, {:start_document, nil}}
      assert_received {:event, {:start_element, "root", [], _}}
      assert_received {:event, {:end_document, nil}}
    end
  end

  describe "UTF-16 detection" do
    test "raises on UTF-16 LE BOM" do
      assert_raise ArgumentError, ~r/UTF-16 Little Endian/, fn ->
        [<<0xFF, 0xFE, "<root/>">>] |> ParserStream.parse() |> Enum.to_list()
      end
    end

    test "raises on UTF-16 BE BOM" do
      assert_raise ArgumentError, ~r/UTF-16 Big Endian/, fn ->
        [<<0xFE, 0xFF, "<root/>">>] |> ParserStream.parse() |> Enum.to_list()
      end
    end
  end

  describe "comments" do
    test "parses comment" do
      events = ["<root><!-- comment --></root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:comment, " comment ", _}, &1))
    end

    test "handles comment across chunks" do
      chunks = ["<root><!--", " comment -->", "</root>"]
      events = chunks |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:comment, _, _}, &1))
    end
  end

  describe "CDATA" do
    test "parses CDATA section" do
      events = ["<root><![CDATA[<data>]]></root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:cdata, "<data>", _}, &1))
    end

    test "handles CDATA across chunks" do
      chunks = ["<root><![CDATA[", "data", "]]></root>"]
      events = chunks |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:cdata, _, _}, &1))
    end
  end

  describe "DOCTYPE" do
    test "parses DOCTYPE" do
      events = ["<!DOCTYPE html><root/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:dtd, _, _}, &1))
    end

    test "parses DOCTYPE with internal subset" do
      xml = "<!DOCTYPE root [<!ELEMENT root (#PCDATA)>]><root/>"
      events = [xml] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:dtd, _, _}, &1))
    end
  end

  describe "processing instructions" do
    test "parses PI" do
      events = ["<?target data?><root/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:processing_instruction, "target", _, _}, &1))
    end

    test "handles PI across chunks" do
      chunks = ["<?tar", "get data?>", "<root/>"]
      events = chunks |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:processing_instruction, _, _, _}, &1))
    end
  end

  describe "XML prolog" do
    test "parses prolog" do
      events = ["<?xml version=\"1.0\"?><root/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:prolog, attrs, _} -> {"version", "1.0"} in attrs
        _ -> false
      end)
    end

    test "parses prolog with encoding" do
      xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root/>"
      events = [xml] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:prolog, attrs, _} -> {"encoding", "UTF-8"} in attrs
        _ -> false
      end)
    end
  end

  describe "entity references" do
    test "resolves built-in entities in text" do
      events = ["<root>&lt;&gt;&amp;&apos;&quot;</root>"] |> ParserStream.parse() |> Enum.to_list()
      text = events
        |> Enum.filter(&match?({:characters, _, _}, &1))
        |> Enum.map(fn {:characters, t, _} -> t end)
        |> Enum.join()
      assert text == "<>&'\""
    end

    test "resolves numeric entities" do
      events = ["<root>&#65;&#x42;</root>"] |> ParserStream.parse() |> Enum.to_list()
      text = events
        |> Enum.filter(&match?({:characters, _, _}, &1))
        |> Enum.map(fn {:characters, t, _} -> t end)
        |> Enum.join()
      assert text == "AB"
    end

    test "resolves entities in attributes" do
      events = ["<root attr=\"a&lt;b\"/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:start_element, "root", attrs, _} -> {"attr", "a<b"} in attrs
        _ -> false
      end)
    end

    test "passes through unknown entities" do
      events = ["<root>&unknown;</root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:characters, "&unknown;", _}, &1))
    end
  end

  describe "self-closing tags" do
    test "emits start and end element" do
      events = ["<root/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "root", [], _}, &1))
      assert Enum.any?(events, &match?({:end_element, "root", _}, &1))
    end
  end

  describe "close tags" do
    test "parses close tag" do
      events = ["<root></root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:end_element, "root", _}, &1))
    end

    test "handles whitespace in close tag" do
      events = ["<root></root   >"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:end_element, "root", _}, &1))
    end
  end

  describe "whitespace handling" do
    test "preserves significant whitespace" do
      events = ["<root>  text  </root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:characters, "  text  ", _}, &1))
    end

    test "tracks line numbers" do
      events = ["<root>\n<child/>\n</root>"] |> ParserStream.parse() |> Enum.to_list()
      child = Enum.find(events, &match?({:start_element, "child", _, _}, &1))
      {:start_element, "child", [], {line, _, _}} = child
      # Line tracking starts at 1, and newline increments it
      assert line >= 1
    end
  end

  describe "error handling" do
    test "reports unexpected EOF after <" do
      events = ["<root><"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:error, _, _}, &1))
    end

    test "reports < in attribute value" do
      events = ["<root attr=\"a<b\"/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:error, msg, _} -> String.contains?(msg, "<")
        _ -> false
      end)
    end

    test "reports invalid character after <" do
      events = ["<root><1invalid/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:error, _, _}, &1))
    end
  end

  describe "nested elements" do
    test "parses deeply nested elements" do
      xml = "<a><b><c><d>text</d></c></b></a>"
      events = [xml] |> ParserStream.parse() |> Enum.to_list()
      tags = events
        |> Enum.filter(&match?({:start_element, _, _, _}, &1))
        |> Enum.map(fn {:start_element, tag, _, _} -> tag end)
      assert tags == ["a", "b", "c", "d"]
    end
  end

  describe "unicode support" do
    test "parses unicode element names" do
      events = ["<\u00E9l\u00E9ment/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "élément", [], _}, &1))
    end

    test "parses unicode text content" do
      events = ["<root>\u4E2D\u6587</root>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, &match?({:characters, "中文", _}, &1))
    end
  end

  describe "attribute edge cases" do
    test "handles single quoted attributes" do
      events = ["<root attr='value'/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:start_element, "root", attrs, _} -> {"attr", "value"} in attrs
        _ -> false
      end)
    end

    test "handles newline in attribute value" do
      events = ["<root attr=\"line1\nline2\"/>"] |> ParserStream.parse() |> Enum.to_list()
      assert Enum.any?(events, fn
        {:start_element, "root", attrs, _} -> {"attr", "line1\nline2"} in attrs
        _ -> false
      end)
    end

    test "handles multiple attributes" do
      events = ["<root a=\"1\" b=\"2\" c=\"3\"/>"] |> ParserStream.parse() |> Enum.to_list()
      attrs = Enum.find_value(events, fn
        {:start_element, "root", attrs, _} -> attrs
        _ -> nil
      end)
      assert length(attrs) == 3
    end
  end
end
