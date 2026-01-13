defmodule FnXML.Security.Namespaces do
  @moduledoc """
  XML Security namespace constants.

  Defines standard namespace URIs for XML Signature, XML Encryption,
  and Canonicalization specifications.

  ## Usage

      alias FnXML.Security.Namespaces

      Namespaces.dsig()
      # => "http://www.w3.org/2000/09/xmldsig#"

  ## Namespace Prefixes Convention

  | Prefix | Namespace |
  |--------|-----------|
  | `ds` | XML Signature |
  | `xenc` | XML Encryption |
  | `ec` | Exclusive Canonicalization |
  """

  # XML Signature namespaces

  @doc "XML Signature 1.0/1.1 namespace"
  @spec dsig() :: String.t()
  def dsig, do: "http://www.w3.org/2000/09/xmldsig#"

  @doc "XML Signature 1.1 additional namespace"
  @spec dsig11() :: String.t()
  def dsig11, do: "http://www.w3.org/2009/xmldsig11#"

  @doc "XML Signature additional algorithms namespace"
  @spec dsig_more() :: String.t()
  def dsig_more, do: "http://www.w3.org/2001/04/xmldsig-more#"

  # XML Encryption namespaces

  @doc "XML Encryption 1.0 namespace"
  @spec xenc() :: String.t()
  def xenc, do: "http://www.w3.org/2001/04/xmlenc#"

  @doc "XML Encryption 1.1 namespace"
  @spec xenc11() :: String.t()
  def xenc11, do: "http://www.w3.org/2009/xmlenc11#"

  # Canonicalization algorithm URIs

  @doc "Canonical XML 1.0 algorithm URI"
  @spec c14n() :: String.t()
  def c14n, do: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315"

  @doc "Canonical XML 1.0 with comments algorithm URI"
  @spec c14n_with_comments() :: String.t()
  def c14n_with_comments, do: "http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments"

  @doc "Exclusive Canonical XML 1.0 algorithm URI"
  @spec exc_c14n() :: String.t()
  def exc_c14n, do: "http://www.w3.org/2001/10/xml-exc-c14n#"

  @doc "Exclusive Canonical XML 1.0 with comments algorithm URI"
  @spec exc_c14n_with_comments() :: String.t()
  def exc_c14n_with_comments, do: "http://www.w3.org/2001/10/xml-exc-c14n#WithComments"

  @doc "Canonical XML 1.1 algorithm URI"
  @spec c14n11() :: String.t()
  def c14n11, do: "http://www.w3.org/2006/12/xml-c14n11"

  @doc "Canonical XML 1.1 with comments algorithm URI"
  @spec c14n11_with_comments() :: String.t()
  def c14n11_with_comments, do: "http://www.w3.org/2006/12/xml-c14n11#WithComments"

  # Digest algorithm URIs

  @doc "SHA-256 digest algorithm URI"
  @spec sha256() :: String.t()
  def sha256, do: "http://www.w3.org/2001/04/xmlenc#sha256"

  @doc "SHA-384 digest algorithm URI"
  @spec sha384() :: String.t()
  def sha384, do: "http://www.w3.org/2001/04/xmldsig-more#sha384"

  @doc "SHA-512 digest algorithm URI"
  @spec sha512() :: String.t()
  def sha512, do: "http://www.w3.org/2001/04/xmlenc#sha512"

  # Signature algorithm URIs

  @doc "RSA-SHA256 signature algorithm URI"
  @spec rsa_sha256() :: String.t()
  def rsa_sha256, do: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"

  @doc "RSA-SHA384 signature algorithm URI"
  @spec rsa_sha384() :: String.t()
  def rsa_sha384, do: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha384"

  @doc "RSA-SHA512 signature algorithm URI"
  @spec rsa_sha512() :: String.t()
  def rsa_sha512, do: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha512"

  @doc "ECDSA-SHA256 signature algorithm URI"
  @spec ecdsa_sha256() :: String.t()
  def ecdsa_sha256, do: "http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256"

  # Encryption algorithm URIs

  @doc "AES-256-CBC encryption algorithm URI"
  @spec aes256_cbc() :: String.t()
  def aes256_cbc, do: "http://www.w3.org/2001/04/xmlenc#aes256-cbc"

  @doc "AES-256-GCM encryption algorithm URI"
  @spec aes256_gcm() :: String.t()
  def aes256_gcm, do: "http://www.w3.org/2009/xmlenc11#aes256-gcm"

  @doc "AES-128-GCM encryption algorithm URI"
  @spec aes128_gcm() :: String.t()
  def aes128_gcm, do: "http://www.w3.org/2009/xmlenc11#aes128-gcm"

  # Key transport algorithm URIs

  @doc "RSA-OAEP key transport algorithm URI"
  @spec rsa_oaep() :: String.t()
  def rsa_oaep, do: "http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p"

  # Transform algorithm URIs

  @doc "Enveloped signature transform algorithm URI"
  @spec enveloped_signature() :: String.t()
  def enveloped_signature, do: "http://www.w3.org/2000/09/xmldsig#enveloped-signature"

  @doc "Base64 transform algorithm URI"
  @spec base64() :: String.t()
  def base64, do: "http://www.w3.org/2000/09/xmldsig#base64"
end
