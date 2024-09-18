defmodule FnXML.Parser.ConstructsTest do
  use ExUnit.Case

  import NimbleParsec
  alias FnXML.Parser.Constructs, as: Construct
  alias FnXML.Parser.ConstructsTest

  defparsec(:ws, Construct.ws())
  defparsec(:name, Construct.name())
  defparsec(:tag_name, Construct.tag_name())

  describe "white space" do
    test "single space" do
      assert ConstructsTest.ws(" ") |> elem(1) == [" "]
    end

    test "multiple space" do
      assert ConstructsTest.ws("     ") |> elem(1) == ["     "]
    end

    test "collection of tab, space, nl, lf" do
      assert ConstructsTest.ws("\t  \r\n\t \n") |> elem(1) == ["\t  \r\n\t \n"]
    end

    test "name, single char" do
      assert ConstructsTest.name("a") |>  elem(1) == ["a"]
    end

    test "name" do
      assert ConstructsTest.name("abc") |>  elem(1) == ["abc"]
    end

    test "name with special characters" do
      assert ConstructsTest.name(":abc<") |>  elem(1) == [":abc"]
    end

    test "tag_name" do
      assert ConstructsTest.tag_name("abc>") |>  elem(1) == [tag: "abc"]
    end

    test "tag_name with namespace" do
      assert ConstructsTest.tag_name("ns:abc>") |>  elem(1) == [tag: "ns:abc"]
    end
    
  end
end


defmodule FnXML.Parser.QuotedTest do
  use ExUnit.Case

  import NimbleParsec
  alias FnXML.Parser.Quoted
  alias FnXML.Parser.QuotedTest

  defparsec(:quoted, choice([Quoted.string(?"), Quoted.string(?')]))

  describe "quoted" do
    test "single quote, empty" do
      assert QuotedTest.quoted("''") |> elem(1) == [""]
    end
    test "single quoted, single char" do
      assert QuotedTest.quoted("'h'") |> elem(1) == ["h"]
    end
    test "single quoted, string" do
      assert QuotedTest.quoted("'hello'") |> elem(1) == ["hello"]
    end
    test "single quoted, string with double quotes" do
      assert QuotedTest.quoted("'\"hello\"'") |> elem(1) == ["\"hello\""]
    end

    test "double quoted, empty" do
      assert QuotedTest.quoted("\"\"") |> elem(1) == [""]
    end

    test "double quoted, single char" do
      assert QuotedTest.quoted("\"d\"") |> elem(1) == ["d"]
    end

    test "double quoted, string" do
      assert QuotedTest.quoted("\"hello world\"") |> elem(1) == ["hello world"]
    end

    test "double quoted, string with single quotes" do
      assert QuotedTest.quoted("\"'hello world'\"") |> elem(1) == ["'hello world'"]
    end
  end
end

defmodule FnXML.Parser.AttributesTest do
  use ExUnit.Case

  import NimbleParsec
  alias FnXML.Parser.Attributes
  alias FnXML.Parser.AttributesTest

  defparsec(:attributes, Attributes.attributes())

  describe "attributes" do
    test "empty attribute" do
      assert AttributesTest.attributes(" ") |> elem(1) == [attributes: []]
    end
    test "single attribute" do
      assert AttributesTest.attributes("name='value'") |> elem(1) == [attributes: [{"name", "value"}]]
    end
    test "multiple attributes" do
      attrs = "a='1' b=\"2\" c='3'"
      assert AttributesTest.attributes(attrs) |> elem(1) == [attributes: [{"a", "1"}, {"b", "2"}, {"c", "3"}]]
    end
  end
end

defmodule FnXML.Parser.PositionTest do
  use ExUnit.Case

  import NimbleParsec
  alias FnXML.Parser.Constructs, as: C
  alias FnXML.Parser.Position
  alias FnXML.Parser.PositionTest

  defparsec(:position, ignore(C.name() |> optional(C.ws())) |> Position.get())

  describe "position" do
    test "empty position" do
      assert PositionTest.position("id ") |> elem(1) |> Enum.at(0) == [loc: {1, 0, 3}]
    end
    test "single position" do
      assert PositionTest.position("long_name\n\n    ") |> elem(1) |> Enum.at(0) == [loc: {3, 11, 15}]
    end
  end
end

defmodule FnXML.Parser.ElementTest do
  use ExUnit.Case

  import NimbleParsec
  alias FnXML.Parser.Element
  alias FnXML.Parser.ElementTest

  defparsec(:open_tag, Element.open_tag())
  defparsec(:close_tag, Element.close_tag())
  defparsec(:comment_tag, Element.comment())
  defparsec(:pi, Element.processing_instruction())
  defparsec(:prolog, Element.prolog())
  defparsec(:text, Element.text())
  defparsec(:cdata, Element.cdata())

  describe "tags" do
    test "empty element" do
      assert ElementTest.open_tag("tag") |> elem(1) == [open: [tag: "tag", loc: {1, 0, 0}]]
    end

    test "element with attributes" do
      assert ElementTest.open_tag("tag a='1' b=\"2\" c='3'") |> elem(1) == [open: [tag: "tag", attributes: [{"a", "1"}, {"b", "2"}, {"c", "3"}], loc: {1, 0, 0}]]
    end

    test "element with attributes and empty tag" do
      assert ElementTest.open_tag("tag a='1' b=\"2\" c='3'/") |> elem(1) == [open: [tag: "tag", close: true, attributes: [{"a", "1"}, {"b", "2"}, {"c", "3"}], loc: {1, 0, 0}]]
    end

    test "basic element" do
      assert ElementTest.close_tag("/tag") |> elem(1)  == [close: [tag: "tag", loc: {1, 0, 0}]]
    end
  end

  describe "comment" do
    test "simple comment" do
      assert ElementTest.comment_tag("!-- comment --") |> elem(1) == [comment: [content: " comment ", loc: {1, 0, 0}]]
    end

    test "multi-line comment" do
      assert ElementTest.comment_tag("!-- comment\ncomment2\ncomment3 --") |> elem(1) == [comment: [content: " comment\ncomment2\ncomment3 ", loc: {1, 0, 0}]]
    end
  end

  describe "processing_instruction" do
    test "basic" do
      assert ElementTest.pi("?id string of text?") |> elem(1) == [proc_inst: [tag: "id", content: "string of text", loc: {1, 0, 0}]]
    end
  end

  describe "prolog" do
    test "basic" do
      assert ElementTest.prolog("<?xml version='1.0' encoding='UTF-8'?>") |> elem(1) == [prolog: [tag: "xml", attributes: [{"version", "1.0"}, {"encoding", "UTF-8"}], loc: {1, 0, 1}]]
    end
  end

  describe "text" do
    test "simple" do
      assert ElementTest.text("hello world") |> elem(1) == [text: [content: "hello world", loc: {1, 0, 0}]]
    end
    test "multi-line" do
      assert ElementTest.text("hello\nworld") |> elem(1) == [text: [content: "hello\nworld", loc: {1, 0, 0}]]
    end
    test "terminated with '<'" do
      assert ElementTest.text("hello<other stuff") |> elem(1) == [text: [content: "hello", loc: {1, 0, 0}]]
    end
  end

  describe "cdata" do
    test "simple" do
      assert ElementTest.cdata("![CDATA[hello world]]") |> elem(1) == [text: [content: "hello world", loc: {1, 0, 0}]]
    end
  end
end
