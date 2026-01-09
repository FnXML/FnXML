defmodule FnXML.DTD.ValidatorTest do
  use ExUnit.Case, async: true

  alias FnXML.DTD.Validator

  describe "validate/2 with namespace constraints" do
    test "emits error for entity name with colon" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo ANY>
        <!ENTITY a:b "bogus">
      ]>
      <foo/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      assert Enum.any?(events, fn
               {:dtd_error, {:colon_in_entity_name, "a:b"}, _, _} -> true
               _ -> false
             end)
    end

    test "emits error for notation name with colon" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo ANY>
        <!NOTATION a:b SYSTEM "notation">
      ]>
      <foo/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      assert Enum.any?(events, fn
               {:dtd_error, {:colon_in_notation_name, "a:b"}, _, _} -> true
               _ -> false
             end)
    end

    test "passes for valid entity and notation names" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo ANY>
        <!ENTITY valid_name "value">
        <!NOTATION valid_notation SYSTEM "notation">
      ]>
      <foo/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      refute Enum.any?(events, fn
               {:dtd_error, _, _, _} -> true
               _ -> false
             end)
    end
  end

  describe "validate/2 with attribute normalization" do
    test "normalizes NMTOKEN attribute values" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo EMPTY>
        <!ATTLIST foo id NMTOKEN #IMPLIED>
      ]>
      <foo id="  hello  world  "/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      open_event =
        Enum.find(events, fn
          {:start_element, "foo", _, _} -> true
          _ -> false
        end)

      assert {:start_element, "foo", attrs, _} = open_event
      assert {"id", "hello world"} in attrs
    end

    test "normalizes ID attribute values" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo EMPTY>
        <!ATTLIST foo myid ID #IMPLIED>
      ]>
      <foo myid="  myvalue  "/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      open_event =
        Enum.find(events, fn
          {:start_element, "foo", _, _} -> true
          _ -> false
        end)

      assert {:start_element, "foo", attrs, _} = open_event
      assert {"myid", "myvalue"} in attrs
    end

    test "does not normalize CDATA attribute values" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo EMPTY>
        <!ATTLIST foo name CDATA #IMPLIED>
      ]>
      <foo name="  hello  world  "/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      open_event =
        Enum.find(events, fn
          {:start_element, "foo", _, _} -> true
          _ -> false
        end)

      assert {:start_element, "foo", attrs, _} = open_event
      assert {"name", "  hello  world  "} in attrs
    end

    test "skips normalization when disabled" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ELEMENT foo EMPTY>
        <!ATTLIST foo id NMTOKEN #IMPLIED>
      ]>
      <foo id="  hello  "/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate(normalize_attributes: false)
        |> Enum.to_list()

      open_event =
        Enum.find(events, fn
          {:start_element, "foo", _, _} -> true
          _ -> false
        end)

      assert {:start_element, "foo", attrs, _} = open_event
      assert {"id", "  hello  "} in attrs
    end
  end

  describe "validate/2 with on_error options" do
    test "raises on error when on_error: :raise" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ENTITY a:b "bogus">
      ]>
      <foo/>
      """

      assert_raise RuntimeError, ~r/colon_in_entity_name/, fn ->
        FnXML.Parser.parse(xml)
        |> Validator.validate(on_error: :raise)
        |> Enum.to_list()
      end
    end

    test "skips errors when on_error: :skip" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [
        <!ENTITY a:b "bogus">
      ]>
      <foo/>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate(on_error: :skip)
        |> Enum.to_list()

      refute Enum.any?(events, fn
               {:dtd_error, _, _, _} -> true
               _ -> false
             end)
    end
  end

  describe "validate/2 passes through events correctly" do
    test "preserves all event types" do
      xml = """
      <?xml version="1.0"?>
      <!DOCTYPE foo [<!ELEMENT foo (#PCDATA)>]>
      <!-- comment -->
      <foo>text</foo>
      """

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      assert Enum.any?(events, &match?({:start_document, _}, &1))
      assert Enum.any?(events, &match?({:prolog, "xml", _, _}, &1))
      assert Enum.any?(events, &match?({:dtd, _, _}, &1))
      assert Enum.any?(events, &match?({:comment, _, _}, &1))
      assert Enum.any?(events, &match?({:start_element, "foo", _, _}, &1))
      assert Enum.any?(events, &match?({:characters, "text", _}, &1))
      assert Enum.any?(events, &match?({:end_element, "foo", _}, &1))
      assert Enum.any?(events, &match?({:end_document, _}, &1))
    end

    test "works without DTD" do
      xml = "<foo><bar/></foo>"

      events =
        FnXML.Parser.parse(xml)
        |> Validator.validate()
        |> Enum.to_list()

      assert Enum.any?(events, &match?({:start_element, "foo", _, _}, &1))
      assert Enum.any?(events, &match?({:start_element, "bar", _, _}, &1))
    end
  end
end
