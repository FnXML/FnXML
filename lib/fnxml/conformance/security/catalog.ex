defmodule FnXML.Conformance.Security.Catalog do
  @moduledoc """
  Catalog of XML Security conformance tests with built-in test vectors.
  """

  defstruct [
    :id,
    :category,
    :type,
    :description,
    :spec_ref,
    :input,
    :expected,
    :algorithm,
    :key_info,
    :options
  ]

  def load(suite_path, opts \\ []) do
    category_filter = Keyword.get(opts, :category)
    filter = Keyword.get(opts, :filter)
    limit = Keyword.get(opts, :limit)

    catalog_path = Path.join(suite_path, "catalog.json")

    tests =
      if File.exists?(catalog_path) do
        load_from_catalog(catalog_path, suite_path)
      else
        builtin_tests()
      end
      |> maybe_filter_category(category_filter)
      |> maybe_filter(filter)
      |> maybe_limit(limit)

    tests
  end

  def list_categories(suite_path, _opts \\ []) do
    tests = load(suite_path, [])

    tests
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, cat_tests} ->
      %{
        category: category,
        count: length(cat_tests),
        types: cat_tests |> Enum.map(& &1.type) |> Enum.uniq()
      }
    end)
    |> Enum.sort_by(& &1.category)
  end

  def generate_builtin_tests(suite_path) do
    tests = builtin_tests()

    catalog_data =
      Enum.map(tests, fn test ->
        %{
          id: test.id,
          category: test.category,
          type: test.type,
          description: test.description,
          spec_ref: test.spec_ref,
          algorithm: test.algorithm
        }
      end)

    catalog_path = Path.join(suite_path, "catalog.json")
    File.write!(catalog_path, Jason.encode!(catalog_data, pretty: true))

    Enum.each(tests, fn test ->
      test_dir = Path.join(suite_path, to_string(test.category))
      File.mkdir_p!(test_dir)

      if test.input do
        input_path = Path.join(test_dir, "#{test.id}_input.xml")
        File.write!(input_path, test.input)
      end

      if test.expected do
        expected_path = Path.join(test_dir, "#{test.id}_expected.xml")
        File.write!(expected_path, test.expected)
      end
    end)
  end

  defp load_from_catalog(catalog_path, suite_path) do
    catalog_path
    |> File.read!()
    |> Jason.decode!()
    |> Enum.map(fn entry ->
      category = String.to_atom(entry["category"])
      test_dir = Path.join(suite_path, entry["category"])

      input = read_test_file(test_dir, "#{entry["id"]}_input.xml")
      expected = read_test_file(test_dir, "#{entry["id"]}_expected.xml")

      %__MODULE__{
        id: entry["id"],
        category: category,
        type: String.to_atom(entry["type"]),
        description: entry["description"],
        spec_ref: entry["spec_ref"],
        algorithm: entry["algorithm"],
        input: input,
        expected: expected
      }
    end)
  end

  defp read_test_file(dir, filename) do
    path = Path.join(dir, filename)
    if File.exists?(path), do: File.read!(path), else: nil
  end

  defp builtin_tests do
    c14n_tests() ++ exc_c14n_tests() ++ signature_tests() ++ encryption_tests()
  end

  defp c14n_tests do
    [
      %__MODULE__{
        id: "c14n-001",
        category: :c14n,
        type: :valid,
        description: "Basic canonicalization: whitespace normalization and empty element expansion",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<?xml version=\"1.0\"?>\n\n<doc>\n   <e1   />\n   <e2   ></e2>\n   <e3   name = \"elem3\"   id=\"elem3\"   />\n</doc>\n",
        expected: "<doc>\n   <e1></e1>\n   <e2></e2>\n   <e3 id=\"elem3\" name=\"elem3\"></e3>\n</doc>\n"
      },
      %__MODULE__{
        id: "c14n-002",
        category: :c14n,
        type: :valid,
        description: "Attribute value normalization and sorting",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc z=\"z\" a=\"a\" m=\"m\">\n  <elem b=\"2\" a=\"1\"/>\n</doc>\n",
        expected: "<doc a=\"a\" m=\"m\" z=\"z\">\n  <elem a=\"1\" b=\"2\"></elem>\n</doc>\n"
      },
      %__MODULE__{
        id: "c14n-003",
        category: :c14n,
        type: :valid,
        description: "Namespace declaration handling and sorting",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc xmlns:b=\"http://b\" xmlns:a=\"http://a\" xmlns=\"http://default\">\n  <elem/>\n</doc>\n",
        expected: "<doc xmlns=\"http://default\" xmlns:a=\"http://a\" xmlns:b=\"http://b\">\n  <elem></elem>\n</doc>\n"
      },
      %__MODULE__{
        id: "c14n-004",
        category: :c14n,
        type: :valid,
        description: "Character and entity reference expansion",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc>&#x20;&#x9;&#xD;&#xA;</doc>\n",
        expected: "<doc> \t\r\n</doc>\n"
      },
      %__MODULE__{
        id: "c14n-005",
        category: :c14n,
        type: :valid,
        description: "CDATA section replacement with character data",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc><![CDATA[<hello>&world;]]></doc>\n",
        expected: "<doc>&lt;hello&gt;&amp;world;</doc>\n"
      },
      %__MODULE__{
        id: "c14n-006",
        category: :c14n,
        type: :valid,
        description: "Comments removed in default canonicalization",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc><!-- comment -->content</doc>\n",
        expected: "<doc>content</doc>\n"
      },
      %__MODULE__{
        id: "c14n-007",
        category: :c14n,
        type: :valid,
        description: "Comments preserved in WithComments variant",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments",
        input: "<doc><!-- comment -->content</doc>\n",
        expected: "<doc><!-- comment -->content</doc>\n"
      },
      %__MODULE__{
        id: "c14n-008",
        category: :c14n,
        type: :valid,
        description: "Processing instruction handling",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<?target data?>\n<doc/>\n",
        expected: "<?target data?>\n<doc></doc>"
      },
      %__MODULE__{
        id: "c14n-009",
        category: :c14n,
        type: :valid,
        description: "Special character escaping in element content",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc>&lt;&gt;&amp;</doc>\n",
        expected: "<doc>&lt;&gt;&amp;</doc>\n"
      },
      %__MODULE__{
        id: "c14n-010",
        category: :c14n,
        type: :valid,
        description: "Special character escaping in attributes",
        spec_ref: "https://www.w3.org/TR/xml-c14n Section 3.1",
        algorithm: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315",
        input: "<doc attr=\"&lt;&gt;&quot;&amp;\"/>\n",
        expected: "<doc attr=\"&lt;&gt;&quot;&amp;\"></doc>\n"
      }
    ]
  end

  defp exc_c14n_tests do
    [
      %__MODULE__{
        id: "exc-c14n-001",
        category: :exc_c14n,
        type: :valid,
        description: "Only visibly utilized namespaces are included",
        spec_ref: "https://www.w3.org/TR/xml-exc-c14n/ Section 4",
        algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#",
        input: "<doc xmlns=\"http://default\" xmlns:unused=\"http://unused\">\n  <elem attr=\"value\"/>\n</doc>\n",
        expected: "<elem xmlns=\"http://default\" attr=\"value\"></elem>\n",
        options: %{subset: "//elem"}
      },
      %__MODULE__{
        id: "exc-c14n-002",
        category: :exc_c14n,
        type: :valid,
        description: "Prefixed element namespace handling",
        spec_ref: "https://www.w3.org/TR/xml-exc-c14n/ Section 4",
        algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#",
        input: "<doc xmlns:a=\"http://a\" xmlns:b=\"http://b\">\n  <a:elem a:attr=\"value\"/>\n</doc>\n",
        expected: "<a:elem xmlns:a=\"http://a\" a:attr=\"value\"></a:elem>\n",
        options: %{subset: "//a:elem"}
      },
      %__MODULE__{
        id: "exc-c14n-003",
        category: :exc_c14n,
        type: :valid,
        description: "InclusiveNamespaces PrefixList forces namespace inclusion",
        spec_ref: "https://www.w3.org/TR/xml-exc-c14n/ Section 4",
        algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#",
        input: "<doc xmlns:include=\"http://include\" xmlns:exclude=\"http://exclude\">\n  <elem/>\n</doc>\n",
        expected: "<elem xmlns:include=\"http://include\"></elem>\n",
        options: %{subset: "//elem", inclusive_prefixes: ["include"]}
      }
    ]
  end

  defp signature_tests do
    [
      %__MODULE__{
        id: "sig-001",
        category: :signature,
        type: :structure,
        description: "Enveloped signature element structure validation",
        spec_ref: "https://www.w3.org/TR/xmldsig-core/ Section 4",
        algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
        input: """
        <Document Id="doc1">
          <Data>Test content</Data>
          <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <ds:SignedInfo>
              <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
              <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
              <ds:Reference URI="">
                <ds:Transforms>
                  <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
                </ds:Transforms>
                <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                <ds:DigestValue>placeholder</ds:DigestValue>
              </ds:Reference>
            </ds:SignedInfo>
            <ds:SignatureValue>placeholder</ds:SignatureValue>
          </ds:Signature>
        </Document>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "sig-002",
        category: :signature,
        type: :structure,
        description: "Detached signature element structure validation",
        spec_ref: "https://www.w3.org/TR/xmldsig-core/ Section 4",
        algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
        input: """
        <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
            <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
            <ds:Reference URI="http://example.org/data.txt">
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue>placeholder</ds:DigestValue>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue>placeholder</ds:SignatureValue>
        </ds:Signature>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "sig-003",
        category: :signature,
        type: :structure,
        description: "Signature with multiple Reference elements",
        spec_ref: "https://www.w3.org/TR/xmldsig-core/ Section 4",
        algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
        input: """
        <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
            <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
            <ds:Reference URI="#part1">
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue>digest1</ds:DigestValue>
            </ds:Reference>
            <ds:Reference URI="#part2">
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue>digest2</ds:DigestValue>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue>signature</ds:SignatureValue>
        </ds:Signature>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "sig-004",
        category: :signature,
        type: :structure,
        description: "Signature with X509Data KeyInfo",
        spec_ref: "https://www.w3.org/TR/xmldsig-core/ Section 4.4",
        algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
        input: """
        <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
            <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
            <ds:Reference URI="">
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue>digest</ds:DigestValue>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue>signature</ds:SignatureValue>
          <ds:KeyInfo>
            <ds:X509Data>
              <ds:X509Certificate>MIIBxTCCAW...</ds:X509Certificate>
            </ds:X509Data>
          </ds:KeyInfo>
        </ds:Signature>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "sig-005",
        category: :signature,
        type: :transform,
        description: "Enveloped signature transform removes Signature element",
        spec_ref: "https://www.w3.org/TR/xmldsig-core/ Section 6.6.4",
        algorithm: "http://www.w3.org/2000/09/xmldsig#enveloped-signature",
        input: """
        <Document>
          <Data>Content</Data>
          <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <ds:SignedInfo>
              <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
              <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
              <ds:Reference URI="">
                <ds:Transforms>
                  <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
                </ds:Transforms>
                <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                <ds:DigestValue>digest</ds:DigestValue>
              </ds:Reference>
            </ds:SignedInfo>
            <ds:SignatureValue>sig</ds:SignatureValue>
          </ds:Signature>
        </Document>
        """,
        expected: "<Document>\n  <Data>Content</Data>\n</Document>\n"
      }
    ]
  end

  defp encryption_tests do
    [
      %__MODULE__{
        id: "enc-001",
        category: :encryption,
        type: :structure,
        description: "EncryptedData element structure validation (Element type)",
        spec_ref: "https://www.w3.org/TR/xmlenc-core/ Section 3",
        algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
        input: """
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                           Type="http://www.w3.org/2001/04/xmlenc#Element">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
          <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <ds:KeyName>SharedKey</ds:KeyName>
          </ds:KeyInfo>
          <xenc:CipherData>
            <xenc:CipherValue>encrypted-content-base64</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedData>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "enc-002",
        category: :encryption,
        type: :structure,
        description: "EncryptedData element structure validation (Content type)",
        spec_ref: "https://www.w3.org/TR/xmlenc-core/ Section 3",
        algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
        input: """
        <Wrapper>
          <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                             Type="http://www.w3.org/2001/04/xmlenc#Content">
            <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
            <xenc:CipherData>
              <xenc:CipherValue>encrypted-content-base64</xenc:CipherValue>
            </xenc:CipherData>
          </xenc:EncryptedData>
        </Wrapper>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "enc-003",
        category: :encryption,
        type: :structure,
        description: "EncryptedKey element structure validation",
        spec_ref: "https://www.w3.org/TR/xmlenc-core/ Section 3.5",
        algorithm: "http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p",
        input: """
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                           xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
          <ds:KeyInfo>
            <xenc:EncryptedKey>
              <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p"/>
              <ds:KeyInfo>
                <ds:KeyName>RecipientPublicKey</ds:KeyName>
              </ds:KeyInfo>
              <xenc:CipherData>
                <xenc:CipherValue>encrypted-dek-base64</xenc:CipherValue>
              </xenc:CipherData>
              <xenc:ReferenceList>
                <xenc:DataReference URI="#encrypted-data"/>
              </xenc:ReferenceList>
            </xenc:EncryptedKey>
          </ds:KeyInfo>
          <xenc:CipherData>
            <xenc:CipherValue>encrypted-content-base64</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedData>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "enc-004",
        category: :encryption,
        type: :structure,
        description: "CipherReference element structure validation",
        spec_ref: "https://www.w3.org/TR/xmlenc-core/ Section 3.3",
        algorithm: "http://www.w3.org/2001/04/xmlenc#aes256-cbc",
        input: """
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                           xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
          <xenc:CipherData>
            <xenc:CipherReference URI="http://example.org/encrypted.bin">
              <xenc:Transforms>
                <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#base64"/>
              </xenc:Transforms>
            </xenc:CipherReference>
          </xenc:CipherData>
        </xenc:EncryptedData>
        """,
        expected: nil
      },
      %__MODULE__{
        id: "enc-005",
        category: :encryption,
        type: :structure,
        description: "AES-GCM encryption structure (XML Encryption 1.1)",
        spec_ref: "https://www.w3.org/TR/xmlenc-core1/ Section 5.2.4",
        algorithm: "http://www.w3.org/2009/xmlenc11#aes256-gcm",
        input: """
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                           Type="http://www.w3.org/2001/04/xmlenc#Element">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2009/xmlenc11#aes256-gcm"/>
          <xenc:CipherData>
            <xenc:CipherValue>iv-ciphertext-authtag-base64</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedData>
        """,
        expected: nil
      }
    ]
  end

  defp maybe_filter_category(tests, nil), do: tests

  defp maybe_filter_category(tests, category) do
    Enum.filter(tests, fn test ->
      test.category == category or
        to_string(test.category) |> String.starts_with?(to_string(category))
    end)
  end

  defp maybe_filter(tests, nil), do: tests

  defp maybe_filter(tests, filter) when is_binary(filter) do
    filter_lower = String.downcase(filter)

    Enum.filter(tests, fn test ->
      String.contains?(String.downcase(test.id), filter_lower) or
        String.contains?(String.downcase(test.description || ""), filter_lower)
    end)
  end

  defp maybe_limit(tests, nil), do: tests
  defp maybe_limit(tests, limit), do: Enum.take(tests, limit)
end

