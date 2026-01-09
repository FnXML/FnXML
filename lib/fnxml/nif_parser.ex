# Check if Zig/Zigler is available at compile time
# The entire module definition is conditional to avoid macro expansion issues
if Code.ensure_loaded?(Zig) and FnXML.MixProject.nif_enabled?() do
  defmodule FnXML.NifParser do
    @moduledoc """
    High-performance NIF-based XML parser written in Zig.

    Processes XML in chunks, enabling streaming parsing of large documents
    with minimal memory overhead.

    > #### Optional Zig NIF {: .info}
    >
    > This module requires the Zig compiler and the `:zigler` dependency.
    > To use pure Elixir only (no Zig), add to your dependency:
    >
    >     {:fnxml, "~> 0.2", nif: false}
    >
    > Or set: `FNXML_NIF=false`
    >
    > When NIF is disabled, this module delegates to `FnXML.Parser` (pure Elixir).

    ## Usage

        # Single chunk parsing
        {events, leftover_pos, new_state} = FnXML.NifParser.parse(xml_chunk, nil, 0, {1, 0, 0})

        # Multi-chunk streaming
        state = {1, 0, 0}
        {events1, pos, state} = FnXML.NifParser.parse(chunk1, nil, 0, state)
        {events2, _, state} = FnXML.NifParser.parse(chunk2, chunk1, pos, state)
    """

    use Zig,
      otp_app: :fnxml,
      zig_code_path: "NifParser.zig",
      nifs: [nif_parse: [:dirty_cpu]]

    @doc """
    Returns true if NIF acceleration is enabled.
    """
    def nif_enabled?, do: true

    @doc """
    Parse XML chunk.

    ## Parameters

    - `block` - Current chunk of XML data
    - `prev_block` - Previous chunk if element spans chunks, or `nil`
    - `prev_pos` - Position in prev_block to start from
    - `state` - Parser state tuple: `{line, column, byte_offset}`

    ## Returns

    `{events, leftover_pos, new_state}` where:
    - `events` - List of parsed event tuples
    - `leftover_pos` - Position in current block where parsing stopped, or `nil`
    - `new_state` - Updated `{line, column, byte_offset}` state
    """
    def parse(block, prev_block, prev_pos, {line, col, byte}) do
      {events, leftover, new_state} = nif_parse(block, prev_block, prev_pos, line, col, byte)
      {events, leftover, new_state}
    end

    @doc """
    Stream XML from a file or enumerable, parsing in chunks.
    """
    def stream(source, opts \\ []) do
      max_join_count = Keyword.get(opts, :max_join_count, 10)

      Stream.resource(
        fn -> init_stream_state(source) end,
        fn state -> next_events(state, max_join_count) end,
        fn _state -> :ok end
      )
    end

    defp init_stream_state(source) when is_binary(source) do
      %{
        source: [source],
        prev_block: nil,
        prev_pos: 0,
        parser_state: {1, 0, 0},
        join_count: 0
      }
    end

    defp init_stream_state(source) do
      %{
        source: source,
        prev_block: nil,
        prev_pos: 0,
        parser_state: {1, 0, 0},
        join_count: 0
      }
    end

    defp next_events(%{source: source} = state, max_join_count) do
      case get_next_chunk(source) do
        {:ok, chunk, rest_source} ->
          {events, leftover_pos, new_parser_state} =
            parse(chunk, state.prev_block, state.prev_pos, state.parser_state)

          case find_advance_error(events) do
            nil ->
              {new_prev_block, new_prev_pos} =
                case {leftover_pos, state.prev_block} do
                  {nil, _} -> {nil, 0}
                  {0, prev} when prev != nil ->
                    combined = binary_part(prev, state.prev_pos, byte_size(prev) - state.prev_pos) <> chunk
                    {combined, 0}
                  {pos, _} -> {chunk, pos}
                end

              new_state = %{state |
                source: rest_source,
                prev_block: new_prev_block,
                prev_pos: new_prev_pos,
                parser_state: new_parser_state,
                join_count: 0
              }

              {filter_advance_errors(events), new_state}

            _error when state.join_count >= max_join_count ->
              {[{:error, :advance, "Element exceeds maximum chunk span", {0, 0, 0}}],
               %{state | source: []}}

            _error ->
              joined = if state.prev_block do
                binary_part(state.prev_block, state.prev_pos, byte_size(state.prev_block) - state.prev_pos) <> chunk
              else
                chunk
              end

              new_state = %{state |
                source: [joined | rest_source],
                prev_block: nil,
                prev_pos: 0,
                join_count: state.join_count + 1
              }

              next_events(new_state, max_join_count)
          end

        :eof ->
          if state.prev_block do
            remaining = binary_part(state.prev_block, state.prev_pos, byte_size(state.prev_block) - state.prev_pos)

            if byte_size(remaining) > 0 do
              {events, _, _} = parse(<<>>, remaining, 0, state.parser_state)
              {events ++ [{:end_document, state.parser_state}], %{state | source: [], prev_block: nil}}
            else
              {:halt, state}
            end
          else
            {:halt, state}
          end
      end
    end

    defp get_next_chunk([chunk | rest]) when is_binary(chunk), do: {:ok, chunk, rest}
    defp get_next_chunk([]), do: :eof
    defp get_next_chunk(stream) do
      case Enum.take(stream, 1) do
        [chunk] -> {:ok, chunk, Stream.drop(stream, 1)}
        [] -> :eof
      end
    end

    defp find_advance_error(events) do
      Enum.find(events, fn
        {:error, :advance, _, _} -> true
        _ -> false
      end)
    end

    defp filter_advance_errors(events) do
      Enum.reject(events, fn
        {:error, :advance, _, _} -> true
        _ -> false
      end)
    end
  end
