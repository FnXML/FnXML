# FnXML Benchmark Results

Comprehensive benchmarks comparing FnXML parsers against other Elixir/Erlang XML libraries.

## Environment

- **OS**: macOS (Darwin 25.1.0)
- **CPU**: Apple M1
- **Cores**: 8
- **Memory**: 16 GB
- **Elixir**: 1.19.3
- **Erlang**: 28.1.1
- **JIT**: Enabled

## Test Data

| File | Size | Description |
|------|------|-------------|
| small.xml | 757 B | Simple catalog with 2 books |
| medium.xml | 249 KB | 500 items with nested elements |
| large.xml | 1.3 MB | 2500 items with nested elements |

## Parsers Compared

| Parser | Type | Description |
|--------|------|-------------|
| **FnXML.Parser** | Stream/Callback | Main parser - CPS recursive descent (fastest) |
| **saxy** | SAX | External, highly optimized callback-based parser |
| **erlsom** | SAX/DOM | External Erlang library, simple_form mode |
| **xmerl** | DOM | Erlang stdlib, full DOM tree |
| **nimble** | Stream | FnXML NimbleParsec-based (legacy) |

---

## Parse Speed Comparison (iterations per second)

### Small File (757 bytes)

| Parser | Speed (ips) | vs FnXML | Notes |
|--------|-------------|----------|-------|
| **fnxml** | **216,361** | 1.00x | Fastest |
| saxy | 142,764 | 1.52x slower | |
| erlsom | 108,675 | 1.99x slower | |
| xmerl | 16,841 | 12.85x slower | |

### Medium File (249 KB)

| Parser | Speed (ips) | vs FnXML | Notes |
|--------|-------------|----------|-------|
| **fnxml** | **591** | 1.00x | Fastest |
| saxy | 397 | 1.49x slower | |
| erlsom | 207 | 2.86x slower | |
| xmerl | 54 | 10.9x slower | |

### Large File (1.3 MB)

| Parser | Speed (ips) | vs FnXML | Notes |
|--------|-------------|----------|-------|
| **fnxml** | **129** | 1.00x | Fastest |
| saxy | 88 | 1.46x slower | |
| erlsom | 26 | 4.92x slower | |
| xmerl | 11 | 11.9x slower | |

---

## Memory Usage Comparison

### Small File (757 bytes)

| Parser | Memory | vs FnXML |
|--------|--------|----------|
| **fnxml** | **10.7 KB** | 1.00x |
| saxy | 11.1 KB | 1.04x more |
| erlsom | 53.2 KB | 4.99x more |
| xmerl | 270 KB | 25.1x more |

### Medium File (249 KB)

| Parser | Memory | vs FnXML |
|--------|--------|----------|
| **fnxml** | **3.69 MB** | 1.00x |
| saxy | 3.89 MB | 1.05x more |
| erlsom | 17.98 MB | 4.87x more |
| xmerl | 86.92 MB | 23.5x more |

### Large File (1.3 MB)

| Parser | Memory | vs FnXML |
|--------|--------|----------|
| **fnxml** | **14.61 MB** | 1.00x |
| saxy | 15.70 MB | 1.07x more |
| erlsom | 92.69 MB | 6.34x more |
| xmerl | 412.70 MB | 28.2x more |

---

## FnXML Parser Variants Comparison (Medium File)

All FnXML parser implementations compared on medium.xml:

| Parser | Speed (ips) | Memory | Description |
|--------|-------------|--------|-------------|
| **parser_stream** | **605** | 3.69 MB | Main parser, Stream mode |
| **parser_cb** | **596** | 2.31 MB | Main parser, Callback mode |
| recursive | 264 | 13.67 MB | Sub-binary rest approach |
| zig_simd | 250 | 5.44 MB | Zig SIMD scanner |
| elixir_idx | 231 | 6.64 MB | Elixir index-based |
| recursive_pos | 147 | 4.94 MB | Position tracking |
| recursive_emit | 120 | 5.57 MB | Emit + process dict |
| nimble | 90 | 39.92 MB | NimbleParsec (legacy) |

**Key findings:**
- Main parser is **6.7x faster** than the original NimbleParsec implementation
- Callback mode uses **40% less memory** than Stream mode
- Main parser is **1.56x faster than Saxy**

---

## Summary: FnXML vs Competition

| Metric | vs Saxy | vs erlsom | vs xmerl |
|--------|---------|-----------|----------|
| **Speed (small)** | 1.52x faster | 1.99x faster | 12.9x faster |
| **Speed (medium)** | 1.49x faster | 2.86x faster | 10.9x faster |
| **Speed (large)** | 1.46x faster | 4.92x faster | 11.9x faster |
| **Memory (medium)** | 5% less | 4.9x less | 23.5x less |
| **Memory (large)** | 7% less | 6.3x less | 28.2x less |

---

## Architecture

### CPS Recursive Descent Parser (Current)

```
XML Input → Binary Pattern Match → Emit Event → Continue
            (single pass)         (direct)      (tail-call)
```

Key optimizations:
- **Continuation-passing style**: Tail-call optimized, minimal stack usage
- **Single binary reference**: Uses `binary_part/3` for zero-copy content extraction
- **Position tracking**: Integer offsets instead of creating sub-binary "rest"
- **Inlined name scanning**: Tag/attribute names parsed inline at call sites
- **Dual code paths**: Optimized for both Stream and Callback modes
- **Guard-based dispatch**: Character classes use guards for efficient branching

### Why FnXML is Fast

1. **Zero-copy parsing**: Content extracted via `binary_part/3` references original binary
2. **No intermediate AST**: Events emitted directly without building tree structure
3. **Minimal allocations**: Only event tuples are allocated during parsing
4. **Tail-call optimization**: CPS enables true tail recursion throughout
5. **BEAM-optimized patterns**: Multi-byte patterns like `<!--` matched directly

---

## When to Use Each Mode

| Use Case | Recommended |
|----------|-------------|
| Maximum speed, full document | `FnXML.Parser.parse(xml, callback)` |
| Streaming with transformations | `FnXML.Parser.parse(xml)` |
| Early termination (Enum.take, etc.) | `FnXML.Parser.parse(xml)` |
| Minimum memory | `FnXML.Parser.parse(xml, callback)` |

---

## Running Benchmarks

```bash
# Quick benchmark (medium file, main parsers)
mix run bench/parse_bench.exs --quick

# Full benchmark (all file sizes)
mix run bench/parse_bench.exs

# All FnXML parser variants comparison
mix run bench/all_parsers_bench.exs

# Memory-focused benchmarks
mix run bench/memory_bench.exs
```

## Regenerating Test Data

```bash
mix run bench/generate_data.exs
```
