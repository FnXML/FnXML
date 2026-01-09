defmodule FnXML.Namespaces.QNameTest do
  use ExUnit.Case, async: true

  alias FnXML.Namespaces.QName

  describe "parse/1" do
    test "parses unprefixed name" do
      assert QName.parse("element") == {nil, "element"}
    end

    test "parses prefixed name" do
      assert QName.parse("ns:element") == {"ns", "element"}
    end

    test "handles multiple colons (only first is prefix separator)" do
      assert QName.parse("ns:local:part") == {"ns", "local:part"}
    end
  end

  describe "valid_ncname?/1" do
    test "valid simple names" do
      assert QName.valid_ncname?("foo")
      assert QName.valid_ncname?("Foo")
      assert QName.valid_ncname?("_foo")
      assert QName.valid_ncname?("foo123")
      assert QName.valid_ncname?("foo-bar")
      assert QName.valid_ncname?("foo.bar")
    end

    test "invalid names starting with numbers" do
      refute QName.valid_ncname?("123foo")
    end

    test "invalid names with colons" do
      refute QName.valid_ncname?("foo:bar")
    end

    test "invalid empty string" do
      refute QName.valid_ncname?("")
    end

    test "invalid names starting with hyphen" do
      refute QName.valid_ncname?("-foo")
    end

    test "invalid names starting with dot" do
      refute QName.valid_ncname?(".foo")
    end
  end

  describe "valid_qname?/1" do
    test "valid unprefixed QNames" do
      assert QName.valid_qname?("element")
      assert QName.valid_qname?("_element")
    end

    test "valid prefixed QNames" do
      assert QName.valid_qname?("ns:element")
      assert QName.valid_qname?("xml:lang")
    end

    test "invalid QNames with bad prefix" do
      refute QName.valid_qname?("123:element")
      refute QName.valid_qname?(":element")
    end

    test "invalid QNames with bad local part" do
      refute QName.valid_qname?("ns:123element")
      refute QName.valid_qname?("ns:")
    end

    test "invalid QNames with multiple colons" do
      # After the first colon, the local part can contain colons
      # but this is actually invalid per XML Namespaces spec
      refute QName.valid_qname?("a:b:c")
    end
  end

  describe "namespace_declaration?/1" do
    test "default namespace declaration" do
      assert QName.namespace_declaration?("xmlns") == {:default, nil}
    end

    test "prefixed namespace declaration" do
      assert QName.namespace_declaration?("xmlns:foo") == {:prefix, "foo"}
      assert QName.namespace_declaration?("xmlns:xml") == {:prefix, "xml"}
    end

    test "regular attributes" do
      assert QName.namespace_declaration?("id") == false
      assert QName.namespace_declaration?("foo:bar") == false
      assert QName.namespace_declaration?("xmlnsfoo") == false
    end
  end

  describe "prefix/1" do
    test "returns prefix for prefixed names" do
      assert QName.prefix("ns:element") == "ns"
    end

    test "returns nil for unprefixed names" do
      assert QName.prefix("element") == nil
    end
  end

  describe "local_part/1" do
    test "returns local part for prefixed names" do
      assert QName.local_part("ns:element") == "element"
    end

    test "returns full name for unprefixed names" do
      assert QName.local_part("element") == "element"
    end
  end
end
