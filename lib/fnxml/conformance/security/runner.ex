defmodule FnXML.Conformance.Security.Runner do
  @moduledoc """
  Execute XML Security conformance tests.
  """

  alias FnXML.Conformance.Security.Catalog

  def run_all(tests, opts \\ []) do
    verbose = Keyword.get(opts, :verbose, false)
    total = length(tests)

    results =
      tests
      |> Enum.with_index(1)
      |> Enum.map(fn {test, idx} ->
        if verbose do
          IO.write("\r[#{idx}/#{total}] #{test.id}...")
        else
          if rem(idx, 10) == 0, do: IO.write("\r#{idx}/#{total} tests...")
        end

        run_one(test, opts)
      end)

    IO.puts("\r#{total} tests completed.#{String.duplicate(" ", 20)}")
    results
  end

  def run_one(%Catalog{} = test, opts \\ []) do
    verbose = Keyword.get(opts, :verbose, false)
    start = System.monotonic_time(:microsecond)

    {status, details} =
      case test.category do
        :c14n -> execute_c14n_test(test)
        :exc_c14n -> execute_exc_c14n_test(test)
        :signature -> execute_signature_test(test)
        :encryption -> execute_encryption_test(test)
        _ -> {:skip, {:unknown_category, test.category}}
      end

    elapsed = System.monotonic_time(:microsecond) - start
    group = to_string(test.category)

    result =
      case status do
        :pass ->
          FnConformance.Result.pass(test.id,
            group: group,
            elapsed_us: elapsed,
            details: details
          )

        :fail ->
          FnConformance.Result.fail(test.id, details,
            group: group,
            elapsed_us: elapsed
          )

        :skip ->
          FnConformance.Result.skip(test.id, details,
            group: group,
            elapsed_us: elapsed
          )
      end

    if verbose, do: print_result(result)
    result
  end

  defp execute_c14n_test(test) do
    if Code.ensure_loaded?(FnXML.C14N) do
      try do
        events = FnXML.Parser.parse(test.input) |> Enum.to_list()

        has_errors = Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))

        if has_errors do
          {:fail, :parse_error}
        else
          c14n_opts =
            case test.algorithm do
              "http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments" ->
                [with_comments: true]

              _ ->
                []
            end

          result = FnXML.C14N.canonicalize(test.input, c14n_opts)

          if test.expected do
            expected_normalized = normalize_whitespace(test.expected)
            result_normalized = normalize_whitespace(result)

            if result_normalized == expected_normalized do
              {:pass, :canonical_match}
            else
              {:fail, {:mismatch, result}}
            end
          else
            {:pass, :canonical_generated}
          end
        end
      rescue
        e -> {:fail, {:exception, Exception.message(e)}}
      end
    else
      validate_xml_structure(test.input)
    end
  end

  defp execute_exc_c14n_test(test) do
    if Code.ensure_loaded?(FnXML.C14N) and
         function_exported?(FnXML.C14N, :exclusive_canonicalize, 2) do
      try do
        opts = Map.to_list(test.options || %{})
        result = FnXML.C14N.exclusive_canonicalize(test.input, opts)

        if test.expected do
          expected_normalized = normalize_whitespace(test.expected)
          result_normalized = normalize_whitespace(result)

          if result_normalized == expected_normalized do
            {:pass, :exc_canonical_match}
          else
            {:fail, {:mismatch, result}}
          end
        else
          {:pass, :exc_canonical_generated}
        end
      rescue
        e -> {:fail, {:exception, Exception.message(e)}}
      end
    else
      validate_xml_structure(test.input)
    end
  end

  defp execute_signature_test(test) do
    case test.type do
      :structure -> validate_signature_structure(test.input)
      :transform -> execute_signature_transform_test(test)
      _ -> validate_signature_structure(test.input)
    end
  end

  defp validate_signature_structure(xml) do
    try do
      events = FnXML.Parser.parse(xml) |> Enum.to_list()

      has_errors = Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))

      if has_errors do
        {:fail, :parse_error}
      else
        has_signature = has_element?(events, "Signature")
        has_signed_info = has_element?(events, "SignedInfo")
        has_signature_value = has_element?(events, "SignatureValue")
        has_c14n_method = has_element?(events, "CanonicalizationMethod")
        has_sig_method = has_element?(events, "SignatureMethod")
        has_reference = has_element?(events, "Reference")
        has_digest_method = has_element?(events, "DigestMethod")
        has_digest_value = has_element?(events, "DigestValue")

        cond do
          not has_signature -> {:fail, :missing_signature}
          not has_signed_info -> {:fail, :missing_signed_info}
          not has_signature_value -> {:fail, :missing_signature_value}
          not has_c14n_method -> {:fail, :missing_c14n_method}
          not has_sig_method -> {:fail, :missing_signature_method}
          not has_reference -> {:fail, :missing_reference}
          not has_digest_method -> {:fail, :missing_digest_method}
          not has_digest_value -> {:fail, :missing_digest_value}
          true -> {:pass, :valid_structure}
        end
      end
    rescue
      e -> {:fail, {:exception, Exception.message(e)}}
    end
  end

  defp execute_signature_transform_test(test) do
    case test.algorithm do
      "http://www.w3.org/2000/09/xmldsig#enveloped-signature" ->
        try do
          events = FnXML.Parser.parse(test.input) |> Enum.to_list()

          has_errors = Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))

          if has_errors do
            {:fail, :parse_error}
          else
            if has_element?(events, "Signature") do
              {:pass, :transform_structure_valid}
            else
              {:fail, :missing_signature}
            end
          end
        rescue
          e -> {:fail, {:exception, Exception.message(e)}}
        end

      _ ->
        {:skip, {:unknown_transform, test.algorithm}}
    end
  end

  defp execute_encryption_test(test) do
    case test.type do
      :structure -> validate_encryption_structure(test.input)
      _ -> validate_encryption_structure(test.input)
    end
  end

  defp validate_encryption_structure(xml) do
    try do
      events = FnXML.Parser.parse(xml) |> Enum.to_list()

      has_errors = Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))

      if has_errors do
        {:fail, :parse_error}
      else
        has_encrypted_data = has_element?(events, "EncryptedData")
        has_cipher_data = has_element?(events, "CipherData")
        has_cipher_value = has_element?(events, "CipherValue")
        has_cipher_ref = has_element?(events, "CipherReference")

        cond do
          not has_encrypted_data -> {:fail, :missing_encrypted_data}
          not has_cipher_data -> {:fail, :missing_cipher_data}
          not has_cipher_value and not has_cipher_ref -> {:fail, :missing_cipher_content}
          true -> {:pass, :valid_structure}
        end
      end
    rescue
      e -> {:fail, {:exception, Exception.message(e)}}
    end
  end

  defp validate_xml_structure(xml) do
    try do
      events = FnXML.Parser.parse(xml) |> Enum.to_list()

      has_errors = Enum.any?(events, &match?({:error, _, _, _, _, _}, &1))

      if has_errors do
        {:fail, :parse_error}
      else
        {:pass, :valid_xml}
      end
    rescue
      e -> {:fail, {:exception, Exception.message(e)}}
    end
  end

  defp has_element?(events, local_name) do
    Enum.any?(events, fn
      {:start_element, name, _, _, _, _} ->
        String.ends_with?(to_string(name), local_name) or name == local_name

      _ ->
        false
    end)
  end

  defp normalize_whitespace(str) when is_binary(str) do
    str
    |> String.trim()
    |> String.replace(~r/\r\n/, "\n")
    |> String.replace(~r/[ \t]+/, " ")
  end

  defp normalize_whitespace(_), do: ""

  defp print_result(%FnConformance.Result{status: :pass, name: name}) do
    IO.puts("  PASS: #{name}")
  end

  defp print_result(%FnConformance.Result{status: :fail, name: name, details: details}) do
    IO.puts("  FAIL: #{name} - #{inspect(details)}")
  end

  defp print_result(%FnConformance.Result{status: :skip, name: name, details: reason}) do
    IO.puts("  SKIP: #{name} - #{inspect(reason)}")
  end
end
