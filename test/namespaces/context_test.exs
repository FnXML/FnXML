defmodule FnXML.Namespaces.ContextTest do
  use ExUnit.Case, async: true

  alias FnXML.Namespaces.Context

  @xml_ns "http://www.w3.org/XML/1998/namespace"
  @xmlns_ns "http://www.w3.org/2000/xmlns/"

  describe "new/1" do
    test "creates context with xml prefix pre-bound" do
      ctx = Context.new()
      assert {:ok, @xml_ns} = Context.resolve_prefix(ctx, "xml")
    end

    test "creates context with no default namespace" do
      ctx = Context.new()
      assert Context.default_namespace(ctx) == nil
    end

    test "can set xml_version" do
      ctx = Context.new(xml_version: "1.1")
      assert Context.xml_version(ctx) == "1.1"
    end
  end

  describe "push/3 and pop/1" do
    test "push creates child context" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      assert Context.default_namespace(child) == "http://example.org"
    end

    test "pop returns parent context" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      parent = Context.pop(child)
      assert Context.default_namespace(parent) == nil
    end

    test "pop on root returns root" do
      ctx = Context.new()
      assert Context.pop(ctx) == ctx
    end

    test "push with prefix binding" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      assert {:ok, "http://foo.org"} = Context.resolve_prefix(child, "foo")
    end

    test "push strips declarations when requested" do
      ctx = Context.new()
      attrs = [{"xmlns:foo", "http://foo.org"}, {"id", "1"}]
      {:ok, _child, filtered} = Context.push(ctx, attrs, strip_declarations: true)
      assert filtered == [{"id", "1"}]
    end

    test "push keeps declarations by default" do
      ctx = Context.new()
      attrs = [{"xmlns:foo", "http://foo.org"}, {"id", "1"}]
      {:ok, _child, kept} = Context.push(ctx, attrs)
      assert kept == attrs
    end
  end

  describe "resolve_prefix/2" do
    test "resolves xml prefix" do
      ctx = Context.new()
      assert {:ok, @xml_ns} = Context.resolve_prefix(ctx, "xml")
    end

    test "resolves xmlns prefix" do
      ctx = Context.new()
      assert {:ok, @xmlns_ns} = Context.resolve_prefix(ctx, "xmlns")
    end

    test "resolves declared prefix" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      assert {:ok, "http://foo.org"} = Context.resolve_prefix(child, "foo")
    end

    test "inherits prefix from parent" do
      ctx = Context.new()
      {:ok, child1, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      {:ok, child2, _} = Context.push(child1, [])
      assert {:ok, "http://foo.org"} = Context.resolve_prefix(child2, "foo")
    end

    test "child can shadow parent prefix" do
      ctx = Context.new()
      {:ok, child1, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      {:ok, child2, _} = Context.push(child1, [{"xmlns:foo", "http://other.org"}])
      assert {:ok, "http://other.org"} = Context.resolve_prefix(child2, "foo")
    end

    test "returns error for undeclared prefix" do
      ctx = Context.new()
      assert {:error, :undeclared_prefix} = Context.resolve_prefix(ctx, "unknown")
    end

    test "returns error for unbound prefix (XML 1.1)" do
      ctx = Context.new(xml_version: "1.1")
      {:ok, child1, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      {:ok, child2, _} = Context.push(child1, [{"xmlns:foo", ""}])
      assert {:error, :undeclared_prefix} = Context.resolve_prefix(child2, "foo")
    end
  end

  describe "default_namespace/1" do
    test "returns nil when no default" do
      ctx = Context.new()
      assert Context.default_namespace(ctx) == nil
    end

    test "returns declared default namespace" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      assert Context.default_namespace(child) == "http://example.org"
    end

    test "inherits default from parent" do
      ctx = Context.new()
      {:ok, child1, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      {:ok, child2, _} = Context.push(child1, [])
      assert Context.default_namespace(child2) == "http://example.org"
    end

    test "undeclares default with empty string" do
      ctx = Context.new()
      {:ok, child1, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      {:ok, child2, _} = Context.push(child1, [{"xmlns", ""}])
      assert Context.default_namespace(child2) == nil
    end
  end

  describe "expand_element/2" do
    test "unprefixed element uses default namespace" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      assert {:ok, {"http://example.org", "foo"}} = Context.expand_element(child, "foo")
    end

    test "unprefixed element has nil namespace when no default" do
      ctx = Context.new()
      assert {:ok, {nil, "foo"}} = Context.expand_element(ctx, "foo")
    end

    test "prefixed element uses prefix binding" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns:ns", "http://ns.org"}])
      assert {:ok, {"http://ns.org", "foo"}} = Context.expand_element(child, "ns:foo")
    end

    test "returns error for undeclared prefix" do
      ctx = Context.new()
      assert {:error, :undeclared_prefix} = Context.expand_element(ctx, "unknown:foo")
    end
  end

  describe "expand_attribute/2" do
    test "unprefixed attribute has no namespace" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      assert {:ok, {nil, "id"}} = Context.expand_attribute(child, "id")
    end

    test "prefixed attribute uses prefix binding" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns:ns", "http://ns.org"}])
      assert {:ok, {"http://ns.org", "attr"}} = Context.expand_attribute(child, "ns:attr")
    end

    test "xmlns declarations are in xmlns namespace" do
      ctx = Context.new()
      assert {:ok, {@xmlns_ns, "xmlns"}} = Context.expand_attribute(ctx, "xmlns")
      assert {:ok, {@xmlns_ns, "xmlns:foo"}} = Context.expand_attribute(ctx, "xmlns:foo")
    end
  end

  describe "reserved prefix validation" do
    test "cannot rebind xml prefix to wrong URI" do
      ctx = Context.new()

      assert {:error, {:reserved_prefix, "xml"}} =
               Context.push(ctx, [{"xmlns:xml", "http://wrong.org"}])
    end

    test "cannot bind other prefix to xml namespace" do
      ctx = Context.new()

      assert {:error, {:reserved_namespace, @xml_ns}} =
               Context.push(ctx, [{"xmlns:foo", @xml_ns}])
    end

    test "cannot use xmlns as prefix" do
      ctx = Context.new()

      assert {:error, {:reserved_prefix, "xmlns"}} =
               Context.push(ctx, [{"xmlns:xmlns", "http://example.org"}])
    end

    test "cannot bind anything to xmlns namespace" do
      ctx = Context.new()

      assert {:error, {:reserved_namespace, @xmlns_ns}} =
               Context.push(ctx, [{"xmlns:foo", @xmlns_ns}])
    end

    test "cannot unbind prefix in XML 1.0" do
      ctx = Context.new(xml_version: "1.0")
      {:ok, child, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])

      assert {:error, {:empty_prefix_binding, "foo"}} =
               Context.push(child, [{"xmlns:foo", ""}])
    end

    test "can unbind prefix in XML 1.1" do
      ctx = Context.new(xml_version: "1.1")
      {:ok, child1, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      assert {:ok, _child2, _} = Context.push(child1, [{"xmlns:foo", ""}])
    end
  end

  describe "all_prefixes/1" do
    test "includes xml prefix" do
      ctx = Context.new()
      prefixes = Context.all_prefixes(ctx)
      assert prefixes["xml"] == @xml_ns
    end

    test "includes declared prefixes" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      prefixes = Context.all_prefixes(child)
      assert prefixes["foo"] == "http://foo.org"
    end

    test "includes inherited prefixes" do
      ctx = Context.new()
      {:ok, child1, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      {:ok, child2, _} = Context.push(child1, [{"xmlns:bar", "http://bar.org"}])
      prefixes = Context.all_prefixes(child2)
      assert prefixes["foo"] == "http://foo.org"
      assert prefixes["bar"] == "http://bar.org"
    end
  end

  describe "in_scope?/2" do
    test "default namespace is in scope" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns", "http://example.org"}])
      assert Context.in_scope?(child, "http://example.org")
    end

    test "prefixed namespace is in scope" do
      ctx = Context.new()
      {:ok, child, _} = Context.push(ctx, [{"xmlns:foo", "http://foo.org"}])
      assert Context.in_scope?(child, "http://foo.org")
    end

    test "undeclared namespace is not in scope" do
      ctx = Context.new()
      refute Context.in_scope?(ctx, "http://unknown.org")
    end
  end
end
