defmodule FnXML.Parser.HTMLDoctypeTest do
  use ExUnit.Case, async: true

  # Define an HTML mode parser
  defmodule HTMLParser do
    use FnXML.Parser.Generator, edition: 5, mode: :html
  end

  describe "DOCTYPE error recovery in HTML mode" do
    test "unclosed double quote emits partial DOCTYPE and error" do
      events = HTMLParser.parse(~s(<!DOCTYPE potato taco "ddd>Hello)) |> Enum.to_list()

      # Should emit a DTD event with partial content
      assert Enum.any?(events, fn
               {:dtd, content, _, _, _} -> String.contains?(content, "DOCTYPE potato")
               _ -> false
             end)

      # Should emit an error for unterminated string
      assert Enum.any?(events, &match?({:error, :unterminated_doctype_string, _, _, _, _}, &1))

      # Should continue parsing and see "Hello" as content
      assert Enum.any?(events, fn
               {:characters, chars, _, _, _} -> String.contains?(chars, "Hello")
               _ -> false
             end)
    end

    test "unclosed single quote emits partial DOCTYPE and error" do
      events =
        HTMLParser.parse("<!DOCTYPE html SYSTEM 'http://example.com>text") |> Enum.to_list()

      assert Enum.any?(events, fn
               {:dtd, content, _, _, _} -> String.contains?(content, "DOCTYPE html")
               _ -> false
             end)

      assert Enum.any?(events, &match?({:error, :unterminated_doctype_string, _, _, _, _}, &1))
    end

    test "invalid character after quoted identifier emits error and scans to close" do
      events = HTMLParser.parse("<!DOCTYPE potato PUBLIC 'go'of'>Hello") |> Enum.to_list()

      # Should emit DTD with content up to the invalid point
      assert Enum.any?(events, fn
               {:dtd, content, _, _, _} ->
                 String.contains?(content, "DOCTYPE potato") and
                   String.contains?(content, "'go'")

               _ ->
                 false
             end)

      # Should emit error for unexpected char
      assert Enum.any?(events, &match?({:error, :unexpected_char_in_doctype, "o", _, _, _}, &1))

      # Should continue and parse "Hello"
      assert Enum.any?(events, fn
               {:characters, chars, _, _, _} -> String.contains?(chars, "Hello")
               _ -> false
             end)
    end

    test "valid DOCTYPE still works" do
      events = HTMLParser.parse("<!DOCTYPE html>content") |> Enum.to_list()

      assert Enum.any?(events, &match?({:dtd, "DOCTYPE html", _, _, _}, &1))

      assert Enum.any?(events, fn
               {:characters, chars, _, _, _} -> chars == "content"
               _ -> false
             end)

      refute Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))
    end

    test "DOCTYPE with PUBLIC identifier works" do
      events =
        HTMLParser.parse(
          ~s(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">)
        )
        |> Enum.to_list()

      assert Enum.any?(events, fn
               {:dtd, content, _, _, _} -> String.contains?(content, "PUBLIC")
               _ -> false
             end)

      refute Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))
    end

    test "DOCTYPE with internal subset works" do
      events =
        HTMLParser.parse("""
        <!DOCTYPE note [
          <!ELEMENT note (to,from)>
        ]><note/>
        """)
        |> Enum.to_list()

      assert Enum.any?(events, fn
               {:dtd, content, _, _, _} -> String.contains?(content, "<!ELEMENT")
               _ -> false
             end)
    end

    test "DOCTYPE with > inside quoted identifier triggers error in HTML mode" do
      # In HTML5, > inside a quoted identifier is an "abrupt-closing-of-DOCTYPE" error
      # The DOCTYPE is emitted up to the >, and parsing continues
      events =
        HTMLParser.parse(~s(<!DOCTYPE html SYSTEM "<!-- not a comment -->">)) |> Enum.to_list()

      # Should emit DTD with partial content (up to the first > inside quotes)
      assert Enum.any?(events, fn
               {:dtd, content, _, _, _} ->
                 String.contains?(content, "DOCTYPE html") and
                   String.contains?(content, "<!-- not a comment --")

               _ ->
                 false
             end)

      # Should emit an error for unterminated string (the > inside quotes)
      assert Enum.any?(events, &match?({:error, :unterminated_doctype_string, _, _, _, _}, &1))
    end
  end

  describe "XML mode DOCTYPE behavior unchanged" do
    defmodule XMLParser do
      use FnXML.Parser.Generator, edition: 5, mode: :xml
    end

    test "unclosed quote in XML mode returns empty events (incomplete parse)" do
      # XML mode should use incomplete() behavior - in one-shot mode
      # this means an incomplete parse with no events
      events = XMLParser.parse(~s(<!DOCTYPE potato "unterminated)) |> Enum.to_list()

      # Should NOT emit a DTD event (incomplete parse)
      refute Enum.any?(events, &match?({:dtd, _, _, _, _}, &1))
    end

    test "invalid char after quote in XML mode returns incomplete (no error recovery)" do
      # XML mode doesn't have HTML-style error recovery
      # The 'b' after 'a' is parsed as content, but then we never find a proper closing
      # structure, so it returns incomplete (empty events in one-shot mode)
      events = XMLParser.parse("<!DOCTYPE x PUBLIC 'a'b'>") |> Enum.to_list()

      # In XML mode without error recovery, malformed DOCTYPE returns incomplete
      # (empty events because no complete events were emitted before incomplete state)
      assert events == [] or not Enum.any?(events, &match?({:dtd, _, _, _, _}, &1))
    end
  end
end
