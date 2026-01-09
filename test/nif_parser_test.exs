defmodule FnXML.NifParserTest do
  use ExUnit.Case, async: true

  alias FnXML.NifParser

  # Skip NIF-specific tests when NIF is not available
  @moduletag :nif_parser

  describe "parse/4 basic parsing" do
    test "parses elements with content and attributes" do
      {events, nil, _} = NifParser.parse("<root id=\"1\">hello</root>", nil, 0, {1, 0, 0})

      assert [{:start_element, "root", [{"id", "1"}], _},
              {:characters, "hello", _},
              {:end_element, "root", _}] = events
    end

    test "parses nested and namespaced elements" do
      {events, nil, _} = NifParser.parse("<ns:root xmlns:ns=\"http://x\"><child/></ns:root>", nil, 0, {1, 0, 0})

      assert Enum.any?(events, &match?({:start_element, "ns:root", _, _}, &1))
      assert Enum.any?(events, &match?({:start_element, "child", [], _}, &1))
    end

    test "parses single-quoted attributes" do
      {events, nil, _} = NifParser.parse("<root attr='value'/>", nil, 0, {1, 0, 0})
      assert [{:start_element, "root", [{"attr", "value"}], _}, _] = events
    end
  end

  describe "parse/4 text and whitespace" do
    test "distinguishes space from characters" do
      {events1, nil, _} = NifParser.parse("<root>   </root>", nil, 0, {1, 0, 0})
      assert Enum.any?(events1, &match?({:space, "   ", _}, &1))

      {events2, nil, _} = NifParser.parse("<root>  hello  </root>", nil, 0, {1, 0, 0})
      assert Enum.any?(events2, &match?({:characters, "  hello  ", _}, &1))
    end
  end

  describe "parse/4 special constructs" do
    test "parses comments and detects invalid --" do
      {events1, nil, _} = NifParser.parse("<root><!-- comment --></root>", nil, 0, {1, 0, 0})
      assert Enum.any?(events1, &match?({:comment, " comment ", _}, &1))

      {events2, nil, _} = NifParser.parse("<root><!-- -- --></root>", nil, 0, {1, 0, 0})
      assert Enum.any?(events2, &match?({:error, :comment, _, _}, &1))
    end

    test "parses CDATA section" do
      {events, nil, _} = NifParser.parse("<root><![CDATA[<not>xml]]></root>", nil, 0, {1, 0, 0})
      assert Enum.any?(events, &match?({:cdata, "<not>xml", _}, &1))
    end

    test "parses processing instructions and XML declaration" do
      {events1, nil, _} = NifParser.parse("<?xml version=\"1.0\"?><root/>", nil, 0, {1, 0, 0})
      assert Enum.any?(events1, &match?({:start_document, _}, &1))

      {events2, nil, _} = NifParser.parse("<?custom data?><root/>", nil, 0, {1, 0, 0})
      assert Enum.any?(events2, &match?({:processing_instruction, "custom", "data", _}, &1))

      {events3, nil, _} = NifParser.parse("<?target?><root/>", nil, 0, {1, 0, 0})
      assert Enum.any?(events3, &match?({:processing_instruction, "target", _, _}, &1))
    end

    test "parses DOCTYPE" do
      {events, nil, _} = NifParser.parse("<!DOCTYPE root [<!ENTITY x \"y\">]><root/>", nil, 0, {1, 0, 0})
      assert Enum.any?(events, &match?({:dtd, _, _}, &1))
    end
  end

  describe "parse/4 error handling" do
    test "detects duplicate attributes" do
      {events, nil, _} = NifParser.parse(~s(<root a="1" a="2"/>), nil, 0, {1, 0, 0})
      assert Enum.any?(events, &match?({:error, :attr_unique, _, _}, &1))
    end

    test "detects UTF-16 BOM" do
      {events, 0, _} = NifParser.parse(<<0xFE, 0xFF, "<root/>"::binary>>, nil, 0, {1, 0, 0})
      assert Enum.any?(events, &match?({:error, :utf16, _, _}, &1))
    end

    test "handles invalid tag start and unknown directives" do
      {events1, nil, _} = NifParser.parse("<1invalid/><root/>", nil, 0, {1, 0, 0})
      assert Enum.any?(events1, &match?({:error, :invalid_name, _, _}, &1))
      assert Enum.any?(events1, &match?({:start_element, "root", _, _}, &1))

      {events2, nil, _} = NifParser.parse("<!UNKNOWN><root/>", nil, 0, {1, 0, 0})
      assert Enum.any?(events2, &match?({:start_element, "root", _, _}, &1))
    end
  end

  describe "parse/4 chunking" do
    test "handles incomplete element at chunk boundary" do
      {[], 0, state} = NifParser.parse("<root attr=\"val", nil, 0, {1, 0, 0})
      {events, nil, _} = NifParser.parse("ue\"/>", "<root attr=\"val", 0, state)

      assert [{:start_element, "root", [{"attr", "value"}], _}, _] = events
    end

    test "handles text at chunk boundary" do
      {events1, nil, state} = NifParser.parse("<root>hello ", nil, 0, {1, 0, 0})
      assert Enum.any?(events1, &match?({:characters, "hello ", _}, &1))

      {events2, nil, _} = NifParser.parse("world</root>", nil, 0, state)
      assert Enum.any?(events2, &match?({:characters, "world", _}, &1))
    end

    test "handles element split across chunks" do
      {[], 0, state} = NifParser.parse("<roo", nil, 0, {1, 0, 0})
      {events, nil, _} = NifParser.parse("t/>", "<roo", 0, state)
      assert [{:start_element, "root", [], _}, _] = events
    end
  end

  describe "parse/4 position tracking" do
    test "tracks line numbers and byte offset" do
      xml = "<root>\n<child/>\n</root>"
      {_, nil, {line, _, byte}} = NifParser.parse(xml, nil, 0, {1, 0, 0})
      assert line == 3
      assert byte == byte_size(xml)
    end

    test "normalizes line endings" do
      {_, nil, {line1, _, _}} = NifParser.parse("<root>\r\n</root>", nil, 0, {1, 0, 0})
      assert line1 == 2

      {_, nil, {line2, _, _}} = NifParser.parse("<root>\r</root>", nil, 0, {1, 0, 0})
      assert line2 == 2
    end

    test "handles multiline constructs" do
      {events, nil, {line, _, _}} = NifParser.parse("<root><!--\nmulti\nline\n--></root>", nil, 0, {1, 0, 0})
      assert line >= 4
      assert Enum.any?(events, &match?({:comment, _, _}, &1))
    end
  end

  describe "parse/4 edge cases" do
    test "handles empty input" do
      {[], nil, {1, 0, 0}} = NifParser.parse("", nil, 0, {1, 0, 0})
    end
  end

  describe "stream/2" do
    test "streams single binary and chunked input" do
      events1 = NifParser.stream("<root><child/></root>") |> Enum.to_list()
      assert Enum.any?(events1, &match?({:start_element, "root", _, _}, &1))

      events2 = NifParser.stream(["<root>", "<child/>", "</root>"]) |> Enum.to_list()
      assert Enum.any?(events2, &match?({:start_element, "root", _, _}, &1))
      assert Enum.any?(events2, &match?({:start_element, "child", _, _}, &1))
    end

    test "handles element spanning multiple chunks" do
      events = NifParser.stream(["<very-lo", "ng-name", "/>"]) |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "very-long-name", _, _}, &1))
    end

    test "handles empty chunks and options" do
      events = NifParser.stream(["<root>", "", "</root>"], max_join_count: 1) |> Enum.to_list()
      assert Enum.any?(events, &match?({:start_element, "root", _, _}, &1))
    end
  end
end
