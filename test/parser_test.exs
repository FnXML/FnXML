defmodule FnXML.ParserTest do
  use ExUnit.Case
  doctest FnXML.Parser

  def parse_xml(xml) do
    xml
    |> FnXML.Parser.parse()
    |> Enum.map(fn x -> x end)
  end

  def filter_loc(tag_list) do
    tag_list
    |> Enum.map(fn {id, list} -> {id, Enum.filter(list, fn
                                     {k, _v} -> k != :loc
                                     _ -> true
                                   end)}
    end)
  end

  # tag tests; single tag with variations
  test "open and close tag" do
    result = parse_xml("<a></a>") |> filter_loc()
    assert result == [open: [tag: "a"], close: [tag: "a"]]
  end

  test "empty tag" do
    result = parse_xml("<a/>") |> filter_loc()
    assert result == [open: [tag: "a"], close: [tag: "a"]]
  end

  test "tag with namespace" do
    result = parse_xml("<a:b></a:b>") |> filter_loc()
    assert result == [open: [tag: "b", namespace: "a"], close: [tag: "b", namespace: "a"]]
  end

  test "attributes" do
    result = parse_xml("<a b=\"c\" d=\"e\"/>") |> filter_loc()
    assert result == [open: [tag: "a", attributes: [{"b", "c"}, {"d", "e"}]], close: [tag: "a"]]
  end

  test "text" do
    result = parse_xml("<a>text</a>") |> filter_loc()
    assert result == [open: [tag: "a"], text: ["text"], close: [tag: "a"]]
  end

  test "tag with all meta" do
    result = parse_xml("<ns:a b=\"c\" d=\"e\">text</ns:a>") |> filter_loc()
    assert result == [
      open: [tag: "a", namespace: "ns", attributes: [{"b", "c"}, {"d", "e"}]],
      text: ["text"],
      close: [tag: "a", namespace: "ns"]
    ]
  end

  test "that '-', '_', '.' can be included in tags and namespaces" do
    input = "<my-env:fancy_tag.with-punc></my-env:fancy_tag.with-punc>"
    assert parse_xml(input) |> Enum.to_list() == [
      open: [tag: "fancy_tag.with-punc", namespace: "my-env", loc: {{1, 0}, 1}],
      close: [tag: "fancy_tag.with-punc", namespace: "my-env", loc: {{1, 0}, 30}]
    ]
  end

  # nested tag tests
  
  test "test 2" do
    result = parse_xml("<ns:foo a='1'><bar>message</bar></ns:foo>")
    assert result == [
             {:open, [tag: "foo", namespace: "ns", attributes: [{"a", "1"}], loc: {{1, 0}, 1}]},
             {:open, [tag: "bar", loc: {{1, 0}, 15}]},
             {:text, ["message", {:loc, {{1, 0}, 26}}]},
             {:close, [tag: "bar", loc: {{1, 0}, 28}]},
             {:close, [tag: "foo", namespace: "ns", loc: {{1, 0}, 34}]}
           ]
  end


  test "single nested tag" do
    xml = "<a><b/></a>"
    result = parse_xml(xml) |> filter_loc()
    assert result == [
      open: [tag: "a"],
      open: [tag: "b"],
      close: [tag: "b"],
      close: [tag: "a"]
    ]
  end

  test "list of nested tags" do
    xml = "<a><b/><c/><d/></a>"
    result = parse_xml(xml) |> filter_loc()
    assert result == [
      open: [tag: "a"],
      open: [tag: "b"], close: [tag: "b"],
      open: [tag: "c"], close: [tag: "c"],
      open: [tag: "d"], close: [tag: "d"],
      close: [tag: "a"]
    ]
  end

  test "list of nested tags with text" do
    xml = "<a>b-text<b></b>c-text<c></c>d-text<d></d>post-text</a>"
    result = parse_xml(xml) |> filter_loc()
    assert result == [
      open: [tag: "a"],
      text: ["b-text"],
      open: [tag: "b"], close: [tag: "b"],
      text: ["c-text"],
      open: [tag: "c"], close: [tag: "c"],
      text: ["d-text"],
      open: [tag: "d"], close: [tag: "d"],
      text: ["post-text"],
      close: [tag: "a"]
    ]
  end

  describe "white space" do
    test "tag without ws" do
      result = parse_xml("<a></a>") |> filter_loc()
      assert result == [{:open, [tag: "a"]}, {:close, [tag: "a"]}]
    end
    test "tag with ws before name" do
      result = parse_xml("< a></ a>") |> filter_loc()
      assert result == [{:open, [tag: "a"]}, {:close, [tag: "a"]}]
    end
    test "tag with ws after name" do
      result = parse_xml("<a ></a >") |> filter_loc()
      assert result == [{:open, [tag: "a"]}, {:close, [tag: "a"]}]
    end
    test "tag with ws before and after name" do
      result = parse_xml("< a ></ a >") |> filter_loc()
      assert result == [{:open, [tag: "a"]}, {:close, [tag: "a"]}]
    end
    test "tag with tab" do
      result = parse_xml("<a\t></a>") |> filter_loc()
      assert result == [{:open, [tag: "a"]}, {:close, [tag: "a"]}]
    end
    test "tag with tab before and after" do
      result = parse_xml("<\ta\t></\ta\t>") |> filter_loc()
      assert result == [{:open, [tag: "a"]}, {:close, [tag: "a"]}]
    end
    test "namespace:tag with ws" do
      result = parse_xml("<\tns :\ta ></ ns\t: a\t>") |> filter_loc()
      assert result == [{:open, [tag: "a", namespace: "ns"]}, {:close, [tag: "a", namespace: "ns"]}]
    end

  end
end
