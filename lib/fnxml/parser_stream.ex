defmodule FnXML.ParserStream do
  @moduledoc """
  Streaming XML parser using position tracking for zero-copy extraction.

  This parser processes XML from any Elixir Stream (like `File.stream!/1`)
  using position tracking instead of buffer accumulation for better performance.

  ## Usage

      File.stream!("/path/to/file.xml", [], 65536)
      |> FnXML.ParserStream.parse()
      |> Enum.to_list()

  ## Options

  - `:mode` - `:lazy` (default) or `:eager`
    - `:lazy` - Pull chunks on demand using Enumerable.reduce with :suspend
    - `:eager` - Convert stream to list upfront (simpler, may use more memory)
  """

  # Guards for name characters
  defguardp is_name_start(c)
            when c in ?a..?z or c in ?A..?Z or c == ?_ or c == ?: or
                   c in 0x00C0..0x00D6 or c in 0x00D8..0x00F6 or
                   c in 0x00F8..0x02FF or c in 0x0370..0x037D or
                   c in 0x037F..0x1FFF or c in 0x200C..0x200D or
                   c in 0x2070..0x218F or c in 0x2C00..0x2FEF or
                   c in 0x3001..0xD7FF or c in 0xF900..0xFDCF or
                   c in 0xFDF0..0xFFFD or c in 0x10000..0xEFFFF

  defguardp is_name_char(c)
            when is_name_start(c) or c == ?- or c == ?. or c in ?0..?9 or
                   c == 0x00B7 or c in 0x0300..0x036F or c in 0x203F..0x2040

  defguardp is_whitespace(c) when c == ?\s or c == ?\t or c == ?\r or c == ?\n

  # Calculate byte size of a UTF-8 codepoint
  defp utf8_size(c) when c < 0x80, do: 1
  defp utf8_size(c) when c < 0x800, do: 2
  defp utf8_size(c) when c < 0x10000, do: 3
  defp utf8_size(_), do: 4

  # Initial state with all possible keys to avoid KeyError when updating
  defp initial_state(emit) do
    %{
      emit: emit,
      line: 1,
      line_start: 0,
      __resume: nil,
      __text_start: nil,
      __tag_start: nil,
      __tag: nil,
      __attrs: nil,
      __loc: nil,
      __attr_start: nil,
      __attr_name: nil,
      __quote: nil,
      __acc: nil,
      __entity_start: nil,
      __entity_context: nil,
      __loc_pos: nil,
      __pi_start: nil,
      __pi_target: nil,
      __prolog_attrs: nil,
      __prolog_attr_start: nil,
      __prolog_attr_name: nil,
      __prolog_quote: nil,
      __comment_start: nil,
      __cdata_start: nil,
      __doctype_depth: nil,
      __doctype_start: nil,
      __doctype_loc: nil
    }
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Parse XML from any stream of binary chunks.

  Returns a Stream of XML events.
  """
  def parse(stream, opts \\ []) do
    mode = Keyword.get(opts, :mode, :lazy)
    cont = make_continuation(stream, mode)

    Stream.resource(
      fn -> {:start, cont} end,
      &produce_events/1,
      fn _ -> :ok end
    )
  end

  @doc """
  Parse XML from a stream with a callback function.
  """
  def parse(stream, emit, opts) when is_function(emit, 1) do
    mode = Keyword.get(opts, :mode, :lazy)
    cont = make_continuation(stream, mode)

    emit.({:start_document, nil})

    case cont.() do
      {:more, chunk, new_cont} ->
        check_encoding!(chunk)
        state = initial_state(emit)
        do_parse(chunk, true, chunk, 0, state, new_cont)

      :eof ->
        :ok
    end

    emit.({:end_document, nil})
    :ok
  end

  # ============================================================================
  # Continuation Builders
  # ============================================================================

  defp make_continuation(stream, :eager) do
    make_cont_from_list(Enum.to_list(stream))
  end

  defp make_continuation(stream, :lazy) do
    make_lazy_continuation(stream)
  end

  defp make_cont_from_list([]) do
    fn -> :eof end
  end

  defp make_cont_from_list([chunk | rest]) do
    fn -> {:more, chunk, make_cont_from_list(rest)} end
  end

  defp make_lazy_continuation(stream) do
    case Enumerable.reduce(stream, {:cont, nil}, fn chunk, _ -> {:suspend, chunk} end) do
      {:suspended, chunk, reducer_cont} ->
        fn -> {:more, chunk, wrap_reducer(reducer_cont)} end

      {:done, _} ->
        fn -> :eof end

      {:halted, chunk} when is_binary(chunk) ->
        fn -> {:more, chunk, fn -> :eof end} end

      {:halted, _} ->
        fn -> :eof end
    end
  end

  defp wrap_reducer(reducer_cont) do
    fn ->
      case reducer_cont.({:cont, nil}) do
        {:suspended, chunk, next_cont} ->
          {:more, chunk, wrap_reducer(next_cont)}

        {:done, _} ->
          :eof

        {:halted, _} ->
          :eof
      end
    end
  end

  # ============================================================================
  # Stream.resource callbacks
  # ============================================================================

  # Detect UTF-16 BOM and raise helpful error
  defp check_encoding!(<<0xFF, 0xFE, _::binary>>) do
    raise ArgumentError, """
    UTF-16 Little Endian encoding detected (BOM: 0xFF 0xFE).

    FnXML.ParserStream expects UTF-8 input. Convert first:

        File.stream!("file.xml")
        |> FnXML.Utf16.to_utf8()
        |> FnXML.ParserStream.parse()
    """
  end

  defp check_encoding!(<<0xFE, 0xFF, _::binary>>) do
    raise ArgumentError, """
    UTF-16 Big Endian encoding detected (BOM: 0xFE 0xFF).

    FnXML.ParserStream expects UTF-8 input. Convert first:

        File.stream!("file.xml")
        |> FnXML.Utf16.to_utf8()
        |> FnXML.ParserStream.parse()
    """
  end

  defp check_encoding!(_), do: :ok

  defp produce_events({:start, cont}) do
    case cont.() do
      {:more, chunk, new_cont} ->
        check_encoding!(chunk)
        state = initial_state(nil)
        {[{:start_document, nil}], {:parsing, chunk, true, chunk, 0, state, new_cont}}

      :eof ->
        {[{:start_document, nil}, {:end_document, nil}], :done}
    end
  end

  defp produce_events({:parsing, buffer, more?, original, pos, state, cont}) do
    # Collect events using process dictionary
    Process.put(:stream_events, [])
    emit = fn event -> Process.put(:stream_events, [event | Process.get(:stream_events)]) end
    state = %{state | emit: emit}

    case resume_parse(buffer, more?, original, pos, state, cont) do
      {:ok, _state} ->
        events = Process.get(:stream_events) |> Enum.reverse()
        Process.delete(:stream_events)
        {events ++ [{:end_document, nil}], :done}

      {:halted, cont_fun, new_state, new_cont} ->
        events = Process.get(:stream_events) |> Enum.reverse()
        Process.delete(:stream_events)

        case new_cont.() do
          {:more, chunk, next_cont} ->
            {new_buffer, new_more?, new_original, new_pos, updated_state} =
              cont_fun.(chunk, true, new_state)

            {events,
             {:parsing, new_buffer, new_more?, new_original, new_pos, updated_state, next_cont}}

          :eof ->
            {new_buffer, new_more?, new_original, new_pos, updated_state} =
              cont_fun.(<<>>, false, new_state)

            case resume_parse(new_buffer, new_more?, new_original, new_pos, updated_state, fn ->
                   :eof
                 end) do
              {:ok, _} ->
                final_events = Process.get(:stream_events, []) |> Enum.reverse()
                Process.delete(:stream_events)
                {events ++ final_events ++ [{:end_document, nil}], :done}

              {:error, reason, loc} ->
                {events ++ [{:error, reason, loc}, {:end_document, nil}], :done}
            end
        end

      {:error, reason, loc} ->
        events = Process.get(:stream_events) |> Enum.reverse()
        Process.delete(:stream_events)
        {events ++ [{:error, reason, loc}, {:end_document, nil}], :done}
    end
  end

  defp produce_events(:done), do: {:halt, :done}

  # ============================================================================
  # Main parse loop for callback API
  # ============================================================================

  defp do_parse(buffer, more?, original, pos, state, cont) do
    case resume_parse(buffer, more?, original, pos, state, cont) do
      {:ok, _state} ->
        :ok

      {:halted, cont_fun, new_state, new_cont} ->
        case new_cont.() do
          {:more, chunk, next_cont} ->
            {new_buffer, new_more?, new_original, new_pos, updated_state} =
              cont_fun.(chunk, true, new_state)

            do_parse(new_buffer, new_more?, new_original, new_pos, updated_state, next_cont)

          :eof ->
            {new_buffer, new_more?, new_original, new_pos, updated_state} =
              cont_fun.(<<>>, false, new_state)

            do_parse(new_buffer, new_more?, new_original, new_pos, updated_state, fn -> :eof end)
        end

      {:error, _reason, _loc} ->
        :ok
    end
  end

  # ============================================================================
  # Halt macro - creates continuation function
  # ============================================================================

  # Helper to trim processed data from original and adjust position
  defp maybe_trim(true, original, pos) when pos > 4096 do
    new_original = binary_part(original, pos, byte_size(original) - pos)
    {new_original, 0}
  end

  defp maybe_trim(_more?, original, pos), do: {original, pos}

  # ============================================================================
  # Resume Dispatcher
  # ============================================================================

  # Routes to correct parsing function based on __resume key in state
  # Note: We don't delete keys from state to avoid KeyError when updating later
  defp resume_parse(buffer, more?, original, pos, state, cont) do
    case state.__resume do
      nil ->
        parse_content(buffer, more?, original, pos, state, cont)

      :parse_content ->
        parse_content(buffer, more?, original, pos, %{state | __resume: nil}, cont)

      :parse_tag_start ->
        parse_tag_start(buffer, more?, original, pos, %{state | __resume: nil}, cont)

      :parse_text ->
        start = state.__text_start
        parse_text(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_open_tag_name ->
        start = state.__tag_start
        parse_open_tag_name(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_attributes ->
        {tag, attrs, loc} = {state.__tag, state.__attrs, state.__loc}

        parse_attributes(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc
        )

      :parse_attr_name ->
        {tag, attrs, loc, start} = {state.__tag, state.__attrs, state.__loc, state.__attr_start}

        parse_attr_name(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc
        )

      :parse_attr_eq ->
        {tag, attrs, loc, attr_name} =
          {state.__tag, state.__attrs, state.__loc, state.__attr_name}

        parse_attr_eq(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc,
          attr_name
        )

      :parse_attr_quote ->
        {tag, attrs, loc, attr_name} =
          {state.__tag, state.__attrs, state.__loc, state.__attr_name}

        parse_attr_quote(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc,
          attr_name
        )

      :parse_attr_value ->
        {tag, attrs, loc, attr_name, start, quote_char, acc} =
          {state.__tag, state.__attrs, state.__loc, state.__attr_name, state.__attr_start,
           state.__quote, state.__acc}

        parse_attr_value(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc,
          attr_name,
          quote_char,
          acc
        )

      :parse_attr_entity ->
        {tag, attrs, loc, attr_name, start, quote_char, acc} =
          {state.__tag, state.__attrs, state.__loc, state.__attr_name, state.__entity_start,
           state.__quote, state.__acc}

        parse_attr_entity(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc,
          attr_name,
          quote_char,
          acc
        )

      :parse_self_close ->
        {tag, attrs, loc} = {state.__tag, state.__attrs, state.__loc}

        parse_self_close(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          attrs,
          loc
        )

      :parse_close_tag ->
        {name_start, loc_pos} = {state.__tag_start, state.__loc_pos}

        parse_close_tag(
          buffer,
          more?,
          original,
          loc_pos,
          name_start,
          pos,
          %{state | __resume: nil},
          cont
        )

      :parse_close_tag_end ->
        {tag, tag_start} = {state.__tag, state.__tag_start}

        parse_close_tag_end(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          tag,
          tag_start
        )

      :parse_pi_content ->
        {target, start} = {state.__pi_target, state.__pi_start}

        parse_pi_content(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          target
        )

      :parse_prolog_after_question ->
        attrs = state.__prolog_attrs

        parse_prolog_maybe_end(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          attrs
        )

      :parse_prolog_attr_name ->
        {attrs, start} = {state.__prolog_attrs, state.__prolog_attr_start}

        parse_prolog_attr_name(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          attrs
        )

      :parse_prolog_attr_eq ->
        {attrs, attr_name} = {state.__prolog_attrs, state.__prolog_attr_name}

        parse_prolog_attr_eq(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          attrs,
          attr_name
        )

      :parse_prolog_attr_quote ->
        {attrs, attr_name} = {state.__prolog_attrs, state.__prolog_attr_name}

        parse_prolog_attr_quote(
          buffer,
          more?,
          original,
          pos,
          %{state | __resume: nil},
          cont,
          attrs,
          attr_name
        )

      :parse_prolog_attr_value ->
        {attrs, attr_name, start, quote_char} =
          {state.__prolog_attrs, state.__prolog_attr_name, state.__prolog_attr_start,
           state.__prolog_quote}

        parse_prolog_attr_value(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          attrs,
          attr_name,
          quote_char
        )

      :parse_comment ->
        start = state.__comment_start
        parse_comment(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_comment_end ->
        start = state.__comment_start
        parse_comment(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_cdata ->
        start = state.__cdata_start
        parse_cdata(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_cdata_end ->
        start = state.__cdata_start
        parse_cdata(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_doctype ->
        {depth, start, loc} = {state.__doctype_depth, state.__doctype_start, state.__doctype_loc}

        parse_doctype(
          buffer,
          more?,
          original,
          pos,
          loc,
          start,
          depth,
          %{state | __resume: nil},
          cont
        )

      :parse_entity_ref ->
        {start, context} = {state.__entity_start, state.__entity_context}

        parse_entity_ref(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          context
        )

      :parse_element_content ->
        parse_element_content(buffer, more?, original, pos, %{state | __resume: nil}, cont)

      :parse_pi ->
        start = state.__pi_start
        parse_pi(buffer, more?, original, start, pos, %{state | __resume: nil}, cont)

      :parse_pi_content_maybe_end ->
        {target, start} = {state.__pi_target, state.__pi_start}

        parse_pi_content_maybe_end(
          buffer,
          more?,
          original,
          start,
          pos,
          %{state | __resume: nil},
          cont,
          target
        )

      :parse_prolog ->
        attrs = state.__prolog_attrs
        parse_prolog(buffer, more?, original, pos, %{state | __resume: nil}, cont, attrs)

      :parse_bang ->
        parse_bang(buffer, more?, original, pos, %{state | __resume: nil}, cont)
    end
  end

  # ============================================================================
  # Content Parsing
  # ============================================================================

  defp parse_content(<<>>, true, original, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_content}, cont}
  end

  defp parse_content(<<>>, false, _original, _pos, state, _cont) do
    {:ok, state}
  end

  defp parse_content(<<"<", rest::binary>>, more?, original, pos, state, cont) do
    parse_tag_start(rest, more?, original, pos + 1, state, cont)
  end

  defp parse_content(<<c, rest::binary>>, more?, original, pos, state, cont)
       when is_whitespace(c) do
    case c do
      ?\n ->
        state = %{state | line: state.line + 1, line_start: pos + 1}
        parse_content(rest, more?, original, pos + 1, state, cont)

      _ ->
        parse_content(rest, more?, original, pos + 1, state, cont)
    end
  end

  defp parse_content(<<_::binary>> = buffer, more?, original, pos, state, cont) do
    parse_text(buffer, more?, original, pos, pos, state, cont)
  end

  # ============================================================================
  # Text Content
  # ============================================================================

  defp parse_text(<<>>, true, original, pos, start, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {<<>>, more?, new_original, pos, st}
     end, %{state | __resume: :parse_text, __text_start: start}, cont}
  end

  defp parse_text(<<>>, false, original, pos, start, state, _cont) do
    if pos > start do
      text = binary_part(original, start, pos - start)
      loc = {state.line, state.line_start, start}
      state.emit.({:characters, text, loc})
    end

    {:ok, state}
  end

  defp parse_text(<<"<", _::binary>> = rest, more?, original, pos, start, state, cont) do
    if pos > start do
      text = binary_part(original, start, pos - start)
      loc = {state.line, state.line_start, start}
      state.emit.({:characters, text, loc})
    end

    parse_content(rest, more?, original, pos, state, cont)
  end

  defp parse_text(<<"&", rest::binary>>, more?, original, pos, start, state, cont) do
    # Emit text before entity
    if pos > start do
      text = binary_part(original, start, pos - start)
      loc = {state.line, state.line_start, start}
      state.emit.({:characters, text, loc})
    end

    parse_entity_ref(rest, more?, original, pos + 1, pos + 1, state, cont, :text)
  end

  defp parse_text(<<?\n, rest::binary>>, more?, original, pos, start, state, cont) do
    state = %{state | line: state.line + 1, line_start: pos + 1}
    parse_text(rest, more?, original, pos + 1, start, state, cont)
  end

  defp parse_text(<<_, rest::binary>>, more?, original, pos, start, state, cont) do
    parse_text(rest, more?, original, pos + 1, start, state, cont)
  end

  # ============================================================================
  # Tag Start
  # ============================================================================

  defp parse_tag_start(<<>>, true, original, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_tag_start}, cont}
  end

  defp parse_tag_start(<<>>, false, _original, pos, state, _cont) do
    {:error, "Unexpected EOF after <", {state.line, state.line_start, pos}}
  end

  defp parse_tag_start(<<"?", rest::binary>>, more?, original, pos, state, cont) do
    parse_pi(rest, more?, original, pos + 1, pos + 1, state, cont)
  end

  defp parse_tag_start(<<"!", rest::binary>>, more?, original, pos, state, cont) do
    parse_bang(rest, more?, original, pos + 1, state, cont)
  end

  defp parse_tag_start(<<"/", rest::binary>>, more?, original, pos, state, cont) do
    # loc_pos = pos (position of /) for location reporting to match FnXML.Parser
    # name_start = pos + 1 (position of first char of tag name)
    parse_close_tag(rest, more?, original, pos, pos + 1, pos + 1, state, cont)
  end

  defp parse_tag_start(<<c::utf8, rest::binary>>, more?, original, pos, state, cont)
       when is_name_start(c) do
    parse_open_tag_name(rest, more?, original, pos, pos + utf8_size(c), state, cont)
  end

  defp parse_tag_start(_, _, _original, pos, state, _cont) do
    {:error, "Invalid character after <", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Open Tag
  # ============================================================================

  defp parse_open_tag_name(<<>>, true, original, start, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_open_tag_name, __tag_start: start}, cont}
  end

  defp parse_open_tag_name(<<>>, false, _original, _start, pos, state, _cont) do
    {:error, "Unexpected EOF in tag name", {state.line, state.line_start, pos}}
  end

  defp parse_open_tag_name(<<c::utf8, rest::binary>>, more?, original, start, pos, state, cont)
       when is_name_char(c) do
    parse_open_tag_name(rest, more?, original, start, pos + utf8_size(c), state, cont)
  end

  defp parse_open_tag_name(rest, more?, original, start, pos, state, cont) do
    tag_name = binary_part(original, start, pos - start)
    loc = {state.line, state.line_start, start}
    parse_attributes(rest, more?, original, pos, state, cont, tag_name, [], loc)
  end

  # ============================================================================
  # Attributes
  # ============================================================================

  defp parse_attributes(<<>>, true, original, pos, state, cont, tag, attrs, loc) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_attributes, __tag: tag, __attrs: attrs, __loc: loc}, cont}
  end

  defp parse_attributes(<<>>, false, _original, pos, state, _cont, _tag, _attrs, _loc) do
    {:error, "Unexpected EOF in attributes", {state.line, state.line_start, pos}}
  end

  defp parse_attributes(<<c, rest::binary>>, more?, original, pos, state, cont, tag, attrs, loc)
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_attributes(rest, more?, original, pos + 1, state, cont, tag, attrs, loc)
  end

  defp parse_attributes(<<">", rest::binary>>, more?, original, pos, state, cont, tag, attrs, loc) do
    state.emit.({:start_element, tag, Enum.reverse(attrs), loc})
    {new_original, new_pos} = maybe_trim(more?, original, pos + 1)
    parse_element_content(rest, more?, new_original, new_pos, state, cont)
  end

  defp parse_attributes(<<"/", rest::binary>>, more?, original, pos, state, cont, tag, attrs, loc) do
    parse_self_close(rest, more?, original, pos + 1, state, cont, tag, attrs, loc)
  end

  defp parse_attributes(
         <<c::utf8, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc
       )
       when is_name_start(c) do
    parse_attr_name(rest, more?, original, pos, pos + utf8_size(c), state, cont, tag, attrs, loc)
  end

  defp parse_attributes(_, _, _original, pos, state, _cont, _tag, _attrs, _loc) do
    {:error, "Invalid character in attributes", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Attribute Name
  # ============================================================================

  defp parse_attr_name(<<>>, true, original, start, pos, state, cont, tag, attrs, loc) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_attr_name,
         __attr_start: start,
         __tag: tag,
         __attrs: attrs,
         __loc: loc
     }, cont}
  end

  defp parse_attr_name(<<>>, false, _original, _start, pos, state, _cont, _tag, _attrs, _loc) do
    {:error, "Unexpected EOF in attribute name", {state.line, state.line_start, pos}}
  end

  defp parse_attr_name(
         <<c::utf8, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc
       )
       when is_name_char(c) do
    parse_attr_name(
      rest,
      more?,
      original,
      start,
      pos + utf8_size(c),
      state,
      cont,
      tag,
      attrs,
      loc
    )
  end

  defp parse_attr_name(rest, more?, original, start, pos, state, cont, tag, attrs, loc) do
    attr_name = binary_part(original, start, pos - start)
    parse_attr_eq(rest, more?, original, pos, state, cont, tag, attrs, loc, attr_name)
  end

  # ============================================================================
  # Attribute =
  # ============================================================================

  defp parse_attr_eq(<<>>, true, original, pos, state, cont, tag, attrs, loc, attr_name) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_attr_eq,
         __attr_name: attr_name,
         __tag: tag,
         __attrs: attrs,
         __loc: loc
     }, cont}
  end

  defp parse_attr_eq(<<>>, false, _original, pos, state, _cont, _tag, _attrs, _loc, _attr_name) do
    {:error, "Unexpected EOF expecting =", {state.line, state.line_start, pos}}
  end

  defp parse_attr_eq(
         <<c, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name
       )
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_attr_eq(rest, more?, original, pos + 1, state, cont, tag, attrs, loc, attr_name)
  end

  defp parse_attr_eq(
         <<"=", rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name
       ) do
    parse_attr_quote(rest, more?, original, pos + 1, state, cont, tag, attrs, loc, attr_name)
  end

  defp parse_attr_eq(_, _, _original, pos, state, _cont, _tag, _attrs, _loc, _attr_name) do
    {:error, "Expected =", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Attribute Quote
  # ============================================================================

  defp parse_attr_quote(<<>>, true, original, pos, state, cont, tag, attrs, loc, attr_name) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_attr_quote,
         __attr_name: attr_name,
         __tag: tag,
         __attrs: attrs,
         __loc: loc
     }, cont}
  end

  defp parse_attr_quote(<<>>, false, _original, pos, state, _cont, _tag, _attrs, _loc, _attr_name) do
    {:error, "Unexpected EOF expecting quote", {state.line, state.line_start, pos}}
  end

  defp parse_attr_quote(
         <<c, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name
       )
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_attr_quote(rest, more?, original, pos + 1, state, cont, tag, attrs, loc, attr_name)
  end

  defp parse_attr_quote(
         <<q, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name
       )
       when q == ?" or q == ?' do
    parse_attr_value(
      rest,
      more?,
      original,
      pos + 1,
      pos + 1,
      state,
      cont,
      tag,
      attrs,
      loc,
      attr_name,
      q,
      []
    )
  end

  defp parse_attr_quote(_, _, _original, pos, state, _cont, _tag, _attrs, _loc, _attr_name) do
    {:error, "Expected quote", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Attribute Value
  # ============================================================================

  defp parse_attr_value(
         <<>>,
         true,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       ) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_attr_value,
         __attr_start: start,
         __attr_name: attr_name,
         __quote: quote,
         __acc: acc,
         __tag: tag,
         __attrs: attrs,
         __loc: loc
     }, cont}
  end

  defp parse_attr_value(
         <<>>,
         false,
         _original,
         _start,
         pos,
         state,
         _cont,
         _tag,
         _attrs,
         _loc,
         _attr_name,
         _quote,
         _acc
       ) do
    {:error, "Unexpected EOF in attribute value", {state.line, state.line_start, pos}}
  end

  defp parse_attr_value(
         <<q, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         q,
         acc
       ) do
    # End of attribute value
    value_part = binary_part(original, start, pos - start)
    value = IO.iodata_to_binary(Enum.reverse([value_part | acc]))
    attrs = [{attr_name, value} | attrs]
    parse_attributes(rest, more?, original, pos + 1, state, cont, tag, attrs, loc)
  end

  defp parse_attr_value(
         <<"&", rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       ) do
    # Entity reference in attribute
    value_part = binary_part(original, start, pos - start)
    acc = [value_part | acc]

    parse_attr_entity(
      rest,
      more?,
      original,
      pos + 1,
      pos + 1,
      state,
      cont,
      tag,
      attrs,
      loc,
      attr_name,
      quote,
      acc
    )
  end

  defp parse_attr_value(
         <<?\n, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       ) do
    state = %{state | line: state.line + 1, line_start: pos + 1}

    parse_attr_value(
      rest,
      more?,
      original,
      start,
      pos + 1,
      state,
      cont,
      tag,
      attrs,
      loc,
      attr_name,
      quote,
      acc
    )
  end

  # WFC: No < in Attribute Values
  defp parse_attr_value(
         <<"<", _::binary>>,
         _more?,
         _original,
         _start,
         pos,
         state,
         _cont,
         _tag,
         _attrs,
         _loc,
         _attr_name,
         _quote,
         _acc
       ) do
    # Emit error via callback if available, then signal error to stop parsing
    if state.emit,
      do:
        state.emit.(
          {:error, "Character '<' not allowed in attribute value",
           {state.line, state.line_start, pos}}
        )

    {:error, "Character '<' not allowed in attribute value", {state.line, state.line_start, pos}}
  end

  defp parse_attr_value(
         <<_, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       ) do
    parse_attr_value(
      rest,
      more?,
      original,
      start,
      pos + 1,
      state,
      cont,
      tag,
      attrs,
      loc,
      attr_name,
      quote,
      acc
    )
  end

  # ============================================================================
  # Attribute Entity Reference
  # ============================================================================

  defp parse_attr_entity(
         <<>>,
         true,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       ) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_attr_entity,
         __entity_start: start,
         __attr_name: attr_name,
         __quote: quote,
         __acc: acc,
         __tag: tag,
         __attrs: attrs,
         __loc: loc
     }, cont}
  end

  defp parse_attr_entity(
         <<>>,
         false,
         _original,
         _start,
         pos,
         state,
         _cont,
         _tag,
         _attrs,
         _loc,
         _attr_name,
         _quote,
         _acc
       ) do
    {:error, "Unexpected EOF in entity", {state.line, state.line_start, pos}}
  end

  defp parse_attr_entity(
         <<";", rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       ) do
    entity_name = binary_part(original, start, pos - start)
    resolved = resolve_entity(entity_name)
    acc = [resolved | acc]

    parse_attr_value(
      rest,
      more?,
      original,
      pos + 1,
      pos + 1,
      state,
      cont,
      tag,
      attrs,
      loc,
      attr_name,
      quote,
      acc
    )
  end

  defp parse_attr_entity(
         <<c, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         tag,
         attrs,
         loc,
         attr_name,
         quote,
         acc
       )
       when is_name_char(c) or c == ?# do
    parse_attr_entity(
      rest,
      more?,
      original,
      start,
      pos + 1,
      state,
      cont,
      tag,
      attrs,
      loc,
      attr_name,
      quote,
      acc
    )
  end

  defp parse_attr_entity(
         _,
         _,
         _original,
         _start,
         pos,
         state,
         _cont,
         _tag,
         _attrs,
         _loc,
         _attr_name,
         _quote,
         _acc
       ) do
    {:error, "Invalid entity reference", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Self-closing tag
  # ============================================================================

  defp parse_self_close(<<>>, true, original, pos, state, cont, tag, attrs, loc) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_self_close, __tag: tag, __attrs: attrs, __loc: loc}, cont}
  end

  defp parse_self_close(<<>>, false, _original, pos, state, _cont, _tag, _attrs, _loc) do
    {:error, "Unexpected EOF expecting >", {state.line, state.line_start, pos}}
  end

  defp parse_self_close(<<">", rest::binary>>, more?, original, pos, state, cont, tag, attrs, loc) do
    state.emit.({:start_element, tag, Enum.reverse(attrs), loc})
    state.emit.({:end_element, tag, {state.line, state.line_start, pos}})
    {new_original, new_pos} = maybe_trim(more?, original, pos + 1)
    parse_content(rest, more?, new_original, new_pos, state, cont)
  end

  defp parse_self_close(_, _, _original, pos, state, _cont, _tag, _attrs, _loc) do
    {:error, "Expected > after /", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Close Tag
  # ============================================================================

  defp parse_close_tag(<<>>, true, original, loc_pos, name_start, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_close_tag, __tag_start: name_start, __loc_pos: loc_pos},
     cont}
  end

  defp parse_close_tag(<<>>, false, _original, _loc_pos, _name_start, pos, state, _cont) do
    {:error, "Unexpected EOF in close tag", {state.line, state.line_start, pos}}
  end

  defp parse_close_tag(
         <<c::utf8, rest::binary>>,
         more?,
         original,
         loc_pos,
         name_start,
         pos,
         state,
         cont
       )
       when is_name_char(c) do
    parse_close_tag(rest, more?, original, loc_pos, name_start, pos + utf8_size(c), state, cont)
  end

  defp parse_close_tag(rest, more?, original, loc_pos, name_start, pos, state, cont) do
    tag_name = binary_part(original, name_start, pos - name_start)
    parse_close_tag_end(rest, more?, original, pos, state, cont, tag_name, loc_pos)
  end

  defp parse_close_tag_end(<<>>, true, original, pos, state, cont, tag, tag_start) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_close_tag_end, __tag: tag, __tag_start: tag_start}, cont}
  end

  defp parse_close_tag_end(<<>>, false, _original, pos, state, _cont, _tag, _tag_start) do
    {:error, "Unexpected EOF in close tag", {state.line, state.line_start, pos}}
  end

  defp parse_close_tag_end(<<c, rest::binary>>, more?, original, pos, state, cont, tag, tag_start)
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_close_tag_end(rest, more?, original, pos + 1, state, cont, tag, tag_start)
  end

  defp parse_close_tag_end(
         <<">", rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         tag,
         tag_start
       ) do
    state.emit.({:end_element, tag, {state.line, state.line_start, tag_start}})
    {new_original, new_pos} = maybe_trim(more?, original, pos + 1)
    parse_content(rest, more?, new_original, new_pos, state, cont)
  end

  defp parse_close_tag_end(_, _, _original, pos, state, _cont, _tag, _tag_start) do
    {:error, "Expected > in close tag", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Element Content
  # ============================================================================

  defp parse_element_content(<<>>, true, original, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_element_content}, cont}
  end

  defp parse_element_content(<<>>, false, _original, _pos, state, _cont) do
    {:ok, state}
  end

  defp parse_element_content(<<"<", rest::binary>>, more?, original, pos, state, cont) do
    parse_tag_start(rest, more?, original, pos + 1, state, cont)
  end

  defp parse_element_content(<<c, rest::binary>>, more?, original, pos, state, cont)
       when is_whitespace(c) do
    # Start of possible text content
    parse_text(rest, more?, original, pos + 1, pos, state, cont)
  end

  defp parse_element_content(<<_::binary>> = rest, more?, original, pos, state, cont) do
    parse_text(rest, more?, original, pos, pos, state, cont)
  end

  # ============================================================================
  # Processing Instructions
  # ============================================================================

  defp parse_pi(<<>>, true, original, start, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_pi, __pi_start: start}, cont}
  end

  defp parse_pi(<<>>, false, _original, _start, pos, state, _cont) do
    {:error, "Unexpected EOF in PI", {state.line, state.line_start, pos}}
  end

  defp parse_pi(<<c::utf8, rest::binary>>, more?, original, start, pos, state, cont)
       when is_name_char(c) do
    parse_pi(rest, more?, original, start, pos + utf8_size(c), state, cont)
  end

  defp parse_pi(rest, more?, original, start, pos, state, cont) do
    target = binary_part(original, start, pos - start)

    if String.downcase(target) == "xml" do
      parse_prolog(rest, more?, original, pos, state, cont, [])
    else
      parse_pi_content(rest, more?, original, pos, pos, state, cont, target)
    end
  end

  defp parse_pi_content(<<>>, true, original, start, pos, state, cont, target) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_pi_content, __pi_target: target, __pi_start: start}, cont}
  end

  defp parse_pi_content(<<>>, false, _original, _start, pos, state, _cont, _target) do
    {:error, "Unexpected EOF in PI", {state.line, state.line_start, pos}}
  end

  defp parse_pi_content(<<"?>", rest::binary>>, more?, original, _start, pos, state, cont, target) do
    state.emit.({:processing_instruction, target, "", {state.line, state.line_start, pos}})
    parse_content(rest, more?, original, pos + 2, state, cont)
  end

  defp parse_pi_content(<<"?", rest::binary>>, more?, original, start, pos, state, cont, target) do
    # Could be end, need to check next char
    parse_pi_content_maybe_end(rest, more?, original, start, pos, state, cont, target)
  end

  defp parse_pi_content(<<?\n, rest::binary>>, more?, original, start, pos, state, cont, target) do
    state = %{state | line: state.line + 1, line_start: pos + 1}
    parse_pi_content(rest, more?, original, start, pos + 1, state, cont, target)
  end

  defp parse_pi_content(<<_, rest::binary>>, more?, original, start, pos, state, cont, target) do
    parse_pi_content(rest, more?, original, start, pos + 1, state, cont, target)
  end

  defp parse_pi_content_maybe_end(<<>>, true, original, start, pos, state, cont, target) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{state | __resume: :parse_pi_content_maybe_end, __pi_target: target, __pi_start: start},
     cont}
  end

  defp parse_pi_content_maybe_end(<<>>, false, _original, _start, pos, state, _cont, _target) do
    {:error, "Unexpected EOF in PI", {state.line, state.line_start, pos}}
  end

  defp parse_pi_content_maybe_end(
         <<">", rest::binary>>,
         more?,
         original,
         _start,
         pos,
         state,
         cont,
         target
       ) do
    state.emit.({:processing_instruction, target, "", {state.line, state.line_start, pos}})
    parse_content(rest, more?, original, pos + 2, state, cont)
  end

  defp parse_pi_content_maybe_end(rest, more?, original, start, pos, state, cont, target) do
    parse_pi_content(rest, more?, original, start, pos + 1, state, cont, target)
  end

  # ============================================================================
  # XML Prolog
  # ============================================================================

  defp parse_prolog(<<>>, true, original, pos, state, cont, attrs) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_prolog, __prolog_attrs: attrs}, cont}
  end

  defp parse_prolog(<<>>, false, _original, pos, state, _cont, _attrs) do
    {:error, "Unexpected EOF in prolog", {state.line, state.line_start, pos}}
  end

  defp parse_prolog(<<c, rest::binary>>, more?, original, pos, state, cont, attrs)
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_prolog(rest, more?, original, pos + 1, state, cont, attrs)
  end

  defp parse_prolog(<<"?>", rest::binary>>, more?, original, pos, state, cont, attrs) do
    state.emit.({:prolog, Enum.reverse(attrs), {state.line, state.line_start, pos}})
    parse_content(rest, more?, original, pos + 2, state, cont)
  end

  defp parse_prolog(<<"?", rest::binary>>, more?, original, pos, state, cont, attrs) do
    parse_prolog_maybe_end(rest, more?, original, pos, state, cont, attrs)
  end

  defp parse_prolog(<<c::utf8, rest::binary>>, more?, original, pos, state, cont, attrs)
       when is_name_start(c) do
    parse_prolog_attr_name(rest, more?, original, pos, pos + utf8_size(c), state, cont, attrs)
  end

  defp parse_prolog(_, _, _original, pos, state, _cont, _attrs) do
    {:error, "Invalid prolog", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_maybe_end(<<>>, true, original, pos, state, cont, attrs) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_prolog_after_question, __prolog_attrs: attrs}, cont}
  end

  defp parse_prolog_maybe_end(<<>>, false, _original, pos, state, _cont, _attrs) do
    {:error, "Unexpected EOF in prolog", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_maybe_end(<<">", rest::binary>>, more?, original, pos, state, cont, attrs) do
    state.emit.({:prolog, Enum.reverse(attrs), {state.line, state.line_start, pos}})
    parse_content(rest, more?, original, pos + 2, state, cont)
  end

  defp parse_prolog_maybe_end(_, _, _original, pos, state, _cont, _attrs) do
    {:error, "Expected ?> in prolog", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_name(<<>>, true, original, start, pos, state, cont, attrs) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_prolog_attr_name,
         __prolog_attr_start: start,
         __prolog_attrs: attrs
     }, cont}
  end

  defp parse_prolog_attr_name(<<>>, false, _original, _start, pos, state, _cont, _attrs) do
    {:error, "Unexpected EOF in prolog attr", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_name(
         <<c::utf8, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         attrs
       )
       when is_name_char(c) do
    parse_prolog_attr_name(rest, more?, original, start, pos + utf8_size(c), state, cont, attrs)
  end

  defp parse_prolog_attr_name(rest, more?, original, start, pos, state, cont, attrs) do
    attr_name = binary_part(original, start, pos - start)
    parse_prolog_attr_eq(rest, more?, original, pos, state, cont, attrs, attr_name)
  end

  defp parse_prolog_attr_eq(<<>>, true, original, pos, state, cont, attrs, attr_name) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_prolog_attr_eq,
         __prolog_attr_name: attr_name,
         __prolog_attrs: attrs
     }, cont}
  end

  defp parse_prolog_attr_eq(<<>>, false, _original, pos, state, _cont, _attrs, _attr_name) do
    {:error, "Unexpected EOF expecting =", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_eq(
         <<c, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         attrs,
         attr_name
       )
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_prolog_attr_eq(rest, more?, original, pos + 1, state, cont, attrs, attr_name)
  end

  defp parse_prolog_attr_eq(
         <<"=", rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         attrs,
         attr_name
       ) do
    parse_prolog_attr_quote(rest, more?, original, pos + 1, state, cont, attrs, attr_name)
  end

  defp parse_prolog_attr_eq(_, _, _original, pos, state, _cont, _attrs, _attr_name) do
    {:error, "Expected =", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_quote(<<>>, true, original, pos, state, cont, attrs, attr_name) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_prolog_attr_quote,
         __prolog_attr_name: attr_name,
         __prolog_attrs: attrs
     }, cont}
  end

  defp parse_prolog_attr_quote(<<>>, false, _original, pos, state, _cont, _attrs, _attr_name) do
    {:error, "Unexpected EOF expecting quote", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_quote(
         <<c, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         attrs,
         attr_name
       )
       when is_whitespace(c) do
    state =
      if c == ?\n,
        do: %{state | line: state.line + 1, line_start: pos + 1},
        else: state

    parse_prolog_attr_quote(rest, more?, original, pos + 1, state, cont, attrs, attr_name)
  end

  defp parse_prolog_attr_quote(
         <<q, rest::binary>>,
         more?,
         original,
         pos,
         state,
         cont,
         attrs,
         attr_name
       )
       when q == ?" or q == ?' do
    parse_prolog_attr_value(
      rest,
      more?,
      original,
      pos + 1,
      pos + 1,
      state,
      cont,
      attrs,
      attr_name,
      q
    )
  end

  defp parse_prolog_attr_quote(_, _, _original, pos, state, _cont, _attrs, _attr_name) do
    {:error, "Expected quote", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_value(
         <<>>,
         true,
         original,
         start,
         pos,
         state,
         cont,
         attrs,
         attr_name,
         quote
       ) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_prolog_attr_value,
         __prolog_attr_start: start,
         __prolog_attr_name: attr_name,
         __prolog_quote: quote,
         __prolog_attrs: attrs
     }, cont}
  end

  defp parse_prolog_attr_value(
         <<>>,
         false,
         _original,
         _start,
         pos,
         state,
         _cont,
         _attrs,
         _attr_name,
         _quote
       ) do
    {:error, "Unexpected EOF in prolog attr value", {state.line, state.line_start, pos}}
  end

  defp parse_prolog_attr_value(
         <<q, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         attrs,
         attr_name,
         q
       ) do
    value = binary_part(original, start, pos - start)
    attrs = [{attr_name, value} | attrs]
    parse_prolog(rest, more?, original, pos + 1, state, cont, attrs)
  end

  defp parse_prolog_attr_value(
         <<_, rest::binary>>,
         more?,
         original,
         start,
         pos,
         state,
         cont,
         attrs,
         attr_name,
         quote
       ) do
    parse_prolog_attr_value(
      rest,
      more?,
      original,
      start,
      pos + 1,
      state,
      cont,
      attrs,
      attr_name,
      quote
    )
  end

  # ============================================================================
  # Bang (comment, CDATA, DOCTYPE)
  # ============================================================================

  defp parse_bang(<<>>, true, original, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_bang}, cont}
  end

  defp parse_bang(<<>>, false, _original, pos, state, _cont) do
    {:error, "Unexpected EOF after <!", {state.line, state.line_start, pos}}
  end

  defp parse_bang(<<"--", rest::binary>>, more?, original, pos, state, cont) do
    parse_comment(rest, more?, original, pos + 2, pos + 2, state, cont)
  end

  defp parse_bang(<<"-", _::binary>> = buffer, true, original, pos, state, cont)
       when byte_size(buffer) < 2 do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_bang}, cont}
  end

  defp parse_bang(<<"[CDATA[", rest::binary>>, more?, original, pos, state, cont) do
    parse_cdata(rest, more?, original, pos + 7, pos + 7, state, cont)
  end

  defp parse_bang(<<"[", _::binary>> = buffer, true, original, pos, state, cont)
       when byte_size(buffer) < 7 do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_bang}, cont}
  end

  defp parse_bang(<<"DOCTYPE", rest::binary>>, more?, original, pos, state, cont) do
    # pos is after "<!" so loc is at pos-1 (the "<"), start is at pos (the "D" of DOCTYPE)
    loc = {state.line, state.line_start, pos - 1}
    parse_doctype(rest, more?, original, pos + 7, loc, pos, 1, state, cont)
  end

  defp parse_bang(<<"D", _::binary>> = buffer, true, original, pos, state, cont)
       when byte_size(buffer) < 7 do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_bang}, cont}
  end

  defp parse_bang(_, _, _original, pos, state, _cont) do
    {:error, "Invalid <! construct", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Comment
  # ============================================================================

  defp parse_comment(<<>>, true, original, start, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_comment, __comment_start: start}, cont}
  end

  defp parse_comment(<<>>, false, _original, _start, pos, state, _cont) do
    {:error, "Unexpected EOF in comment", {state.line, state.line_start, pos}}
  end

  defp parse_comment(<<"-->", rest::binary>>, more?, original, start, pos, state, cont) do
    comment = binary_part(original, start, pos - start)
    state.emit.({:comment, comment, {state.line, state.line_start, start}})
    parse_content(rest, more?, original, pos + 3, state, cont)
  end

  defp parse_comment(<<"--", _::binary>> = buffer, true, original, start, pos, state, cont)
       when byte_size(buffer) < 3 do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_comment_end, __comment_start: start}, cont}
  end

  defp parse_comment(<<?\n, rest::binary>>, more?, original, start, pos, state, cont) do
    state = %{state | line: state.line + 1, line_start: pos + 1}
    parse_comment(rest, more?, original, start, pos + 1, state, cont)
  end

  defp parse_comment(<<_, rest::binary>>, more?, original, start, pos, state, cont) do
    parse_comment(rest, more?, original, start, pos + 1, state, cont)
  end

  # ============================================================================
  # CDATA
  # ============================================================================

  defp parse_cdata(<<>>, true, original, start, pos, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_cdata, __cdata_start: start}, cont}
  end

  defp parse_cdata(<<>>, false, _original, _start, pos, state, _cont) do
    {:error, "Unexpected EOF in CDATA", {state.line, state.line_start, pos}}
  end

  defp parse_cdata(<<"]]>", rest::binary>>, more?, original, start, pos, state, cont) do
    cdata = binary_part(original, start, pos - start)
    state.emit.({:cdata, cdata, {state.line, state.line_start, start}})
    {new_original, new_pos} = maybe_trim(more?, original, pos + 3)
    parse_element_content(rest, more?, new_original, new_pos, state, cont)
  end

  defp parse_cdata(<<"]]", _::binary>> = buffer, true, original, start, pos, state, cont)
       when byte_size(buffer) < 3 do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end, %{state | __resume: :parse_cdata_end, __cdata_start: start}, cont}
  end

  defp parse_cdata(<<?\n, rest::binary>>, more?, original, start, pos, state, cont) do
    state = %{state | line: state.line + 1, line_start: pos + 1}
    parse_cdata(rest, more?, original, start, pos + 1, state, cont)
  end

  defp parse_cdata(<<_, rest::binary>>, more?, original, start, pos, state, cont) do
    parse_cdata(rest, more?, original, start, pos + 1, state, cont)
  end

  # ============================================================================
  # DOCTYPE
  # ============================================================================

  defp parse_doctype(<<>>, true, original, pos, loc, start, depth, state, cont) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{
       state
       | __resume: :parse_doctype,
         __doctype_depth: depth,
         __doctype_start: start,
         __doctype_loc: loc
     }, cont}
  end

  defp parse_doctype(<<>>, false, _original, pos, _loc, _start, _depth, state, _cont) do
    {:error, "Unexpected EOF in DOCTYPE", {state.line, state.line_start, pos}}
  end

  defp parse_doctype(<<">", rest::binary>>, more?, original, pos, loc, start, 1, state, cont) do
    content = binary_part(original, start, pos - start)
    state.emit.({:dtd, content, loc})
    parse_content(rest, more?, original, pos + 1, state, cont)
  end

  defp parse_doctype(<<">", rest::binary>>, more?, original, pos, loc, start, depth, state, cont) do
    parse_doctype(rest, more?, original, pos + 1, loc, start, depth - 1, state, cont)
  end

  defp parse_doctype(<<"<", rest::binary>>, more?, original, pos, loc, start, depth, state, cont) do
    parse_doctype(rest, more?, original, pos + 1, loc, start, depth + 1, state, cont)
  end

  defp parse_doctype(<<?\n, rest::binary>>, more?, original, pos, loc, start, depth, state, cont) do
    state = %{state | line: state.line + 1, line_start: pos + 1}
    parse_doctype(rest, more?, original, pos + 1, loc, start, depth, state, cont)
  end

  defp parse_doctype(<<_, rest::binary>>, more?, original, pos, loc, start, depth, state, cont) do
    parse_doctype(rest, more?, original, pos + 1, loc, start, depth, state, cont)
  end

  # ============================================================================
  # Entity Reference (in text)
  # ============================================================================

  defp parse_entity_ref(<<>>, true, original, start, pos, state, cont, context) do
    {:halted,
     fn chunk, more?, st ->
       new_original = original <> chunk
       {chunk, more?, new_original, pos, st}
     end,
     %{state | __resume: :parse_entity_ref, __entity_start: start, __entity_context: context},
     cont}
  end

  defp parse_entity_ref(<<>>, false, _original, _start, pos, state, _cont, _context) do
    {:error, "Unexpected EOF in entity", {state.line, state.line_start, pos}}
  end

  defp parse_entity_ref(<<";", rest::binary>>, more?, original, start, pos, state, cont, :text) do
    entity_name = binary_part(original, start, pos - start)
    resolved = resolve_entity(entity_name)
    loc = {state.line, state.line_start, start - 1}
    state.emit.({:characters, resolved, loc})
    parse_text(rest, more?, original, pos + 1, pos + 1, state, cont)
  end

  defp parse_entity_ref(<<c, rest::binary>>, more?, original, start, pos, state, cont, context)
       when is_name_char(c) or c == ?# do
    parse_entity_ref(rest, more?, original, start, pos + 1, state, cont, context)
  end

  defp parse_entity_ref(_, _, _original, _start, pos, state, _cont, _context) do
    {:error, "Invalid entity reference", {state.line, state.line_start, pos}}
  end

  # ============================================================================
  # Entity Resolution
  # ============================================================================

  defp resolve_entity("lt"), do: "<"
  defp resolve_entity("gt"), do: ">"
  defp resolve_entity("amp"), do: "&"
  defp resolve_entity("apos"), do: "'"
  defp resolve_entity("quot"), do: "\""

  defp resolve_entity(<<"#x", hex::binary>>) do
    <<String.to_integer(hex, 16)::utf8>>
  end

  defp resolve_entity(<<"#", dec::binary>>) do
    <<String.to_integer(dec, 10)::utf8>>
  end

  defp resolve_entity(name), do: "&#{name};"
end
