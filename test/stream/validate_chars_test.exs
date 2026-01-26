defmodule FnXML.ValidateCharsTest do
  use ExUnit.Case, async: true

  alias FnXML.Validate

  describe "characters/2" do
    test "passes valid text through unchanged" do
      events = [
        {:start_document, nil},
        {:characters, "Hello World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      assert result == events
    end

    test "detects NUL character in text" do
      events = [
        {:start_document, nil},
        {:characters, "Hello\x00World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "Invalid XML character")
               _ -> false
             end)
    end

    test "detects control characters" do
      events = [
        {:start_document, nil},
        {:characters, "Hello\x01World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "Invalid XML character")
               _ -> false
             end)
    end

    test "allows tab, LF, CR" do
      events = [
        {:start_document, nil},
        {:characters, "Hello\t\n\rWorld", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      refute Enum.any?(result, fn
               {:error, _, _} -> true
               _ -> false
             end)
    end

    test "validates attribute values" do
      events = [
        {:start_document, nil},
        {:start_element, "a", [{"b", "Hello\x00World"}], 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "attribute")
               _ -> false
             end)
    end

    test "skip mode removes invalid characters" do
      events = [
        {:start_document, nil},
        {:characters, "Hello\x00World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters(on_error: :skip) |> Enum.to_list()

      assert Enum.any?(result, fn
               {:characters, "HelloWorld", _} -> true
               _ -> false
             end)
    end

    test "replace mode substitutes invalid characters" do
      events = [
        {:start_document, nil},
        {:characters, "Hello\x00World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters(on_error: {:replace, "?"}) |> Enum.to_list()

      assert Enum.any?(result, fn
               {:characters, "Hello?World", _} -> true
               _ -> false
             end)
    end

    test "validates CDATA content" do
      events = [
        {:start_document, nil},
        {:cdata, "Hello\x00World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "Invalid XML character")
               _ -> false
             end)
    end

    test "validates comment content" do
      events = [
        {:start_document, nil},
        {:comment, "Hello\x00World", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.characters() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "Invalid XML character")
               _ -> false
             end)
    end
  end

  describe "comments/2" do
    test "passes valid comments through unchanged" do
      events = [
        {:start_document, nil},
        {:comment, " This is a valid comment ", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.comments() |> Enum.to_list()

      assert result == events
    end

    test "allows single hyphens" do
      events = [
        {:start_document, nil},
        {:comment, " single - hyphen - ok ", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.comments() |> Enum.to_list()

      refute Enum.any?(result, fn
               {:error, _, _} -> true
               _ -> false
             end)
    end

    test "detects double-hyphen in comment" do
      events = [
        {:start_document, nil},
        {:comment, " invalid -- comment ", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.comments() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "--")
               _ -> false
             end)
    end

    test "detects double-hyphen at start" do
      events = [
        {:start_document, nil},
        {:comment, "-- at start", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.comments() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "--")
               _ -> false
             end)
    end

    test "detects consecutive double-hyphens" do
      events = [
        {:start_document, nil},
        {:comment, " triple --- hyphen ", 1, 0, 0},
        {:end_document, nil}
      ]

      result = events |> Validate.comments() |> Enum.to_list()

      assert Enum.any?(result, fn
               {:error, msg, _} -> String.contains?(msg, "--")
               _ -> false
             end)
    end

    test "raise mode raises exception" do
      events = [
        {:start_document, nil},
        {:comment, " invalid -- comment ", 1, 0, 0},
        {:end_document, nil}
      ]

      assert_raise RuntimeError, ~r/--/, fn ->
        events |> Validate.comments(on_error: :raise) |> Enum.to_list()
      end
    end
  end
end
