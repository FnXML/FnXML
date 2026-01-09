# Nx Scanning Benchmark
# Run with: mix run bench/nx_scan_bench.exs
#
# Tests whether Nx can accelerate character scanning for XML parsing

defmodule NxScanBench do
  @medium File.read!("bench/data/medium.xml")

  # Characters of interest for XML parsing
  @lt ?<
  @gt ?>
  @eq ?=
  @dquote ?"
  @squote ?'
  @slash ?/

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("NX SCANNING BENCHMARK")
    IO.puts("Testing whether Nx can accelerate character scanning")
    IO.puts(String.duplicate("=", 70) <> "\n")

    IO.puts("File: medium.xml (#{byte_size(@medium)} bytes)")
    IO.puts("")

    # Warm up Nx
    _ = Nx.tensor([1, 2, 3])

    Benchee.run(
      %{
        # Approach 1: Nx tensor scan for '<' positions
        "nx_find_lt" => fn ->
          find_char_positions_nx(@medium, @lt)
        end,

        # Approach 2: Pure Elixir binary scan for '<' positions
        "elixir_find_lt" => fn ->
          find_char_positions_elixir(@medium, @lt)
        end,

        # Approach 3: Erlang :binary.matches
        "binary_matches_lt" => fn ->
          :binary.matches(@medium, <<"<">>)
        end,

        # Approach 4: Nx scan for multiple characters at once
        "nx_find_all_structural" => fn ->
          find_structural_chars_nx(@medium)
        end,

        # Approach 5: Elixir scan for multiple characters
        "elixir_find_all_structural" => fn ->
          find_structural_chars_elixir(@medium)
        end,

        # Approach 6: Just count '<' chars (baseline)
        "count_lt_only" => fn ->
          count_char(@medium, @lt)
        end
      },
      warmup: 1,
      time: 3,
      memory_time: 1,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_overhead_test do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("NX OVERHEAD ANALYSIS")
    IO.puts("Breaking down where time is spent")
    IO.puts(String.duplicate("=", 70) <> "\n")

    Benchee.run(
      %{
        # Step 1: Just convert binary to tensor
        "binary_to_tensor" => fn ->
          @medium
          |> :binary.bin_to_list()
          |> Nx.tensor(type: :u8)
        end,

        # Step 2: Tensor comparison only (pre-converted)
        "tensor_compare" => fn ->
          tensor = Nx.tensor(:binary.bin_to_list(@medium), type: :u8)
          Nx.equal(tensor, @lt)
        end,

        # Step 3: Extract results from tensor
        "tensor_to_list" => fn ->
          tensor = Nx.tensor(:binary.bin_to_list(@medium), type: :u8)
          mask = Nx.equal(tensor, @lt)
          Nx.to_flat_list(mask)
        end,

        # Full Nx pipeline
        "nx_full_pipeline" => fn ->
          find_char_positions_nx(@medium, @lt)
        end,

        # Elixir baseline
        "elixir_baseline" => fn ->
          find_char_positions_elixir(@medium, @lt)
        end
      },
      warmup: 1,
      time: 3,
      formatters: [Benchee.Formatters.Console]
    )
  end

  # Nx-based character position finder
  defp find_char_positions_nx(binary, char) do
    binary
    |> :binary.bin_to_list()
    |> Nx.tensor(type: :u8)
    |> Nx.equal(char)
    |> Nx.to_flat_list()
    |> Enum.with_index()
    |> Enum.filter(fn {v, _} -> v == 1 end)
    |> Enum.map(fn {_, i} -> i end)
  end

  # Pure Elixir character position finder
  defp find_char_positions_elixir(binary, char) do
    find_positions(binary, char, 0, [])
  end

  defp find_positions(<<>>, _char, _pos, acc), do: Enum.reverse(acc)
  defp find_positions(<<c, rest::binary>>, char, pos, acc) when c == char do
    find_positions(rest, char, pos + 1, [pos | acc])
  end
  defp find_positions(<<_, rest::binary>>, char, pos, acc) do
    find_positions(rest, char, pos + 1, acc)
  end

  # Nx-based multi-character scanner
  defp find_structural_chars_nx(binary) do
    bytes = :binary.bin_to_list(binary)
    tensor = Nx.tensor(bytes, type: :u8)

    # Find each structural character
    lt_mask = Nx.equal(tensor, @lt)
    gt_mask = Nx.equal(tensor, @gt)
    eq_mask = Nx.equal(tensor, @eq)
    dq_mask = Nx.equal(tensor, @dquote)

    # Combine masks
    combined = Nx.logical_or(lt_mask, gt_mask)
    |> Nx.logical_or(eq_mask)
    |> Nx.logical_or(dq_mask)

    Nx.to_flat_list(combined)
    |> Enum.with_index()
    |> Enum.filter(fn {v, _} -> v == 1 end)
    |> Enum.map(fn {_, i} -> i end)
  end

  # Elixir-based multi-character scanner
  defp find_structural_chars_elixir(binary) do
    find_structural(binary, 0, [])
  end

  defp find_structural(<<>>, _pos, acc), do: Enum.reverse(acc)
  defp find_structural(<<c, rest::binary>>, pos, acc)
       when c == @lt or c == @gt or c == @eq or c == @dquote do
    find_structural(rest, pos + 1, [pos | acc])
  end
  defp find_structural(<<_, rest::binary>>, pos, acc) do
    find_structural(rest, pos, acc)
  end

  # Simple character counter
  defp count_char(binary, char) do
    do_count(binary, char, 0)
  end

  defp do_count(<<>>, _char, count), do: count
  defp do_count(<<c, rest::binary>>, char, count) when c == char do
    do_count(rest, char, count + 1)
  end
  defp do_count(<<_, rest::binary>>, char, count) do
    do_count(rest, char, count)
  end
end

case System.argv() do
  ["--overhead"] -> NxScanBench.run_overhead_test()
  _ -> NxScanBench.run()
end
