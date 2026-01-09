defmodule FnXML.DTD.ParserTest do
  use ExUnit.Case, async: true

  alias FnXML.DTD.Parser

  describe "parse_element/1" do
    test "parses EMPTY element" do
      assert Parser.parse_element("<!ELEMENT br EMPTY>") ==
               {:ok, {:element, "br", :empty}}
    end

    test "parses ANY element" do
      assert Parser.parse_element("<!ELEMENT container ANY>") ==
               {:ok, {:element, "container", :any}}
    end

    test "parses #PCDATA element" do
      assert Parser.parse_element("<!ELEMENT p (#PCDATA)>") ==
               {:ok, {:element, "p", :pcdata}}
    end

    test "parses sequence content model" do
      assert Parser.parse_element("<!ELEMENT note (to, from, body)>") ==
               {:ok, {:element, "note", {:seq, ["to", "from", "body"]}}}
    end

    test "parses choice content model" do
      assert Parser.parse_element("<!ELEMENT choice (a | b | c)>") ==
               {:ok, {:element, "choice", {:choice, ["a", "b", "c"]}}}
    end

    test "parses element with occurrence indicators" do
      assert Parser.parse_element("<!ELEMENT items (item)*>") ==
               {:ok, {:element, "items", {:zero_or_more, "item"}}}

      assert Parser.parse_element("<!ELEMENT items (item)+>") ==
               {:ok, {:element, "items", {:one_or_more, "item"}}}

      assert Parser.parse_element("<!ELEMENT items (item)?>") ==
               {:ok, {:element, "items", {:optional, "item"}}}
    end

    test "parses sequence with occurrence" do
      assert Parser.parse_element("<!ELEMENT list (a, b)*>") ==
               {:ok, {:element, "list", {:zero_or_more, {:seq, ["a", "b"]}}}}
    end

    test "parses mixed content" do
      assert Parser.parse_element("<!ELEMENT p (#PCDATA | b | i)*>") ==
               {:ok, {:element, "p", {:mixed, ["b", "i"]}}}
    end

    test "parses item occurrence indicators in sequence" do
      assert Parser.parse_element("<!ELEMENT doc (title, para+)>") ==
               {:ok, {:element, "doc", {:seq, ["title", {:one_or_more, "para"}]}}}
    end

    test "handles whitespace variations" do
      assert Parser.parse_element("<!ELEMENT   note   (  to ,  from  )  >") ==
               {:ok, {:element, "note", {:seq, ["to", "from"]}}}
    end

    test "returns error for invalid declaration" do
      assert {:error, _} = Parser.parse_element("<!ELEMENT >")
      assert {:error, _} = Parser.parse_element("<!ELEMENT foo>")
    end
  end

  describe "parse_content_model/1" do
    test "parses EMPTY" do
      assert Parser.parse_content_model("EMPTY") == {:ok, :empty}
    end

    test "parses ANY" do
      assert Parser.parse_content_model("ANY") == {:ok, :any}
    end

    test "parses #PCDATA" do
      assert Parser.parse_content_model("(#PCDATA)") == {:ok, :pcdata}
    end

    test "parses simple sequence" do
      assert Parser.parse_content_model("(a, b, c)") == {:ok, {:seq, ["a", "b", "c"]}}
    end

    test "parses simple choice" do
      assert Parser.parse_content_model("(a | b)") == {:ok, {:choice, ["a", "b"]}}
    end
  end

  describe "parse_entity/1" do
    test "parses internal entity" do
      assert Parser.parse_entity(~s[<!ENTITY copyright "(c) 2024">]) ==
               {:ok, {:entity, "copyright", {:internal, "(c) 2024"}}}
    end

    test "parses internal entity with single quotes" do
      assert Parser.parse_entity("<!ENTITY copyright '(c) 2024'>") ==
               {:ok, {:entity, "copyright", {:internal, "(c) 2024"}}}
    end

    test "parses SYSTEM entity" do
      assert Parser.parse_entity(~s[<!ENTITY logo SYSTEM "logo.gif">]) ==
               {:ok, {:entity, "logo", {:external, "logo.gif", nil}}}
    end

    test "parses PUBLIC entity" do
      assert Parser.parse_entity(
               ~s[<!ENTITY chapter PUBLIC "-//OASIS//DTD DocBook//EN" "docbook.dtd">]
             ) ==
               {:ok,
                {:entity, "chapter", {:external, "docbook.dtd", "-//OASIS//DTD DocBook//EN"}}}
    end

    test "parses parameter entity" do
      assert Parser.parse_entity(~s[<!ENTITY % colors "red | green | blue">]) ==
               {:ok, {:param_entity, "colors", "red | green | blue"}}
    end

    test "parses unparsed entity with NDATA" do
      assert Parser.parse_entity(~s[<!ENTITY logo SYSTEM "logo.gif" NDATA gif>]) ==
               {:ok, {:entity, "logo", {:external_unparsed, "logo.gif", nil, "gif"}}}
    end

    test "returns error for invalid entity" do
      assert {:error, _} = Parser.parse_entity("<!ENTITY >")
    end
  end

  describe "parse_attlist/1" do
    test "parses CDATA attribute with #REQUIRED" do
      assert Parser.parse_attlist("<!ATTLIST img src CDATA #REQUIRED>") ==
               {:ok, {:attlist, "img", [%{name: "src", type: :cdata, default: :required}]}}
    end

    test "parses CDATA attribute with #IMPLIED" do
      assert Parser.parse_attlist("<!ATTLIST img alt CDATA #IMPLIED>") ==
               {:ok, {:attlist, "img", [%{name: "alt", type: :cdata, default: :implied}]}}
    end

    test "parses ID attribute" do
      assert Parser.parse_attlist("<!ATTLIST div id ID #REQUIRED>") ==
               {:ok, {:attlist, "div", [%{name: "id", type: :id, default: :required}]}}
    end

    test "parses IDREF attribute" do
      assert Parser.parse_attlist("<!ATTLIST ref target IDREF #REQUIRED>") ==
               {:ok, {:attlist, "ref", [%{name: "target", type: :idref, default: :required}]}}
    end

    test "parses enumeration attribute" do
      assert Parser.parse_attlist(~s[<!ATTLIST color type (red | green | blue) "red">]) ==
               {:ok,
                {:attlist, "color",
                 [
                   %{
                     name: "type",
                     type: {:enum, ["red", "green", "blue"]},
                     default: {:default, "red"}
                   }
                 ]}}
    end

    test "parses #FIXED attribute" do
      assert Parser.parse_attlist(~s[<!ATTLIST html version CDATA #FIXED "1.0">]) ==
               {:ok,
                {:attlist, "html", [%{name: "version", type: :cdata, default: {:fixed, "1.0"}}]}}
    end

    test "parses multiple attributes" do
      result = Parser.parse_attlist("<!ATTLIST img src CDATA #REQUIRED alt CDATA #IMPLIED>")
      assert {:ok, {:attlist, "img", attrs}} = result
      assert length(attrs) == 2
      assert Enum.at(attrs, 0) == %{name: "src", type: :cdata, default: :required}
      assert Enum.at(attrs, 1) == %{name: "alt", type: :cdata, default: :implied}
    end
  end

  describe "parse_notation/1" do
    test "parses SYSTEM notation" do
      assert Parser.parse_notation(~s[<!NOTATION gif SYSTEM "image/gif">]) ==
               {:ok, {:notation, "gif", "image/gif", nil}}
    end

    test "parses PUBLIC notation with SYSTEM" do
      assert Parser.parse_notation(~s[<!NOTATION html PUBLIC "-//W3C//DTD HTML//EN" "html.dtd">]) ==
               {:ok, {:notation, "html", "html.dtd", "-//W3C//DTD HTML//EN"}}
    end

    test "parses PUBLIC notation without SYSTEM" do
      assert Parser.parse_notation(~s[<!NOTATION html PUBLIC "-//W3C//DTD HTML//EN">]) ==
               {:ok, {:notation, "html", nil, "-//W3C//DTD HTML//EN"}}
    end
  end

  describe "parse/1" do
    test "parses complete DTD" do
      dtd = """
      <!ELEMENT note (to, from, body)>
      <!ELEMENT to (#PCDATA)>
      <!ELEMENT from (#PCDATA)>
      <!ELEMENT body (#PCDATA)>
      <!ATTLIST note id ID #REQUIRED>
      <!ENTITY copyright "(c) 2024">
      """

      assert {:ok, model} = Parser.parse(dtd)
      assert model.elements["note"] == {:seq, ["to", "from", "body"]}
      assert model.elements["to"] == :pcdata
      assert model.elements["from"] == :pcdata
      assert model.elements["body"] == :pcdata
      assert model.attributes["note"] == [%{name: "id", type: :id, default: :required}]
      assert model.entities["copyright"] == {:internal, "(c) 2024"}
    end

    test "handles empty DTD" do
      assert {:ok, model} = Parser.parse("")
      assert model.elements == %{}
    end

    test "skips comments" do
      dtd = """
      <!-- This is a comment -->
      <!ELEMENT note (#PCDATA)>
      """

      assert {:ok, model} = Parser.parse(dtd)
      assert model.elements["note"] == :pcdata
    end
  end

  describe "parse_declaration/1" do
    test "routes to correct parser" do
      assert {:ok, {:element, _, _}} = Parser.parse_declaration("<!ELEMENT foo EMPTY>")
      assert {:ok, {:entity, _, _}} = Parser.parse_declaration("<!ENTITY foo \"bar\">")

      assert {:ok, {:attlist, _, _}} =
               Parser.parse_declaration("<!ATTLIST foo bar CDATA #IMPLIED>")

      assert {:ok, {:notation, _, _, _}} =
               Parser.parse_declaration("<!NOTATION foo SYSTEM \"bar\">")
    end

    test "skips empty and comments" do
      assert {:ok, :skip} = Parser.parse_declaration("")
      assert {:ok, :skip} = Parser.parse_declaration("<!-- comment -->")
    end

    test "returns error for unknown declaration" do
      assert {:error, _} = Parser.parse_declaration("<!UNKNOWN foo>")
    end
  end
end