else
  defmodule FnXML.NifParser do
    @moduledoc """
    XML parser fallback module (pure Elixir).

    This module provides the same API as the NIF-accelerated parser but uses
    pure Elixir implementation. It is used when:

    1. Zig/Zigler is not installed
    2. `FNXML_NIF=false` environment variable is set
    3. Parent project specifies `{:fnxml, "~> x.x", nif: false}` in deps

    To enable NIF acceleration, ensure:
    - Zig compiler is installed
    - Remove `nif: false` from dependency (if set)
    - Remove `FNXML_NIF=false` env var (if set)
    """

    @doc """
    Returns true if NIF acceleration is enabled.
    """
    def nif_enabled?, do: false

    @doc """
    Parse XML chunk (pure Elixir fallback).

    This delegates to `FnXML.Parser` for actual parsing work.

    Note: The pure Elixir fallback does not support true chunking like the NIF.
    It accumulates all data and parses when complete XML is available.
    """
    def parse(block, prev_block, prev_pos, {line, col, byte}) do
      # Reconstruct the full input if there's leftover from previous chunk
      input = if prev_block do
        leftover = binary_part(prev_block, prev_pos, byte_size(prev_block) - prev_pos)
        leftover <> block
      else
        block
      end

      # Try to parse using pure Elixir parser (stream mode)
      try do
        events =
          FnXML.Parser.parse(input)
          |> Enum.to_list()
          |> Enum.map(fn event -> convert_event(event, {line, col, byte}) end)

        {events, nil, update_position({line, col, byte}, input)}
      rescue
        # If parsing fails (incomplete XML), signal need for more data
        _ ->
          # Return advance error to indicate we need more chunks
          {[{:error, :advance, nil, {line, col, byte}}], 0, {line, col, byte}}
      end
    end

    defp convert_event(event, pos) do
      case event do
        {:start_element, tag, attrs, _event_pos} -> {:start_element, tag, attrs, pos}
        {:start_element, tag, attrs} -> {:start_element, tag, attrs, pos}
        {:end_element, tag, _event_pos} -> {:end_element, tag, pos}
        {:end_element, tag} -> {:end_element, tag, pos}
        {:characters, text, _event_pos} -> {:characters, text, pos}
        {:characters, text} -> {:characters, text, pos}
        {:comment, text, _event_pos} -> {:comment, text, pos}
        {:comment, text} -> {:comment, text, pos}
        {:processing_instruction, target, data, _event_pos} -> {:processing_instruction, target, data, pos}
        {:processing_instruction, target, data} -> {:processing_instruction, target, data, pos}
        {:cdata, text, _event_pos} -> {:cdata, text, pos}
        {:cdata, text} -> {:cdata, text, pos}
        {:start_document, _} -> {:start_document, pos}
        {:end_document, _} -> {:end_document, pos}
        other -> other
      end
    end

    defp update_position({line, _col, byte}, input) do
      lines = String.split(input, ~r/\r?\n/, parts: :infinity)
      new_lines = length(lines) - 1
      last_line = List.last(lines)
      new_col = if new_lines > 0, do: String.length(last_line), else: String.length(input)
      {line + new_lines, new_col, byte + byte_size(input)}
    end

    @doc """
    Stream XML from a file or enumerable, parsing in chunks (pure Elixir fallback).
    """
    def stream(source, opts \\ []) do
      max_join_count = Keyword.get(opts, :max_join_count, 10)

      Stream.resource(
        fn -> init_stream_state(source) end,
        fn state -> next_events(state, max_join_count) end,
        fn _state -> :ok end
      )
    end

    defp init_stream_state(source) when is_binary(source) do
      %{
        source: [source],
        prev_block: nil,
        prev_pos: 0,
        parser_state: {1, 0, 0},
        join_count: 0
      }
    end

    defp init_stream_state(source) do
      %{
        source: source,
        prev_block: nil,
        prev_pos: 0,
        parser_state: {1, 0, 0},
        join_count: 0
      }
    end

    defp next_events(%{source: source} = state, max_join_count) do
      case get_next_chunk(source) do
        {:ok, chunk, rest_source} ->
          {events, leftover_pos, new_parser_state} =
            parse(chunk, state.prev_block, state.prev_pos, state.parser_state)

          case find_advance_error(events) do
            nil ->
              {new_prev_block, new_prev_pos} =
                case {leftover_pos, state.prev_block} do
                  {nil, _} -> {nil, 0}
                  {0, prev} when prev != nil ->
                    combined = binary_part(prev, state.prev_pos, byte_size(prev) - state.prev_pos) <> chunk
                    {combined, 0}
                  {pos, _} -> {chunk, pos}
                end

              new_state = %{state |
                source: rest_source,
                prev_block: new_prev_block,
                prev_pos: new_prev_pos,
                parser_state: new_parser_state,
                join_count: 0
              }

              {filter_advance_errors(events), new_state}

            _error when state.join_count >= max_join_count ->
              {[{:error, :advance, "Element exceeds maximum chunk span", {0, 0, 0}}],
               %{state | source: []}}

            _error ->
              joined = if state.prev_block do
                binary_part(state.prev_block, state.prev_pos, byte_size(state.prev_block) - state.prev_pos) <> chunk
              else
                chunk
              end

              new_state = %{state |
                source: [joined | rest_source],
                prev_block: nil,
                prev_pos: 0,
                join_count: state.join_count + 1
              }

              next_events(new_state, max_join_count)
          end

        :eof ->
          if state.prev_block do
            remaining = binary_part(state.prev_block, state.prev_pos, byte_size(state.prev_block) - state.prev_pos)

            if byte_size(remaining) > 0 do
              {events, _, _} = parse(<<>>, remaining, 0, state.parser_state)
              {events ++ [{:end_document, state.parser_state}], %{state | source: [], prev_block: nil}}
            else
              {:halt, state}
            end
          else
            {:halt, state}
          end
      end
    end

    defp get_next_chunk([chunk | rest]) when is_binary(chunk), do: {:ok, chunk, rest}
    defp get_next_chunk([]), do: :eof
    defp get_next_chunk(stream) do
      case Enum.take(stream, 1) do
        [chunk] -> {:ok, chunk, Stream.drop(stream, 1)}
        [] -> :eof
      end
    end

    defp find_advance_error(events) do
      Enum.find(events, fn
        {:error, :advance, _, _} -> true
        _ -> false
      end)
    end

    defp filter_advance_errors(events) do
      Enum.reject(events, fn
        {:error, :advance, _, _} -> true
        _ -> false
      end)
    end
  end
end
