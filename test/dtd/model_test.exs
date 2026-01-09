defmodule FnXML.DTD.ModelTest do
  use ExUnit.Case, async: true

  alias FnXML.DTD.Model

  describe "new/0" do
    test "creates empty model" do
      model = Model.new()
      assert model.elements == %{}
      assert model.attributes == %{}
      assert model.entities == %{}
      assert model.param_entities == %{}
      assert model.notations == %{}
      assert model.root_element == nil
    end
  end

  describe "add_element/3" do
    test "adds element with EMPTY content model" do
      model = Model.new() |> Model.add_element("br", :empty)
      assert model.elements["br"] == :empty
    end

    test "adds element with ANY content model" do
      model = Model.new() |> Model.add_element("container", :any)
      assert model.elements["container"] == :any
    end

    test "adds element with PCDATA content model" do
      model = Model.new() |> Model.add_element("p", :pcdata)
      assert model.elements["p"] == :pcdata
    end

    test "adds element with sequence content model" do
      model = Model.new() |> Model.add_element("note", {:seq, ["to", "from", "body"]})
      assert model.elements["note"] == {:seq, ["to", "from", "body"]}
    end

    test "adds element with choice content model" do
      model = Model.new() |> Model.add_element("choice", {:choice, ["a", "b", "c"]})
      assert model.elements["choice"] == {:choice, ["a", "b", "c"]}
    end

    test "adds multiple elements" do
      model =
        Model.new()
        |> Model.add_element("br", :empty)
        |> Model.add_element("p", :pcdata)
        |> Model.add_element("div", {:seq, ["p", "br"]})

      assert model.elements["br"] == :empty
      assert model.elements["p"] == :pcdata
      assert model.elements["div"] == {:seq, ["p", "br"]}
    end
  end

  describe "add_attributes/3" do
    test "adds attribute definitions" do
      attrs = [
        %{name: "id", type: :id, default: :required},
        %{name: "class", type: :cdata, default: :implied}
      ]

      model = Model.new() |> Model.add_attributes("div", attrs)
      assert model.attributes["div"] == attrs
    end

    test "merges attribute definitions for same element" do
      attrs1 = [%{name: "id", type: :id, default: :required}]
      attrs2 = [%{name: "class", type: :cdata, default: :implied}]

      model =
        Model.new()
        |> Model.add_attributes("div", attrs1)
        |> Model.add_attributes("div", attrs2)

      assert model.attributes["div"] == attrs1 ++ attrs2
    end
  end

  describe "add_entity/3" do
    test "adds internal entity" do
      model = Model.new() |> Model.add_entity("copyright", {:internal, "(c) 2024"})
      assert model.entities["copyright"] == {:internal, "(c) 2024"}
    end

    test "adds external entity" do
      model = Model.new() |> Model.add_entity("logo", {:external, "logo.gif", nil})
      assert model.entities["logo"] == {:external, "logo.gif", nil}
    end
  end

  describe "add_param_entity/3" do
    test "adds parameter entity" do
      model = Model.new() |> Model.add_param_entity("colors", "red | green | blue")
      assert model.param_entities["colors"] == "red | green | blue"
    end
  end

  describe "add_notation/4" do
    test "adds notation" do
      model = Model.new() |> Model.add_notation("gif", "image/gif", nil)
      assert model.notations["gif"] == {"image/gif", nil}
    end
  end

  describe "set_root_element/2" do
    test "sets root element name" do
      model = Model.new() |> Model.set_root_element("html")
      assert model.root_element == "html"
    end
  end

  describe "get_* functions" do
    setup do
      model =
        Model.new()
        |> Model.add_element("note", {:seq, ["to", "body"]})
        |> Model.add_attributes("note", [%{name: "id", type: :id, default: :required}])
        |> Model.add_entity("copyright", {:internal, "(c)"})
        |> Model.add_param_entity("common", "attrs")
        |> Model.add_notation("gif", "image/gif", nil)

      {:ok, model: model}
    end

    test "get_element returns content model", %{model: model} do
      assert Model.get_element(model, "note") == {:seq, ["to", "body"]}
      assert Model.get_element(model, "unknown") == nil
    end

    test "get_attributes returns attr definitions", %{model: model} do
      assert Model.get_attributes(model, "note") == [%{name: "id", type: :id, default: :required}]
      assert Model.get_attributes(model, "unknown") == []
    end

    test "get_entity returns entity definition", %{model: model} do
      assert Model.get_entity(model, "copyright") == {:internal, "(c)"}
      assert Model.get_entity(model, "unknown") == nil
    end

    test "get_param_entity returns value", %{model: model} do
      assert Model.get_param_entity(model, "common") == "attrs"
      assert Model.get_param_entity(model, "unknown") == nil
    end

    test "get_notation returns notation def", %{model: model} do
      assert Model.get_notation(model, "gif") == {"image/gif", nil}
      assert Model.get_notation(model, "unknown") == nil
    end
  end
end
