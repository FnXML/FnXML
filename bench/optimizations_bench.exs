# Benchmark individual optimizations for recursive_cps
# Run with: mix run bench/optimizations_bench.exs
#
# Tests:
#   - baseline: Current RecursiveCPS implementation
#   - bulk_ws: Skip multiple whitespace chars at once using :binary.match
#   - fewer_params: Consolidate parameters into tuples
#   - direct_calls: Replace atom dispatch with direct function refs

defmodule NullHandler do
  @behaviour Saxy.Handler
  def handle_event(_, _, state), do: {:ok, state}
end

# ============================================================
# Optimization #2: Bulk Whitespace Skip
# ============================================================
defmodule OptBulkWS do
  @moduledoc "Test: Skip multiple whitespace at once"

  defguardp is_name_start(c) when
    c in ?a..?z or c in ?A..?Z or c == ?_ or c == ?: or
    c in 0x00C0..0x00D6 or c in 0x00D8..0x00F6 or
    c in 0x00F8..0x02FF or c in 0x0370..0x037D or
    c in 0x037F..0x1FFF or c in 0x200C..0x200D

  defguardp is_name_char(c) when
    is_name_start(c) or c == ?- or c == ?. or c in ?0..?9 or
    c == 0x00B7 or c in 0x0300..0x036F or c in 0x203F..0x2040

  @ws_chars [?\s, ?\t, ?\r, ?\n]

  def parse(xml, emit) when is_binary(xml) and is_function(emit, 1) do
    do_parse_all(xml, xml, 0, 1, 0, emit)
  end

  defp do_parse_all(<<>>, _xml, pos, line, ls, _emit), do: {:ok, pos, line, ls}

  defp do_parse_all(rest, xml, pos, line, ls, emit) do
    {pos, line, ls} = do_parse_one(rest, xml, pos, line, ls, emit)
    new_rest = binary_part(xml, pos, byte_size(xml) - pos)
    do_parse_all(new_rest, xml, pos, line, ls, emit)
  end

  defp do_parse_one(<<>>, _xml, pos, line, ls, _emit), do: {pos, line, ls}

  defp do_parse_one(<<"<?xml", rest::binary>>, xml, pos, line, ls, emit) do
    parse_prolog(rest, xml, pos + 5, line, ls, {line, ls, pos + 1}, emit)
  end

  defp do_parse_one(<<"<", _::binary>> = rest, xml, pos, line, ls, emit) do
    parse_element(rest, xml, pos, line, ls, emit)
  end

  # OPTIMIZATION: Bulk whitespace skip
  defp do_parse_one(<<c, _::binary>> = rest, xml, pos, line, ls, emit) when c in @ws_chars do
    {new_pos, new_line, new_ls} = skip_ws_bulk(rest, xml, pos, line, ls)
    new_rest = binary_part(xml, new_pos, byte_size(xml) - new_pos)
    do_parse_one(new_rest, xml, new_pos, new_line, new_ls, emit)
  end

  defp do_parse_one(rest, xml, pos, line, ls, emit) do
    parse_text(rest, xml, pos, line, ls, {line, ls, pos}, pos, emit)
  end

  # Bulk whitespace skip - scan forward through whitespace
  defp skip_ws_bulk(rest, _xml, pos, line, ls) do
    skip_ws_loop(rest, pos, line, ls)
  end

  defp skip_ws_loop(<<?\n, rest::binary>>, pos, line, _ls) do
    skip_ws_loop(rest, pos + 1, line + 1, pos + 1)
  end

  defp skip_ws_loop(<<c, rest::binary>>, pos, line, ls) when c in [?\s, ?\t, ?\r] do
    skip_ws_loop(rest, pos + 1, line, ls)
  end

  defp skip_ws_loop(_, pos, line, ls), do: {pos, line, ls}

  # Simplified element parsing (just enough for benchmark)
  defp parse_element(<<"<!--", rest::binary>>, xml, pos, line, ls, emit) do
    parse_comment(rest, xml, pos + 4, line, ls, {line, ls, pos + 1}, pos + 4, emit)
  end

  defp parse_element(<<"</", rest::binary>>, xml, pos, line, ls, emit) do
    parse_close_tag(rest, xml, pos + 2, line, ls, {line, ls, pos + 1}, emit)
  end

  defp parse_element(<<"<", c, _::binary>> = rest, xml, pos, line, ls, emit) when is_name_start(c) do
    <<"<", rest2::binary>> = rest
    parse_open_tag(rest2, xml, pos + 1, line, ls, {line, ls, pos + 1}, emit)
  end

  defp parse_element(_, _xml, pos, line, ls, emit) do
    emit.({:error, "Invalid element", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_prolog(rest, xml, pos, line, ls, loc, emit) do
    {pos, line, ls} = skip_ws_bulk(rest, xml, pos, line, ls)
    new_rest = binary_part(xml, pos, byte_size(xml) - pos)
    parse_prolog_content(new_rest, xml, pos, line, ls, loc, [], emit)
  end

  defp parse_prolog_content(<<"?>", _::binary>>, _xml, pos, line, ls, loc, attrs, emit) do
    emit.({:prolog, "xml", Enum.reverse(attrs), loc})
    {pos + 2, line, ls}
  end

  defp parse_prolog_content(<<c, _::binary>> = rest, xml, pos, line, ls, loc, attrs, emit) when is_name_start(c) do
    {name, rest2, pos2} = scan_name(rest, pos)
    {pos2, line, ls} = skip_ws_bulk(rest2, xml, pos2, line, ls)
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    <<"=", rest4::binary>> = rest3
    {pos3, line, ls} = skip_ws_bulk(rest4, xml, pos2 + 1, line, ls)
    rest5 = binary_part(xml, pos3, byte_size(xml) - pos3)
    <<q, rest6::binary>> = rest5
    {value, rest7, pos4} = scan_until_char(rest6, xml, pos3 + 1, q)
    {pos4, line, ls} = skip_ws_bulk(rest7, xml, pos4, line, ls)
    rest8 = binary_part(xml, pos4, byte_size(xml) - pos4)
    parse_prolog_content(rest8, xml, pos4, line, ls, loc, [{name, value} | attrs], emit)
  end

  defp parse_prolog_content(_, _xml, pos, line, ls, _loc, _attrs, emit) do
    emit.({:error, "Expected '?>'", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_open_tag(rest, xml, pos, line, ls, loc, emit) do
    {name, rest2, pos2} = scan_name(rest, pos)
    {pos2, line, ls} = skip_ws_bulk(rest2, xml, pos2, line, ls)
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    parse_open_tag_attrs(rest3, xml, pos2, line, ls, name, [], loc, emit)
  end

  defp parse_open_tag_attrs(<<"/>", _::binary>>, _xml, pos, line, ls, name, attrs, loc, emit) do
    emit.({:open, name, Enum.reverse(attrs), loc})
    emit.({:close, name})
    {pos + 2, line, ls}
  end

  defp parse_open_tag_attrs(<<">", _::binary>>, _xml, pos, line, ls, name, attrs, loc, emit) do
    emit.({:open, name, Enum.reverse(attrs), loc})
    {pos + 1, line, ls}
  end

  defp parse_open_tag_attrs(<<c, _::binary>> = rest, xml, pos, line, ls, name, attrs, loc, emit) when is_name_start(c) do
    {attr_name, rest2, pos2} = scan_name(rest, pos)
    {pos2, line, ls} = skip_ws_bulk(rest2, xml, pos2, line, ls)
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    <<"=", rest4::binary>> = rest3
    {pos3, line, ls} = skip_ws_bulk(rest4, xml, pos2 + 1, line, ls)
    rest5 = binary_part(xml, pos3, byte_size(xml) - pos3)
    <<q, rest6::binary>> = rest5
    {value, rest7, pos4} = scan_until_char(rest6, xml, pos3 + 1, q)
    {pos4, line, ls} = skip_ws_bulk(rest7, xml, pos4, line, ls)
    rest8 = binary_part(xml, pos4, byte_size(xml) - pos4)
    parse_open_tag_attrs(rest8, xml, pos4, line, ls, name, [{attr_name, value} | attrs], loc, emit)
  end

  defp parse_open_tag_attrs(_, _xml, pos, line, ls, _name, _attrs, _loc, emit) do
    emit.({:error, "Expected '>' or attribute", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_close_tag(rest, xml, pos, line, ls, loc, emit) do
    {name, rest2, pos2} = scan_name(rest, pos)
    {pos2, line, ls} = skip_ws_bulk(rest2, xml, pos2, line, ls)
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    <<">", _::binary>> = rest3
    emit.({:close, name, loc})
    {pos2 + 1, line, ls}
  end

  defp parse_comment(<<"-->", _::binary>>, xml, pos, line, ls, loc, start, emit) do
    content = binary_part(xml, start, pos - start)
    emit.({:comment, content, loc})
    {pos + 3, line, ls}
  end

  defp parse_comment(<<?\n, rest::binary>>, xml, pos, line, _ls, loc, start, emit) do
    parse_comment(rest, xml, pos + 1, line + 1, pos + 1, loc, start, emit)
  end

  defp parse_comment(<<_, rest::binary>>, xml, pos, line, ls, loc, start, emit) do
    parse_comment(rest, xml, pos + 1, line, ls, loc, start, emit)
  end

  defp parse_comment(<<>>, _xml, pos, line, ls, _loc, _start, emit) do
    emit.({:error, "Unterminated comment", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_text(<<"<", _::binary>>, xml, pos, line, ls, loc, start, emit) do
    content = binary_part(xml, start, pos - start)
    emit.({:text, content, loc})
    {pos, line, ls}
  end

  defp parse_text(<<?\n, rest::binary>>, xml, pos, line, _ls, loc, start, emit) do
    parse_text(rest, xml, pos + 1, line + 1, pos + 1, loc, start, emit)
  end

  defp parse_text(<<_, rest::binary>>, xml, pos, line, ls, loc, start, emit) do
    parse_text(rest, xml, pos + 1, line, ls, loc, start, emit)
  end

  defp parse_text(<<>>, xml, pos, line, ls, loc, start, emit) do
    content = binary_part(xml, start, pos - start)
    emit.({:text, content, loc})
    {pos, line, ls}
  end

  defp scan_name(<<c, rest::binary>>, pos) when is_name_char(c) do
    scan_name_loop(rest, pos + 1, pos)
  end

  defp scan_name_loop(<<c, rest::binary>>, pos, start) when is_name_char(c) do
    scan_name_loop(rest, pos + 1, start)
  end

  defp scan_name_loop(rest, pos, start) do
    # We need the original xml to extract the name, but for simplicity
    # we'll track the length and extract later
    {pos - start, rest, pos}
  end

  # Override to return actual name
  defp scan_name(rest, xml, pos) do
    start = pos
    {len, rest2, pos2} = scan_name(rest, pos)
    name = binary_part(xml, start, len)
    {name, rest2, pos2}
  end

  # Shadowing simpler version
  defp scan_name(rest, pos) do
    scan_name_inner(rest, pos, pos)
  end

  defp scan_name_inner(<<c, rest::binary>>, pos, start) when is_name_char(c) do
    scan_name_inner(rest, pos + 1, start)
  end

  defp scan_name_inner(rest, pos, _start) do
    {rest, pos}
  end

  # Fix scan_name to work with binary extraction
  defp scan_name(<<c, _::binary>> = rest, xml, pos) when is_name_char(c) do
    start = pos
    {rest2, pos2} = scan_name_inner(rest, pos, start)
    name = binary_part(xml, start, pos2 - start)
    {name, rest2, pos2}
  end

  defp scan_until_char(rest, xml, pos, char) do
    scan_until_char_loop(rest, xml, pos, char, pos)
  end

  defp scan_until_char_loop(<<c, rest::binary>>, xml, pos, c, start) do
    value = binary_part(xml, start, pos - start)
    {value, rest, pos + 1}
  end

  defp scan_until_char_loop(<<_, rest::binary>>, xml, pos, char, start) do
    scan_until_char_loop(rest, xml, pos + 1, char, start)
  end
end

# ============================================================
# Optimization #5: Fewer Parameters (consolidate into tuples)
# ============================================================
defmodule OptFewerParams do
  @moduledoc "Test: Consolidate parameters into context tuples"

  defguardp is_name_start(c) when
    c in ?a..?z or c in ?A..?Z or c == ?_ or c == ?: or
    c in 0x00C0..0x00D6 or c in 0x00D8..0x00F6 or
    c in 0x00F8..0x02FF or c in 0x0370..0x037D or
    c in 0x037F..0x1FFF or c in 0x200C..0x200D

  defguardp is_name_char(c) when
    is_name_start(c) or c == ?- or c == ?. or c in ?0..?9 or
    c == 0x00B7 or c in 0x0300..0x036F or c in 0x203F..0x2040

  # Context tuple: {xml, emit}
  # Position tuple: {pos, line, ls}

  def parse(xml, emit) when is_binary(xml) and is_function(emit, 1) do
    ctx = {xml, emit}
    do_parse_all(xml, ctx, {0, 1, 0})
  end

  defp do_parse_all(<<>>, _ctx, pos_info), do: {:ok, pos_info}

  defp do_parse_all(rest, ctx, pos_info) do
    {xml, _emit} = ctx
    {pos, _line, _ls} = pos_info
    pos_info = do_parse_one(rest, ctx, pos_info)
    {new_pos, _, _} = pos_info
    new_rest = binary_part(xml, new_pos, byte_size(xml) - new_pos)
    do_parse_all(new_rest, ctx, pos_info)
  end

  defp do_parse_one(<<>>, _ctx, pos_info), do: pos_info

  defp do_parse_one(<<"<?xml", rest::binary>>, ctx, {pos, line, ls}) do
    parse_prolog(rest, ctx, {pos + 5, line, ls}, {line, ls, pos + 1})
  end

  defp do_parse_one(<<"<", _::binary>> = rest, ctx, pos_info) do
    parse_element(rest, ctx, pos_info)
  end

  defp do_parse_one(<<c, rest::binary>>, ctx, {pos, line, ls}) when c in [?\s, ?\t, ?\r] do
    do_parse_one(rest, ctx, {pos + 1, line, ls})
  end

  defp do_parse_one(<<?\n, rest::binary>>, ctx, {pos, line, _ls}) do
    do_parse_one(rest, ctx, {pos + 1, line + 1, pos + 1})
  end

  defp do_parse_one(rest, ctx, {pos, line, ls}) do
    parse_text(rest, ctx, {pos, line, ls}, {line, ls, pos}, pos)
  end

  defp parse_element(<<"<!--", rest::binary>>, ctx, {pos, line, ls}) do
    parse_comment(rest, ctx, {pos + 4, line, ls}, {line, ls, pos + 1}, pos + 4)
  end

  defp parse_element(<<"</", rest::binary>>, ctx, {pos, line, ls}) do
    parse_close_tag(rest, ctx, {pos + 2, line, ls}, {line, ls, pos + 1})
  end

  defp parse_element(<<"<", c, _::binary>> = rest, ctx, {pos, line, ls}) when is_name_start(c) do
    <<"<", rest2::binary>> = rest
    parse_open_tag(rest2, ctx, {pos + 1, line, ls}, {line, ls, pos + 1})
  end

  defp parse_element(_, ctx, {pos, line, ls}) do
    {_xml, emit} = ctx
    emit.({:error, "Invalid element", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_prolog(rest, ctx, pos_info, loc) do
    {xml, emit} = ctx
    {pos, line, ls} = skip_ws(rest, pos_info)
    new_rest = binary_part(xml, pos, byte_size(xml) - pos)
    parse_prolog_content(new_rest, ctx, {pos, line, ls}, loc, [])
  end

  defp parse_prolog_content(<<"?>", _::binary>>, ctx, {pos, line, ls}, loc, attrs) do
    {_xml, emit} = ctx
    emit.({:prolog, "xml", Enum.reverse(attrs), loc})
    {pos + 2, line, ls}
  end

  defp parse_prolog_content(<<c, rest::binary>>, ctx, {pos, line, ls}, loc, attrs) when c in [?\s, ?\t, ?\r] do
    parse_prolog_content(rest, ctx, {pos + 1, line, ls}, loc, attrs)
  end

  defp parse_prolog_content(<<?\n, rest::binary>>, ctx, {pos, line, _ls}, loc, attrs) do
    parse_prolog_content(rest, ctx, {pos + 1, line + 1, pos + 1}, loc, attrs)
  end

  defp parse_prolog_content(<<c, _::binary>> = rest, ctx, pos_info, loc, attrs) when is_name_start(c) do
    {xml, _emit} = ctx
    {name, rest2, pos2} = scan_name(rest, xml, pos_info)
    {pos2, line, ls} = skip_ws(rest2, {pos2, elem(pos_info, 1), elem(pos_info, 2)})
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    <<"=", rest4::binary>> = rest3
    {pos3, line, ls} = skip_ws(rest4, {pos2 + 1, line, ls})
    rest5 = binary_part(xml, pos3, byte_size(xml) - pos3)
    <<q, rest6::binary>> = rest5
    {value, rest7, pos4} = scan_quoted(rest6, xml, pos3 + 1, q)
    {pos4, line, ls} = skip_ws(rest7, {pos4, line, ls})
    rest8 = binary_part(xml, pos4, byte_size(xml) - pos4)
    parse_prolog_content(rest8, ctx, {pos4, line, ls}, loc, [{name, value} | attrs])
  end

  defp parse_prolog_content(_, ctx, {pos, line, ls}, _loc, _attrs) do
    {_xml, emit} = ctx
    emit.({:error, "Expected '?>'", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_open_tag(rest, ctx, pos_info, loc) do
    {xml, _emit} = ctx
    {name, rest2, pos2} = scan_name(rest, xml, pos_info)
    {pos2, line, ls} = skip_ws(rest2, {pos2, elem(pos_info, 1), elem(pos_info, 2)})
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    parse_open_tag_attrs(rest3, ctx, {pos2, line, ls}, name, [], loc)
  end

  defp parse_open_tag_attrs(<<"/>", _::binary>>, ctx, {pos, line, ls}, name, attrs, loc) do
    {_xml, emit} = ctx
    emit.({:open, name, Enum.reverse(attrs), loc})
    emit.({:close, name})
    {pos + 2, line, ls}
  end

  defp parse_open_tag_attrs(<<">", _::binary>>, ctx, {pos, line, ls}, name, attrs, loc) do
    {_xml, emit} = ctx
    emit.({:open, name, Enum.reverse(attrs), loc})
    {pos + 1, line, ls}
  end

  defp parse_open_tag_attrs(<<c, rest::binary>>, ctx, {pos, line, ls}, name, attrs, loc) when c in [?\s, ?\t, ?\r] do
    parse_open_tag_attrs(rest, ctx, {pos + 1, line, ls}, name, attrs, loc)
  end

  defp parse_open_tag_attrs(<<?\n, rest::binary>>, ctx, {pos, line, _ls}, name, attrs, loc) do
    parse_open_tag_attrs(rest, ctx, {pos + 1, line + 1, pos + 1}, name, attrs, loc)
  end

  defp parse_open_tag_attrs(<<c, _::binary>> = rest, ctx, pos_info, name, attrs, loc) when is_name_start(c) do
    {xml, _emit} = ctx
    {attr_name, rest2, pos2} = scan_name(rest, xml, pos_info)
    {pos2, line, ls} = skip_ws(rest2, {pos2, elem(pos_info, 1), elem(pos_info, 2)})
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    <<"=", rest4::binary>> = rest3
    {pos3, line, ls} = skip_ws(rest4, {pos2 + 1, line, ls})
    rest5 = binary_part(xml, pos3, byte_size(xml) - pos3)
    <<q, rest6::binary>> = rest5
    {value, rest7, pos4} = scan_quoted(rest6, xml, pos3 + 1, q)
    {pos4, line, ls} = skip_ws(rest7, {pos4, line, ls})
    rest8 = binary_part(xml, pos4, byte_size(xml) - pos4)
    parse_open_tag_attrs(rest8, ctx, {pos4, line, ls}, name, [{attr_name, value} | attrs], loc)
  end

  defp parse_open_tag_attrs(_, ctx, {pos, line, ls}, _name, _attrs, _loc) do
    {_xml, emit} = ctx
    emit.({:error, "Expected '>' or attribute", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_close_tag(rest, ctx, pos_info, loc) do
    {xml, emit} = ctx
    {name, rest2, pos2} = scan_name(rest, xml, pos_info)
    {pos2, line, ls} = skip_ws(rest2, {pos2, elem(pos_info, 1), elem(pos_info, 2)})
    rest3 = binary_part(xml, pos2, byte_size(xml) - pos2)
    <<">", _::binary>> = rest3
    emit.({:close, name, loc})
    {pos2 + 1, line, ls}
  end

  defp parse_comment(<<"-->", _::binary>>, ctx, {pos, line, ls}, loc, start) do
    {xml, emit} = ctx
    content = binary_part(xml, start, pos - start)
    emit.({:comment, content, loc})
    {pos + 3, line, ls}
  end

  defp parse_comment(<<?\n, rest::binary>>, ctx, {pos, line, _ls}, loc, start) do
    parse_comment(rest, ctx, {pos + 1, line + 1, pos + 1}, loc, start)
  end

  defp parse_comment(<<_, rest::binary>>, ctx, {pos, line, ls}, loc, start) do
    parse_comment(rest, ctx, {pos + 1, line, ls}, loc, start)
  end

  defp parse_comment(<<>>, ctx, {pos, line, ls}, _loc, _start) do
    {_xml, emit} = ctx
    emit.({:error, "Unterminated comment", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_text(<<"<", _::binary>>, ctx, {pos, line, ls}, loc, start) do
    {xml, emit} = ctx
    content = binary_part(xml, start, pos - start)
    emit.({:text, content, loc})
    {pos, line, ls}
  end

  defp parse_text(<<?\n, rest::binary>>, ctx, {pos, line, _ls}, loc, start) do
    parse_text(rest, ctx, {pos + 1, line + 1, pos + 1}, loc, start)
  end

  defp parse_text(<<_, rest::binary>>, ctx, {pos, line, ls}, loc, start) do
    parse_text(rest, ctx, {pos + 1, line, ls}, loc, start)
  end

  defp parse_text(<<>>, ctx, {pos, line, ls}, loc, start) do
    {xml, emit} = ctx
    content = binary_part(xml, start, pos - start)
    emit.({:text, content, loc})
    {pos, line, ls}
  end

  defp skip_ws(<<c, rest::binary>>, {pos, line, ls}) when c in [?\s, ?\t, ?\r] do
    skip_ws(rest, {pos + 1, line, ls})
  end

  defp skip_ws(<<?\n, rest::binary>>, {pos, line, _ls}) do
    skip_ws(rest, {pos + 1, line + 1, pos + 1})
  end

  defp skip_ws(_, pos_info), do: pos_info

  defp scan_name(<<c, _::binary>> = rest, xml, {pos, _, _}) when is_name_char(c) do
    start = pos
    {rest2, pos2} = scan_name_loop(rest, pos)
    name = binary_part(xml, start, pos2 - start)
    {name, rest2, pos2}
  end

  defp scan_name_loop(<<c, rest::binary>>, pos) when is_name_char(c) do
    scan_name_loop(rest, pos + 1)
  end

  defp scan_name_loop(rest, pos), do: {rest, pos}

  defp scan_quoted(rest, xml, pos, q) do
    scan_quoted_loop(rest, xml, pos, q, pos)
  end

  defp scan_quoted_loop(<<c, rest::binary>>, xml, pos, c, start) do
    value = binary_part(xml, start, pos - start)
    {value, rest, pos + 1}
  end

  defp scan_quoted_loop(<<_, rest::binary>>, xml, pos, q, start) do
    scan_quoted_loop(rest, xml, pos + 1, q, start)
  end
end

# ============================================================
# Optimization #6: Direct Function Calls (no atom dispatch)
# ============================================================
defmodule OptDirectCalls do
  @moduledoc "Test: Direct function refs instead of atom dispatch"

  defguardp is_name_start(c) when
    c in ?a..?z or c in ?A..?Z or c == ?_ or c == ?: or
    c in 0x00C0..0x00D6 or c in 0x00D8..0x00F6 or
    c in 0x00F8..0x02FF or c in 0x0370..0x037D or
    c in 0x037F..0x1FFF or c in 0x200C..0x200D

  defguardp is_name_char(c) when
    is_name_start(c) or c == ?- or c == ?. or c in ?0..?9 or
    c == 0x00B7 or c in 0x0300..0x036F or c in 0x203F..0x2040

  def parse(xml, emit) when is_binary(xml) and is_function(emit, 1) do
    do_parse_all(xml, xml, 0, 1, 0, emit)
  end

  defp do_parse_all(<<>>, _xml, pos, line, ls, _emit), do: {:ok, pos, line, ls}

  defp do_parse_all(rest, xml, pos, line, ls, emit) do
    {pos, line, ls} = do_parse_one(rest, xml, pos, line, ls, emit)
    new_rest = binary_part(xml, pos, byte_size(xml) - pos)
    do_parse_all(new_rest, xml, pos, line, ls, emit)
  end

  defp do_parse_one(<<>>, _xml, pos, line, ls, _emit), do: {pos, line, ls}

  defp do_parse_one(<<"<?xml", rest::binary>>, xml, pos, line, ls, emit) do
    parse_prolog(rest, xml, pos + 5, line, ls, {line, ls, pos + 1}, emit)
  end

  defp do_parse_one(<<"<", _::binary>> = rest, xml, pos, line, ls, emit) do
    parse_element(rest, xml, pos, line, ls, emit)
  end

  defp do_parse_one(<<c, rest::binary>>, xml, pos, line, ls, emit) when c in [?\s, ?\t, ?\r] do
    do_parse_one(rest, xml, pos + 1, line, ls, emit)
  end

  defp do_parse_one(<<?\n, rest::binary>>, xml, pos, line, _ls, emit) do
    do_parse_one(rest, xml, pos + 1, line + 1, pos + 1, emit)
  end

  defp do_parse_one(rest, xml, pos, line, ls, emit) do
    parse_text(rest, xml, pos, line, ls, {line, ls, pos}, pos, emit)
  end

  defp parse_element(<<"<!--", rest::binary>>, xml, pos, line, ls, emit) do
    parse_comment(rest, xml, pos + 4, line, ls, {line, ls, pos + 1}, pos + 4, emit)
  end

  defp parse_element(<<"</", rest::binary>>, xml, pos, line, ls, emit) do
    # DIRECT: Instead of parse_name -> continue(:close_tag, ...), inline the flow
    parse_close_tag_name(rest, xml, pos + 2, line, ls, {line, ls, pos + 1}, pos + 2, emit)
  end

  defp parse_element(<<"<", c, _::binary>> = rest, xml, pos, line, ls, emit) when is_name_start(c) do
    <<"<", rest2::binary>> = rest
    # DIRECT: Instead of parse_name -> continue(:open_tag, ...), inline the flow
    parse_open_tag_name(rest2, xml, pos + 1, line, ls, {line, ls, pos + 1}, pos + 1, emit)
  end

  defp parse_element(_, _xml, pos, line, ls, emit) do
    emit.({:error, "Invalid element", {line, ls, pos}})
    {pos, line, ls}
  end

  # DIRECT: Inline name scanning for open tag
  defp parse_open_tag_name(<<c, rest::binary>>, xml, pos, line, ls, loc, start, emit) when is_name_char(c) do
    parse_open_tag_name(rest, xml, pos + 1, line, ls, loc, start, emit)
  end

  defp parse_open_tag_name(rest, xml, pos, line, ls, loc, start, emit) do
    name = binary_part(xml, start, pos - start)
    finish_open_tag(rest, xml, pos, line, ls, name, [], loc, emit)
  end

  # DIRECT: Inline name scanning for close tag
  defp parse_close_tag_name(<<c, rest::binary>>, xml, pos, line, ls, loc, start, emit) when is_name_char(c) do
    parse_close_tag_name(rest, xml, pos + 1, line, ls, loc, start, emit)
  end

  defp parse_close_tag_name(rest, xml, pos, line, ls, loc, start, emit) do
    name = binary_part(xml, start, pos - start)
    finish_close_tag(rest, xml, pos, line, ls, name, loc, emit)
  end

  # DIRECT: Inline name scanning for attribute
  defp parse_attr_name(<<c, rest::binary>>, xml, pos, line, ls, tag, attrs, loc, start, emit) when is_name_char(c) do
    parse_attr_name(rest, xml, pos + 1, line, ls, tag, attrs, loc, start, emit)
  end

  defp parse_attr_name(rest, xml, pos, line, ls, tag, attrs, loc, start, emit) do
    name = binary_part(xml, start, pos - start)
    parse_attr_eq(rest, xml, pos, line, ls, tag, name, attrs, loc, emit)
  end

  defp parse_prolog(rest, xml, pos, line, ls, loc, emit) do
    {pos, line, ls} = skip_ws(rest, xml, pos, line, ls)
    new_rest = binary_part(xml, pos, byte_size(xml) - pos)
    parse_prolog_content(new_rest, xml, pos, line, ls, loc, [], emit)
  end

  defp parse_prolog_content(<<"?>", _::binary>>, _xml, pos, line, ls, loc, attrs, emit) do
    emit.({:prolog, "xml", Enum.reverse(attrs), loc})
    {pos + 2, line, ls}
  end

  defp parse_prolog_content(<<c, rest::binary>>, xml, pos, line, ls, loc, attrs, emit) when c in [?\s, ?\t, ?\r] do
    parse_prolog_content(rest, xml, pos + 1, line, ls, loc, attrs, emit)
  end

  defp parse_prolog_content(<<?\n, rest::binary>>, xml, pos, line, _ls, loc, attrs, emit) do
    parse_prolog_content(rest, xml, pos + 1, line + 1, pos + 1, loc, attrs, emit)
  end

  defp parse_prolog_content(<<c, _::binary>> = rest, xml, pos, line, ls, loc, attrs, emit) when is_name_start(c) do
    # DIRECT: Inline prolog attr name scanning
    parse_prolog_attr_name(rest, xml, pos, line, ls, loc, attrs, pos, emit)
  end

  defp parse_prolog_content(_, _xml, pos, line, ls, _loc, _attrs, emit) do
    emit.({:error, "Expected '?>'", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_prolog_attr_name(<<c, rest::binary>>, xml, pos, line, ls, loc, attrs, start, emit) when is_name_char(c) do
    parse_prolog_attr_name(rest, xml, pos + 1, line, ls, loc, attrs, start, emit)
  end

  defp parse_prolog_attr_name(rest, xml, pos, line, ls, loc, attrs, start, emit) do
    name = binary_part(xml, start, pos - start)
    parse_prolog_attr_eq(rest, xml, pos, line, ls, name, loc, attrs, emit)
  end

  defp parse_prolog_attr_eq(<<"=", rest::binary>>, xml, pos, line, ls, name, loc, attrs, emit) do
    parse_prolog_attr_value_start(rest, xml, pos + 1, line, ls, name, loc, attrs, emit)
  end

  defp parse_prolog_attr_eq(<<c, rest::binary>>, xml, pos, line, ls, name, loc, attrs, emit) when c in [?\s, ?\t, ?\r] do
    parse_prolog_attr_eq(rest, xml, pos + 1, line, ls, name, loc, attrs, emit)
  end

  defp parse_prolog_attr_eq(<<?\n, rest::binary>>, xml, pos, line, _ls, name, loc, attrs, emit) do
    parse_prolog_attr_eq(rest, xml, pos + 1, line + 1, pos + 1, name, loc, attrs, emit)
  end

  defp parse_prolog_attr_eq(_, _xml, pos, line, ls, _name, _loc, _attrs, emit) do
    emit.({:error, "Expected '='", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_prolog_attr_value_start(<<c, rest::binary>>, xml, pos, line, ls, name, loc, attrs, emit) when c in [?\s, ?\t, ?\r] do
    parse_prolog_attr_value_start(rest, xml, pos + 1, line, ls, name, loc, attrs, emit)
  end

  defp parse_prolog_attr_value_start(<<?\n, rest::binary>>, xml, pos, line, _ls, name, loc, attrs, emit) do
    parse_prolog_attr_value_start(rest, xml, pos + 1, line + 1, pos + 1, name, loc, attrs, emit)
  end

  defp parse_prolog_attr_value_start(<<"\"", rest::binary>>, xml, pos, line, ls, name, loc, attrs, emit) do
    parse_prolog_attr_value(rest, xml, pos + 1, line, ls, ?", name, loc, attrs, pos + 1, emit)
  end

  defp parse_prolog_attr_value_start(<<"'", rest::binary>>, xml, pos, line, ls, name, loc, attrs, emit) do
    parse_prolog_attr_value(rest, xml, pos + 1, line, ls, ?', name, loc, attrs, pos + 1, emit)
  end

  defp parse_prolog_attr_value_start(_, _xml, pos, line, ls, _name, _loc, _attrs, emit) do
    emit.({:error, "Expected quoted value", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_prolog_attr_value(<<"\"", rest::binary>>, xml, pos, line, ls, ?", name, loc, attrs, start, emit) do
    value = binary_part(xml, start, pos - start)
    parse_prolog_content(rest, xml, pos + 1, line, ls, loc, [{name, value} | attrs], emit)
  end

  defp parse_prolog_attr_value(<<"'", rest::binary>>, xml, pos, line, ls, ?', name, loc, attrs, start, emit) do
    value = binary_part(xml, start, pos - start)
    parse_prolog_content(rest, xml, pos + 1, line, ls, loc, [{name, value} | attrs], emit)
  end

  defp parse_prolog_attr_value(<<_, rest::binary>>, xml, pos, line, ls, q, name, loc, attrs, start, emit) do
    parse_prolog_attr_value(rest, xml, pos + 1, line, ls, q, name, loc, attrs, start, emit)
  end

  defp finish_open_tag(<<"/>", _::binary>>, _xml, pos, line, ls, name, attrs, loc, emit) do
    emit.({:open, name, Enum.reverse(attrs), loc})
    emit.({:close, name})
    {pos + 2, line, ls}
  end

  defp finish_open_tag(<<">", _::binary>>, _xml, pos, line, ls, name, attrs, loc, emit) do
    emit.({:open, name, Enum.reverse(attrs), loc})
    {pos + 1, line, ls}
  end

  defp finish_open_tag(<<c, rest::binary>>, xml, pos, line, ls, name, attrs, loc, emit) when c in [?\s, ?\t, ?\r] do
    finish_open_tag(rest, xml, pos + 1, line, ls, name, attrs, loc, emit)
  end

  defp finish_open_tag(<<?\n, rest::binary>>, xml, pos, line, _ls, name, attrs, loc, emit) do
    finish_open_tag(rest, xml, pos + 1, line + 1, pos + 1, name, attrs, loc, emit)
  end

  defp finish_open_tag(<<c, _::binary>> = rest, xml, pos, line, ls, name, attrs, loc, emit) when is_name_start(c) do
    # DIRECT: Inline attr name scanning
    parse_attr_name(rest, xml, pos, line, ls, name, attrs, loc, pos, emit)
  end

  defp finish_open_tag(_, _xml, pos, line, ls, _name, _attrs, _loc, emit) do
    emit.({:error, "Expected '>', '/>', or attribute", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_attr_eq(<<"=", rest::binary>>, xml, pos, line, ls, tag, name, attrs, loc, emit) do
    parse_attr_value_start(rest, xml, pos + 1, line, ls, tag, name, attrs, loc, emit)
  end

  defp parse_attr_eq(<<c, rest::binary>>, xml, pos, line, ls, tag, name, attrs, loc, emit) when c in [?\s, ?\t, ?\r] do
    parse_attr_eq(rest, xml, pos + 1, line, ls, tag, name, attrs, loc, emit)
  end

  defp parse_attr_eq(<<?\n, rest::binary>>, xml, pos, line, _ls, tag, name, attrs, loc, emit) do
    parse_attr_eq(rest, xml, pos + 1, line + 1, pos + 1, tag, name, attrs, loc, emit)
  end

  defp parse_attr_eq(_, _xml, pos, line, ls, _tag, _name, _attrs, _loc, emit) do
    emit.({:error, "Expected '='", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_attr_value_start(<<c, rest::binary>>, xml, pos, line, ls, tag, name, attrs, loc, emit) when c in [?\s, ?\t, ?\r] do
    parse_attr_value_start(rest, xml, pos + 1, line, ls, tag, name, attrs, loc, emit)
  end

  defp parse_attr_value_start(<<?\n, rest::binary>>, xml, pos, line, _ls, tag, name, attrs, loc, emit) do
    parse_attr_value_start(rest, xml, pos + 1, line + 1, pos + 1, tag, name, attrs, loc, emit)
  end

  defp parse_attr_value_start(<<"\"", rest::binary>>, xml, pos, line, ls, tag, name, attrs, loc, emit) do
    parse_attr_value(rest, xml, pos + 1, line, ls, ?", tag, name, attrs, loc, pos + 1, emit)
  end

  defp parse_attr_value_start(<<"'", rest::binary>>, xml, pos, line, ls, tag, name, attrs, loc, emit) do
    parse_attr_value(rest, xml, pos + 1, line, ls, ?', tag, name, attrs, loc, pos + 1, emit)
  end

  defp parse_attr_value_start(_, _xml, pos, line, ls, _tag, _name, _attrs, _loc, emit) do
    emit.({:error, "Expected quoted value", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_attr_value(<<"\"", rest::binary>>, xml, pos, line, ls, ?", tag, name, attrs, loc, start, emit) do
    value = binary_part(xml, start, pos - start)
    finish_open_tag(rest, xml, pos + 1, line, ls, tag, [{name, value} | attrs], loc, emit)
  end

  defp parse_attr_value(<<"'", rest::binary>>, xml, pos, line, ls, ?', tag, name, attrs, loc, start, emit) do
    value = binary_part(xml, start, pos - start)
    finish_open_tag(rest, xml, pos + 1, line, ls, tag, [{name, value} | attrs], loc, emit)
  end

  defp parse_attr_value(<<?\n, rest::binary>>, xml, pos, line, _ls, q, tag, name, attrs, loc, start, emit) do
    parse_attr_value(rest, xml, pos + 1, line + 1, pos + 1, q, tag, name, attrs, loc, start, emit)
  end

  defp parse_attr_value(<<_, rest::binary>>, xml, pos, line, ls, q, tag, name, attrs, loc, start, emit) do
    parse_attr_value(rest, xml, pos + 1, line, ls, q, tag, name, attrs, loc, start, emit)
  end

  defp parse_attr_value(<<>>, _xml, pos, line, ls, _q, _tag, _name, _attrs, _loc, _start, emit) do
    emit.({:error, "Unterminated attribute value", {line, ls, pos}})
    {pos, line, ls}
  end

  defp finish_close_tag(<<">", _::binary>>, _xml, pos, line, ls, name, loc, emit) do
    emit.({:close, name, loc})
    {pos + 1, line, ls}
  end

  defp finish_close_tag(<<c, rest::binary>>, xml, pos, line, ls, name, loc, emit) when c in [?\s, ?\t, ?\r] do
    finish_close_tag(rest, xml, pos + 1, line, ls, name, loc, emit)
  end

  defp finish_close_tag(<<?\n, rest::binary>>, xml, pos, line, _ls, name, loc, emit) do
    finish_close_tag(rest, xml, pos + 1, line + 1, pos + 1, name, loc, emit)
  end

  defp finish_close_tag(_, _xml, pos, line, ls, _name, _loc, emit) do
    emit.({:error, "Expected '>'", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_comment(<<"-->", _::binary>>, xml, pos, line, ls, loc, start, emit) do
    content = binary_part(xml, start, pos - start)
    emit.({:comment, content, loc})
    {pos + 3, line, ls}
  end

  defp parse_comment(<<?\n, rest::binary>>, xml, pos, line, _ls, loc, start, emit) do
    parse_comment(rest, xml, pos + 1, line + 1, pos + 1, loc, start, emit)
  end

  defp parse_comment(<<_, rest::binary>>, xml, pos, line, ls, loc, start, emit) do
    parse_comment(rest, xml, pos + 1, line, ls, loc, start, emit)
  end

  defp parse_comment(<<>>, _xml, pos, line, ls, _loc, _start, emit) do
    emit.({:error, "Unterminated comment", {line, ls, pos}})
    {pos, line, ls}
  end

  defp parse_text(<<"<", _::binary>>, xml, pos, line, ls, loc, start, emit) do
    content = binary_part(xml, start, pos - start)
    emit.({:text, content, loc})
    {pos, line, ls}
  end

  defp parse_text(<<?\n, rest::binary>>, xml, pos, line, _ls, loc, start, emit) do
    parse_text(rest, xml, pos + 1, line + 1, pos + 1, loc, start, emit)
  end

  defp parse_text(<<_, rest::binary>>, xml, pos, line, ls, loc, start, emit) do
    parse_text(rest, xml, pos + 1, line, ls, loc, start, emit)
  end

  defp parse_text(<<>>, xml, pos, line, ls, loc, start, emit) do
    content = binary_part(xml, start, pos - start)
    emit.({:text, content, loc})
    {pos, line, ls}
  end

  defp skip_ws(<<c, rest::binary>>, xml, pos, line, ls) when c in [?\s, ?\t, ?\r] do
    skip_ws(rest, xml, pos + 1, line, ls)
  end

  defp skip_ws(<<?\n, rest::binary>>, xml, pos, line, _ls) do
    skip_ws(rest, xml, pos + 1, line + 1, pos + 1)
  end

  defp skip_ws(_, _xml, pos, line, ls), do: {pos, line, ls}
end

# ============================================================
# Run Benchmarks
# ============================================================

medium = File.read!("bench/data/medium.xml")

IO.puts("=" |> String.duplicate(60))
IO.puts("OPTIMIZATION BENCHMARKS")
IO.puts("=" |> String.duplicate(60))
IO.puts("\nFile size: #{byte_size(medium)} bytes\n")

IO.puts("Optimizations tested:")
IO.puts("  - parser: FnXML.Parser (main parser)")
IO.puts("  - bulk_ws: Bulk whitespace skip (#2)")
IO.puts("  - fewer_params: Consolidate params into tuples (#5)")
IO.puts("  - direct_calls: Benchmark test version of #6")
IO.puts("  - saxy: Reference (Saxy)")
IO.puts("")

Benchee.run(
  %{
    "saxy" => fn -> Saxy.parse_string(medium, NullHandler, nil) end,
    "parser" => fn -> FnXML.Parser.parse(medium, fn _ -> :ok end) end,
    "bulk_ws" => fn -> OptBulkWS.parse(medium, fn _ -> :ok end) end,
    "fewer_params" => fn -> OptFewerParams.parse(medium, fn _ -> :ok end) end,
    "direct_calls" => fn -> OptDirectCalls.parse(medium, fn _ -> :ok end) end
  },
  warmup: 2,
  time: 8,
  memory_time: 2
)
