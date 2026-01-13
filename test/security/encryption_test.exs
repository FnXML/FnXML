defmodule FnXML.Security.EncryptionTest do
  use ExUnit.Case, async: true

  alias FnXML.Security.Encryption
  alias FnXML.Security.Algorithms

  describe "Encryption.info/1" do
    test "extracts encryption information from encrypted document" do
      encrypted_doc = """
      <root>
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
                           Type="http://www.w3.org/2001/04/xmlenc#Element">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2009/xmlenc11#aes256-gcm"/>
          <xenc:CipherData>
            <xenc:CipherValue>dGVzdA==</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedData>
      </root>
      """

      {:ok, info} = Encryption.info(encrypted_doc)

      assert info.algorithm == :aes_256_gcm
      assert info.type == :element
    end

    test "returns error when no encrypted data present" do
      doc = "<root><child/></root>"
      assert {:error, :no_encrypted_data} = Encryption.info(doc)
    end
  end

  describe "Encryption.find_encrypted_data/1" do
    test "finds all EncryptedData elements" do
      doc = """
      <root>
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#" Id="enc1">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2009/xmlenc11#aes256-gcm"/>
          <xenc:CipherData>
            <xenc:CipherValue>dGVzdDE=</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedData>
        <xenc:EncryptedData xmlns:xenc="http://www.w3.org/2001/04/xmlenc#" Id="enc2">
          <xenc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
          <xenc:CipherData>
            <xenc:CipherValue>dGVzdDI=</xenc:CipherValue>
          </xenc:CipherData>
        </xenc:EncryptedData>
      </root>
      """

      {:ok, encrypted_list} = Encryption.find_encrypted_data(doc)

      assert length(encrypted_list) == 2
      assert Enum.any?(encrypted_list, &(&1.id == "enc1"))
      assert Enum.any?(encrypted_list, &(&1.id == "enc2"))
    end

    test "returns empty list when no encrypted data" do
      doc = "<root><child/></root>"
      {:ok, encrypted_list} = Encryption.find_encrypted_data(doc)
      assert encrypted_list == []
    end
  end

  describe "encrypt/decrypt round-trip" do
    test "element encryption with AES-256-GCM" do
      xml = """
      <root>
        <secret Id="secret-data">This is sensitive information</secret>
      </root>
      """

      key = Algorithms.generate_key(32)

      {:ok, encrypted} =
        Encryption.encrypt(xml, "#secret-data", key,
          algorithm: :aes_256_gcm,
          type: :element
        )

      # Verify it's encrypted
      assert encrypted =~ "EncryptedData"
      assert encrypted =~ "CipherValue"
      refute encrypted =~ "This is sensitive information"

      # Decrypt and verify
      {:ok, decrypted} = Encryption.decrypt(encrypted, key)
      assert decrypted =~ "This is sensitive information"
    end

    test "element encryption with AES-256-CBC" do
      xml = """
      <root>
        <secret Id="to-encrypt">CBC mode test data</secret>
      </root>
      """

      key = Algorithms.generate_key(32)

      {:ok, encrypted} =
        Encryption.encrypt(xml, "#to-encrypt", key,
          algorithm: :aes_256_cbc,
          type: :element
        )

      assert encrypted =~ "EncryptedData"
      refute encrypted =~ "CBC mode test data"

      {:ok, decrypted} = Encryption.decrypt(encrypted, key)
      assert decrypted =~ "CBC mode test data"
    end

    test "AES-128-GCM encryption" do
      xml = """
      <root>
        <data Id="item">Short content</data>
      </root>
      """

      key = Algorithms.generate_key(16)

      {:ok, encrypted} =
        Encryption.encrypt(xml, "#item", key, algorithm: :aes_128_gcm)

      {:ok, decrypted} = Encryption.decrypt(encrypted, key)
      assert decrypted =~ "Short content"
    end
  end

  describe "key transport" do
    # Generate test RSA key pair
    defp generate_rsa_keypair do
      private_key = :public_key.generate_key({:rsa, 2048, 65537})
      {:RSAPrivateKey, _, n, e, _, _, _, _, _, _, _} = private_key
      public_key = {:RSAPublicKey, n, e}
      {private_key, public_key}
    end

    test "encryption with RSA-OAEP key transport" do
      xml = """
      <root>
        <secret Id="wrapped">Key transport test</secret>
      </root>
      """

      {private_key, public_key} = generate_rsa_keypair()

      # Encrypt with key transport (generates random key, wraps with public key)
      {:ok, encrypted} =
        Encryption.encrypt(xml, "#wrapped", nil,
          algorithm: :aes_256_gcm,
          key_transport: {:rsa_oaep, public_key}
        )

      assert encrypted =~ "EncryptedKey"
      assert encrypted =~ "EncryptedData"

      # Decrypt using private key
      {:ok, decrypted} = Encryption.decrypt(encrypted, private_key: private_key)
      assert decrypted =~ "Key transport test"
    end
  end

  describe "error handling" do
    test "returns error for missing target" do
      xml = "<root><child/></root>"
      key = Algorithms.generate_key(32)

      assert {:error, {:element_not_found, "nonexistent"}} =
               Encryption.encrypt(xml, "#nonexistent", key)
    end

    test "returns error when no key provided" do
      xml = "<root><secret Id=\"data\">test</secret></root>"

      assert {:error, :no_encryption_key} =
               Encryption.encrypt(xml, "#data", nil, algorithm: :aes_256_gcm)
    end
  end
end
