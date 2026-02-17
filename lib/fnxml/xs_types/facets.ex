defmodule FnXML.XsTypes.Facets do
  @moduledoc """
  XSD facet validation.

  Facets are constraining rules that can be applied to XSD types to
  further restrict their value space.

  ## Supported Facets

  | Facet | Description | Applicable Types |
  |-------|-------------|------------------|
  | length | Exact length | string, binary, list types |
  | minLength | Minimum length | string, binary, list types |
  | maxLength | Maximum length | string, binary, list types |
  | pattern | Regex pattern | All types |
  | enumeration | Allowed values | All types |
  | minInclusive | Minimum value (≥) | Numeric, date/time types |
  | maxInclusive | Maximum value (≤) | Numeric, date/time types |
  | minExclusive | Minimum value (>) | Numeric, date/time types |
  | maxExclusive | Maximum value (<) | Numeric, date/time types |
  | totalDigits | Max total digits | Decimal types |
  | fractionDigits | Max fraction digits | Decimal types |
  | whiteSpace | Whitespace handling | String types |

  ## Examples

      iex> FnXML.XsTypes.Facets.validate("hello", :string, [{:minLength, 1}, {:maxLength, 10}])
      :ok

      iex> FnXML.XsTypes.Facets.validate("50", :integer, [{:minInclusive, "0"}, {:maxInclusive, "100"}])
      :ok
  """

  alias FnXML.XsTypes.Hierarchy

  @type facet ::
          {:length, non_neg_integer()}
          | {:minLength, non_neg_integer()}
          | {:maxLength, non_neg_integer()}
          | {:pattern, String.t()}
          | {:enumeration, [String.t()]}
          | {:minInclusive, String.t()}
          | {:maxInclusive, String.t()}
          | {:minExclusive, String.t()}
          | {:maxExclusive, String.t()}
          | {:totalDigits, pos_integer()}
          | {:fractionDigits, non_neg_integer()}
          | {:whiteSpace, :preserve | :replace | :collapse}

  @doc """
  Validate a value against a list of facets.

  ## Examples

      iex> FnXML.XsTypes.Facets.validate("hello", :string, [{:minLength, 1}])
      :ok

      iex> FnXML.XsTypes.Facets.validate("", :string, [{:minLength, 1}])
      {:error, {:facet_violation, :minLength, [expected: 1, got: 0]}}
  """
  @spec validate(String.t(), atom(), [facet()]) :: :ok | {:error, term()}
  def validate(_value, _type, []), do: :ok

  def validate(value, type, facets) do
    # Separate enumeration facets (OR logic) from other facets (AND logic)
    {enum_facets, other_facets} =
      Enum.split_with(facets, fn
        {:enumeration, _} -> true
        _ -> false
      end)

    # First validate enumeration (if any)
    enum_result = validate_enumerations(value, enum_facets)

    case enum_result do
      :ok ->
        # Then validate all other facets (all must pass)
        Enum.reduce_while(other_facets, :ok, fn facet, :ok ->
          case validate_facet(value, type, facet) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      error ->
        error
    end
  end

  defp validate_enumerations(_value, []), do: :ok

  defp validate_enumerations(value, enum_facets) do
    enum_values = Enum.flat_map(enum_facets, fn {:enumeration, vals} -> vals end)

    if value in enum_values do
      :ok
    else
      {:error, {:facet_violation, :enumeration, [expected: enum_values, got: value]}}
    end
  end

  # ============================================================================
  # Individual Facet Validation
  # ============================================================================

  defp validate_facet(value, type, {:length, expected}) do
    # QName and NOTATION don't support length facets per XSD spec §4.3.1
    if type in [:QName, :NOTATION] do
      :ok
    else
      actual = get_length(value, type)

      if actual == expected do
        :ok
      else
        {:error, {:facet_violation, :length, [expected: expected, got: actual]}}
      end
    end
  end

  defp validate_facet(value, type, {:minLength, min}) do
    # QName and NOTATION don't support length facets per XSD spec §4.3.1
    if type in [:QName, :NOTATION] do
      :ok
    else
      actual = get_length(value, type)

      if actual >= min do
        :ok
      else
        {:error, {:facet_violation, :minLength, [expected: min, got: actual]}}
      end
    end
  end

  defp validate_facet(value, type, {:maxLength, max}) do
    # QName and NOTATION don't support length facets per XSD spec §4.3.1
    if type in [:QName, :NOTATION] do
      :ok
    else
      actual = get_length(value, type)

      if actual <= max do
        :ok
      else
        {:error, {:facet_violation, :maxLength, [expected: max, got: actual]}}
      end
    end
  end

  defp validate_facet(value, _type, {:pattern, pattern}) do
    pcre_pattern = xsd_pattern_to_pcre(pattern)

    case Regex.compile("^#{pcre_pattern}$", "u") do
      {:ok, regex} ->
        if Regex.match?(regex, value) do
          :ok
        else
          {:error, {:facet_violation, :pattern, [expected: pattern, got: value]}}
        end

      {:error, _} ->
        # If pattern conversion fails, skip validation
        :ok
    end
  end

  defp validate_facet(value, _type, {:minInclusive, min_str}) do
    case compare_values(value, min_str) do
      :lt -> {:error, {:facet_violation, :minInclusive, [expected: ">= #{min_str}", got: value]}}
      _ -> :ok
    end
  end

  defp validate_facet(value, _type, {:maxInclusive, max_str}) do
    case compare_values(value, max_str) do
      :gt -> {:error, {:facet_violation, :maxInclusive, [expected: "<= #{max_str}", got: value]}}
      _ -> :ok
    end
  end

  defp validate_facet(value, _type, {:minExclusive, min_str}) do
    case compare_values(value, min_str) do
      :gt -> :ok
      _ -> {:error, {:facet_violation, :minExclusive, [expected: "> #{min_str}", got: value]}}
    end
  end

  defp validate_facet(value, _type, {:maxExclusive, max_str}) do
    case compare_values(value, max_str) do
      :lt -> :ok
      _ -> {:error, {:facet_violation, :maxExclusive, [expected: "< #{max_str}", got: value]}}
    end
  end

  defp validate_facet(value, _type, {:totalDigits, max_digits}) do
    digit_count = count_total_digits(value)

    if digit_count <= max_digits do
      :ok
    else
      {:error, {:facet_violation, :totalDigits, [expected: max_digits, got: digit_count]}}
    end
  end

  defp validate_facet(value, _type, {:fractionDigits, max_fraction}) do
    fraction_count = count_fraction_digits(value)

    if fraction_count <= max_fraction do
      :ok
    else
      {:error, {:facet_violation, :fractionDigits, [expected: max_fraction, got: fraction_count]}}
    end
  end

  defp validate_facet(value, _type, {:whiteSpace, mode}) do
    case mode do
      :preserve ->
        :ok

      :replace ->
        if String.contains?(value, ["\t", "\n", "\r"]) do
          {:error, {:facet_violation, :whiteSpace, [expected: :replace, got: value]}}
        else
          :ok
        end

      :collapse ->
        cond do
          String.contains?(value, ["\t", "\n", "\r"]) ->
            {:error, {:facet_violation, :whiteSpace, [expected: :collapse, got: value]}}

          String.starts_with?(value, " ") or String.ends_with?(value, " ") ->
            {:error, {:facet_violation, :whiteSpace, [expected: :collapse, got: value]}}

          String.contains?(value, "  ") ->
            {:error, {:facet_violation, :whiteSpace, [expected: :collapse, got: value]}}

          true ->
            :ok
        end
    end
  end

  defp validate_facet(_value, _type, _facet), do: :ok

  # ============================================================================
  # Length Calculation
  # ============================================================================

  defp get_length(value, type) do
    cond do
      type == :hexBinary ->
        div(String.length(value), 2)

      type == :base64Binary ->
        get_base64_byte_length(value)

      Hierarchy.list_type?(type) ->
        value |> String.split(~r/\s+/, trim: true) |> length()

      true ->
        String.length(value)
    end
  end

  defp get_base64_byte_length(value) do
    clean = String.replace(value, ~r/\s/, "")
    len = String.length(clean)

    padding =
      cond do
        String.ends_with?(clean, "==") -> 2
        String.ends_with?(clean, "=") -> 1
        true -> 0
      end

    div(len * 3, 4) - padding
  end

  # ============================================================================
  # Digit Counting
  # ============================================================================

  defp count_total_digits(value) do
    value
    |> String.replace(~r/[^0-9]/, "")
    |> String.replace(~r/^0+/, "")
    |> String.length()
  end

  defp count_fraction_digits(value) do
    case String.split(value, ".") do
      [_] -> 0
      [_, fraction] -> String.length(String.replace(fraction, ~r/0+$/, ""))
    end
  end

  # ============================================================================
  # Value Comparison
  # ============================================================================

  defp compare_values(a, b) when is_binary(a) and is_binary(b) do
    cond do
      String.starts_with?(a, "P") or String.starts_with?(a, "-P") ->
        compare_duration(a, b)

      String.starts_with?(a, "--") ->
        compare_strings(a, b)

      is_datetime_format?(a) ->
        compare_datetime(a, b)

      true ->
        compare_numeric(a, b)
    end
  rescue
    _ -> :eq
  end

  defp compare_numeric(a, b) do
    if Code.ensure_loaded?(Decimal) do
      # Use apply to avoid compile-time warning when Decimal is not available
      case {apply(Decimal, :parse, [a]), apply(Decimal, :parse, [b])} do
        {{a_dec, ""}, {b_dec, ""}} -> apply(Decimal, :compare, [a_dec, b_dec])
        {{a_dec, _}, {b_dec, _}} -> apply(Decimal, :compare, [a_dec, b_dec])
        _ -> compare_float(a, b)
      end
    else
      compare_float(a, b)
    end
  end

  defp compare_float(a, b) do
    case {Float.parse(a), Float.parse(b)} do
      {{a_num, _}, {b_num, _}} ->
        cond do
          a_num < b_num -> :lt
          a_num > b_num -> :gt
          true -> :eq
        end

      _ ->
        :eq
    end
  end

  defp compare_duration(a, b) do
    a_seconds = duration_to_seconds(a)
    b_seconds = duration_to_seconds(b)

    cond do
      a_seconds < b_seconds -> :lt
      a_seconds > b_seconds -> :gt
      true -> :eq
    end
  rescue
    _ -> :eq
  end

  defp duration_to_seconds(duration) do
    negative = String.starts_with?(duration, "-")
    duration = duration |> String.trim_leading("-") |> String.trim_leading("P")

    {date_part, time_part} =
      case String.split(duration, "T", parts: 2) do
        [date, time] -> {date, time}
        [date] -> {date, ""}
      end

    years = parse_duration_component(date_part, "Y")
    months = parse_duration_component(date_part, "M")
    days = parse_duration_component(date_part, "D")
    hours = parse_duration_component(time_part, "H")
    minutes = parse_duration_component(time_part, "M")
    seconds = parse_duration_component_decimal(time_part, "S")

    total =
      years * 365.25 * 24 * 60 * 60 +
        months * 30.4375 * 24 * 60 * 60 +
        days * 24 * 60 * 60 +
        hours * 60 * 60 +
        minutes * 60 +
        seconds

    if negative, do: -total, else: total
  end

  defp parse_duration_component(str, suffix) do
    case Regex.run(~r/(\d+)#{suffix}/, str) do
      [_, num] -> String.to_integer(num)
      _ -> 0
    end
  end

  defp parse_duration_component_decimal(str, suffix) do
    case Regex.run(~r/([\d.]+)#{suffix}/, str) do
      [_, num] ->
        case Float.parse(num) do
          {val, _} -> val
          :error -> 0.0
        end

      _ ->
        0.0
    end
  end

  defp compare_datetime(a, b) do
    a_norm = normalize_datetime(a)
    b_norm = normalize_datetime(b)
    compare_strings(a_norm, b_norm)
  end

  defp compare_strings(a, b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end

  defp is_datetime_format?(s) do
    String.contains?(s, "T") or
      Regex.match?(~r/^-?\d{4,}-\d{2}-\d{2}/, s) or
      Regex.match?(~r/^\d{2}:\d{2}:\d{2}/, s) or
      Regex.match?(~r/^-?\d{4}-\d{2}(Z|[+-]\d{2}:\d{2})?$/, s) or
      Regex.match?(~r/^-?\d{4}(Z|[+-]\d{2}:\d{2})$/, s)
  end

  defp normalize_datetime(dt) do
    dt
    |> String.replace(~r/Z$/, "")
    |> String.replace(~r/[+-]\d{2}:\d{2}$/, "")
  end

  # ============================================================================
  # XSD Pattern Conversion
  # ============================================================================

  # XSD multi-character escape inner ranges (without surrounding [])
  @xsd_i_inner "_:A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8-\\xFF"
  @xsd_c_inner "\\-._:A-Za-z0-9\\xB7\\xC0-\\xD6\\xD8-\\xF6\\xF8-\\xFF"

  # XSD \d = all Unicode decimal digits (\p{Nd}), NOT just ASCII 0-9
  # XSD \w = [#x0000-#xFFFF]-[\p{P}\p{Z}\p{C}] = letters, marks, numbers, symbols
  # XSD \s = [#x20\t\n\r] (narrower than PCRE's \s which also includes \f and \v)
  @xsd_d_inner "\\p{Nd}"
  @xsd_w_inner "\\p{L}\\p{M}\\p{N}\\p{S}"
  @xsd_s_inner "\\x20\\x09\\x0A\\x0D"

  # XSD Unicode block name -> codepoint range (Unicode 3.1 blocks used by XSD 1.0)
  @xsd_unicode_blocks %{
    "BasicLatin" => {0x0000, 0x007F},
    "Latin-1Supplement" => {0x0080, 0x00FF},
    "LatinExtended-A" => {0x0100, 0x017F},
    "LatinExtended-B" => {0x0180, 0x024F},
    "IPAExtensions" => {0x0250, 0x02AF},
    "SpacingModifierLetters" => {0x02B0, 0x02FF},
    "CombiningDiacriticalMarks" => {0x0300, 0x036F},
    "Greek" => {0x0370, 0x03FF},
    "GreekExtended" => {0x1F00, 0x1FFF},
    "Cyrillic" => {0x0400, 0x04FF},
    "Armenian" => {0x0530, 0x058F},
    "Hebrew" => {0x0590, 0x05FF},
    "Arabic" => {0x0600, 0x06FF},
    "Syriac" => {0x0700, 0x074F},
    "Thaana" => {0x0780, 0x07BF},
    "Devanagari" => {0x0900, 0x097F},
    "Bengali" => {0x0980, 0x09FF},
    "Gurmukhi" => {0x0A00, 0x0A7F},
    "Gujarati" => {0x0A80, 0x0AFF},
    "Oriya" => {0x0B00, 0x0B7F},
    "Tamil" => {0x0B80, 0x0BFF},
    "Telugu" => {0x0C00, 0x0C7F},
    "Kannada" => {0x0C80, 0x0CFF},
    "Malayalam" => {0x0D00, 0x0D7F},
    "Sinhala" => {0x0D80, 0x0DFF},
    "Thai" => {0x0E00, 0x0E7F},
    "Lao" => {0x0E80, 0x0EFF},
    "Tibetan" => {0x0F00, 0x0FFF},
    "Myanmar" => {0x1000, 0x109F},
    "Georgian" => {0x10A0, 0x10FF},
    "HangulJamo" => {0x1100, 0x11FF},
    "Ethiopic" => {0x1200, 0x137F},
    "Cherokee" => {0x13A0, 0x13FF},
    "UnifiedCanadianAboriginalSyllabics" => {0x1400, 0x167F},
    "Ogham" => {0x1680, 0x169F},
    "Runic" => {0x16A0, 0x16FF},
    "Khmer" => {0x1780, 0x17FF},
    "Mongolian" => {0x1800, 0x18AF},
    "LatinExtendedAdditional" => {0x1E00, 0x1EFF},
    "GeneralPunctuation" => {0x2000, 0x206F},
    "SuperscriptsandSubscripts" => {0x2070, 0x209F},
    "CurrencySymbols" => {0x20A0, 0x20CF},
    "CombiningMarksforSymbols" => {0x20D0, 0x20FF},
    "LetterlikeSymbols" => {0x2100, 0x214F},
    "NumberForms" => {0x2150, 0x218F},
    "Arrows" => {0x2190, 0x21FF},
    "MathematicalOperators" => {0x2200, 0x22FF},
    "MiscellaneousTechnical" => {0x2300, 0x23FF},
    "ControlPictures" => {0x2400, 0x243F},
    "OpticalCharacterRecognition" => {0x2440, 0x245F},
    "EnclosedAlphanumerics" => {0x2460, 0x24FF},
    "BoxDrawing" => {0x2500, 0x257F},
    "BlockElements" => {0x2580, 0x259F},
    "GeometricShapes" => {0x25A0, 0x25FF},
    "MiscellaneousSymbols" => {0x2600, 0x26FF},
    "Dingbats" => {0x2700, 0x27BF},
    "BraillePatterns" => {0x2800, 0x28FF},
    "CJKRadicalsSupplement" => {0x2E80, 0x2EFF},
    "KangxiRadicals" => {0x2F00, 0x2FDF},
    "IdeographicDescriptionCharacters" => {0x2FF0, 0x2FFF},
    "CJKSymbolsandPunctuation" => {0x3000, 0x303F},
    "Hiragana" => {0x3040, 0x309F},
    "Katakana" => {0x30A0, 0x30FF},
    "Bopomofo" => {0x3100, 0x312F},
    "HangulCompatibilityJamo" => {0x3130, 0x318F},
    "Kanbun" => {0x3190, 0x319F},
    "BopomofoExtended" => {0x31A0, 0x31BF},
    "EnclosedCJKLettersandMonths" => {0x3200, 0x32FF},
    "CJKCompatibility" => {0x3300, 0x33FF},
    "CJKUnifiedIdeographsExtensionA" => {0x3400, 0x4DBF},
    "CJKUnifiedIdeographs" => {0x4E00, 0x9FFF},
    "YiSyllables" => {0xA000, 0xA48F},
    "YiRadicals" => {0xA490, 0xA4CF},
    "HangulSyllables" => {0xAC00, 0xD7AF},
    "HighSurrogates" => {0xD800, 0xDB7F},
    "LowSurrogates" => {0xDC00, 0xDFFF},
    "PrivateUse" => {0xE000, 0xF8FF},
    "CJKCompatibilityIdeographs" => {0xF900, 0xFAFF},
    "AlphabeticPresentationForms" => {0xFB00, 0xFB4F},
    "HalfwidthandFullwidthForms" => {0xFF00, 0xFFEF},
    "Specials" => {0xFFF0, 0xFFFD},
    "SmallFormVariants" => {0xFE50, 0xFE6F},
    "CombiningHalfMarks" => {0xFE20, 0xFE2F},
    "CJKCompatibilityForms" => {0xFE30, 0xFE4F},
    "OldItalic" => {0x10300, 0x1032F},
    "Gothic" => {0x10330, 0x1034F},
    "Deseret" => {0x10400, 0x1044F},
    "ByzantineMusicalSymbols" => {0x1D000, 0x1D0FF},
    "MusicalSymbols" => {0x1D100, 0x1D1FF},
    "MathematicalAlphanumericSymbols" => {0x1D400, 0x1D7FF},
    "CJKCompatibilityIdeographsSupplement" => {0x2F800, 0x2FA1F},
    "Tags" => {0xE0000, 0xE007F}
  }

  defp xsd_pattern_to_pcre(pattern) do
    pattern
    |> translate_char_class_subtraction()
    |> translate_xsd_char_classes()
    |> translate_xsd_standalone_escapes()
    |> translate_standalone_unicode_blocks()
  end

  # XSD character class subtraction: [BASE-[SUB]] → (?:(?![SUB])[BASE])
  # Must run before other translations since they can't handle nested brackets.
  defp translate_char_class_subtraction(pattern), do: do_translate_ccs(pattern, "")

  defp do_translate_ccs("", acc), do: acc

  defp do_translate_ccs(<<?\\, c, rest::binary>>, acc) do
    do_translate_ccs(rest, <<acc::binary, ?\\, c>>)
  end

  defp do_translate_ccs(<<?[, rest::binary>>, acc) do
    {negated, rest} =
      case rest do
        <<?^, r::binary>> -> {true, r}
        r -> {false, r}
      end

    case scan_ccs_body(rest, "") do
      {:subtraction, base, sub_str, rest2} ->
        processed_sub = translate_char_class_subtraction(sub_str)
        neg = if negated, do: "^", else: ""
        replacement = "(?:(?!#{processed_sub})[#{neg}#{base}])"
        do_translate_ccs(rest2, acc <> replacement)

      {:simple, body, rest2} ->
        neg = if negated, do: "^", else: ""
        do_translate_ccs(rest2, acc <> "[" <> neg <> body <> "]")
    end
  end

  defp do_translate_ccs(<<c::utf8, rest::binary>>, acc) do
    do_translate_ccs(rest, <<acc::binary, c::utf8>>)
  end

  # Scan character class body looking for subtraction (-[...]) or closing ]
  defp scan_ccs_body(<<?], rest::binary>>, acc), do: {:simple, acc, rest}

  defp scan_ccs_body(<<?-, ?[, rest::binary>>, acc) do
    case scan_ccs_nested(rest, "", 1) do
      {:ok, inner, <<?], rest2::binary>>} ->
        {:subtraction, acc, "[" <> inner <> "]", rest2}

      {:ok, inner, rest2} ->
        scan_ccs_body(rest2, acc <> "-[" <> inner <> "]")

      :error ->
        scan_ccs_body(rest, acc <> "-[")
    end
  end

  defp scan_ccs_body(<<?\\, c, rest::binary>>, acc) do
    scan_ccs_body(rest, <<acc::binary, ?\\, c>>)
  end

  defp scan_ccs_body(<<c::utf8, rest::binary>>, acc) do
    scan_ccs_body(rest, <<acc::binary, c::utf8>>)
  end

  defp scan_ccs_body("", acc), do: {:simple, acc, ""}

  # Scan nested brackets tracking depth to find matching ]
  defp scan_ccs_nested(<<?], rest::binary>>, acc, 1), do: {:ok, acc, rest}

  defp scan_ccs_nested(<<?], rest::binary>>, acc, depth) do
    scan_ccs_nested(rest, acc <> "]", depth - 1)
  end

  defp scan_ccs_nested(<<?[, rest::binary>>, acc, depth) do
    scan_ccs_nested(rest, acc <> "[", depth + 1)
  end

  defp scan_ccs_nested(<<?\\, c, rest::binary>>, acc, depth) do
    scan_ccs_nested(rest, <<acc::binary, ?\\, c>>, depth)
  end

  defp scan_ccs_nested(<<c::utf8, rest::binary>>, acc, depth) do
    scan_ccs_nested(rest, <<acc::binary, c::utf8>>, depth)
  end

  defp scan_ccs_nested("", _acc, _depth), do: :error

  # Convert a block name to a PCRE hex range string (without brackets)
  defp block_to_range(block_name) do
    case Map.get(@xsd_unicode_blocks, block_name) do
      {start, stop} ->
        {:ok, "\\x{#{Integer.to_string(start, 16)}}-\\x{#{Integer.to_string(stop, 16)}}"}

      nil ->
        :error
    end
  end

  # Convert \P{IsXxx} (negative block) to complement ranges for use inside char classes
  defp block_to_complement_range(block_name) do
    case Map.get(@xsd_unicode_blocks, block_name) do
      {start, stop} ->
        parts =
          (if start > 0, do: ["\\x{0}-\\x{#{Integer.to_string(start - 1, 16)}}"], else: []) ++
            if stop < 0x10FFFF,
              do: ["\\x{#{Integer.to_string(stop + 1, 16)}}-\\x{10FFFF}"],
              else: []

        {:ok, Enum.join(parts)}

      nil ->
        :error
    end
  end

  # Translate standalone \p{IsXxx} and \P{IsXxx} (outside character classes)
  defp translate_standalone_unicode_blocks(pattern) do
    Regex.replace(~r/\\([pP])\{Is([A-Za-z-]+)\}/, pattern, fn _full, type, block_name ->
      case block_to_range(block_name) do
        {:ok, range} ->
          if type == "p", do: "[#{range}]", else: "[^#{range}]"

        :error ->
          "\\#{type}{Is#{block_name}}"
      end
    end)
  end

  # Process character classes [...] to expand XSD-specific escapes inside them.
  # Translates \i, \I, \c, \C (XSD-only), \d, \D, \w, \W, \s (XSD Unicode semantics),
  # and \p{IsBlockName}/\P{IsBlockName} (Unicode blocks).
  defp translate_xsd_char_classes(pattern) do
    Regex.replace(~r/\[([^\]]*)\]/, pattern, fn _full, inner ->
      translated =
        inner
        |> String.replace("\\i", @xsd_i_inner)
        |> String.replace("\\I", "^" <> @xsd_i_inner)
        |> String.replace("\\c", @xsd_c_inner)
        |> String.replace("\\C", "^" <> @xsd_c_inner)
        |> String.replace("\\d", @xsd_d_inner)
        |> String.replace("\\D", "\\P{Nd}")
        |> String.replace("\\w", @xsd_w_inner)
        |> String.replace("\\W", "\\p{P}\\p{Z}\\p{C}")
        |> String.replace("\\s", @xsd_s_inner)
        |> String.replace("\\S", "\\p{L}\\p{M}\\p{N}\\p{S}\\p{P}\\p{C}")
        |> translate_blocks_in_char_class()

      "[#{translated}]"
    end)
  end

  # Handle \p{IsXxx} and \P{IsXxx} inside character classes (no wrapping brackets)
  defp translate_blocks_in_char_class(inner) do
    Regex.replace(~r/\\([pP])\{Is([A-Za-z-]+)\}/, inner, fn _full, type, block_name ->
      if type == "p" do
        case block_to_range(block_name) do
          {:ok, range} -> range
          :error -> "\\p{Is#{block_name}}"
        end
      else
        case block_to_complement_range(block_name) do
          {:ok, range} -> range
          :error -> "\\P{Is#{block_name}}"
        end
      end
    end)
  end

  # Replace standalone XSD-specific escapes (outside character classes) with bracketed ranges.
  defp translate_xsd_standalone_escapes(pattern) do
    pattern
    |> String.replace("\\i", "[#{@xsd_i_inner}]")
    |> String.replace("\\I", "[^#{@xsd_i_inner}]")
    |> String.replace("\\c", "[#{@xsd_c_inner}]")
    |> String.replace("\\C", "[^#{@xsd_c_inner}]")
    |> String.replace("\\d", "\\p{Nd}")
    |> String.replace("\\D", "\\P{Nd}")
    |> String.replace("\\w", "[#{@xsd_w_inner}]")
    |> String.replace("\\W", "[^#{@xsd_w_inner}]")
    |> String.replace("\\s", "[#{@xsd_s_inner}]")
    |> String.replace("\\S", "[^#{@xsd_s_inner}]")
  end
end
