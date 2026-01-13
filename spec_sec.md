# W3C XML Security Specifications Reference

> Comprehensive reference for XML Signature and XML Encryption specifications, formatted for LLM consumption to build security modules.

---

## Table of Contents

1. [XML Signature Overview](#1-xml-signature-overview)
2. [XML Signature Structure](#2-xml-signature-structure)
3. [XML Signature Processing](#3-xml-signature-processing)
4. [Reference Processing](#4-reference-processing)
5. [Canonicalization](#5-canonicalization)
6. [Signature Algorithms](#6-signature-algorithms)
7. [XML Encryption Overview](#7-xml-encryption-overview)
8. [XML Encryption Structure](#8-xml-encryption-structure)
9. [XML Encryption Processing](#9-xml-encryption-processing)
10. [Encryption Algorithms](#10-encryption-algorithms)
11. [Key Management](#11-key-management)
12. [Namespaces and Schema](#12-namespaces-and-schema)
13. [Security Considerations](#13-security-considerations)
14. [Implementation Checklist](#14-implementation-checklist)
15. [Test Vectors](#15-test-vectors)

---

## 1. XML Signature Overview

### Specification References

| Specification | URI | Version |
|---------------|-----|---------|
| XML Signature Syntax and Processing | https://www.w3.org/TR/xmldsig-core1/ | 1.1 (Second Edition) |
| XML Signature Syntax and Processing | https://www.w3.org/TR/xmldsig-core/ | 1.0 |
| Canonical XML | https://www.w3.org/TR/xml-c14n | 1.0 |
| Exclusive XML Canonicalization | https://www.w3.org/TR/xml-exc-c14n/ | 1.0 |
| XML Signature 1.1 Interop Test Cases | https://www.w3.org/TR/xmldsig-core1-interop/ | 1.1 |

### Namespace

```
http://www.w3.org/2000/09/xmldsig#
```

**Prefix Convention**: `ds` (e.g., `ds:Signature`)

### Signature Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Enveloped** | Signature is inside the signed document | Sign an entire XML document |
| **Enveloping** | Signed data is inside the Signature element | Sign arbitrary data |
| **Detached** | Signature and signed data are separate | Sign external resources |

### Core Concepts

| Term | Definition |
|------|------------|
| **SignedInfo** | The information that is actually signed (canonicalized) |
| **Reference** | Pointer to data being signed, with transforms and digest |
| **Digest** | Cryptographic hash of referenced data after transforms |
| **SignatureValue** | The actual cryptographic signature over SignedInfo |
| **KeyInfo** | Information about the key used for signature |

---

## 2. XML Signature Structure

### Complete Signature Schema

```xml
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  <SignedInfo>
    <CanonicalizationMethod Algorithm="..."/>
    <SignatureMethod Algorithm="..."/>
    <Reference URI="...">
      <Transforms>
        <Transform Algorithm="..."/>
      </Transforms>
      <DigestMethod Algorithm="..."/>
      <DigestValue>...</DigestValue>
    </Reference>
  </SignedInfo>
  <SignatureValue>...</SignatureValue>
  <KeyInfo>...</KeyInfo>
  <Object>...</Object>
</Signature>
```

### Element Definitions

#### Signature Element

```
Signature ::= (SignedInfo, SignatureValue, KeyInfo?, Object*)
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier for reference |
| `xmlns` | Yes | Must be `http://www.w3.org/2000/09/xmldsig#` |

#### SignedInfo Element

```
SignedInfo ::= (CanonicalizationMethod, SignatureMethod, Reference+)
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier for reference |

**Critical**: The SignedInfo element is what gets canonicalized and signed. Any modification to SignedInfo will invalidate the signature.

#### CanonicalizationMethod Element

```
CanonicalizationMethod ::= (any)*
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Algorithm` | Yes | URI identifying canonicalization algorithm |

**Standard Algorithms**:

| Algorithm URI | Description |
|---------------|-------------|
| `http://www.w3.org/TR/2001/REC-xml-c14n-20010315` | Canonical XML 1.0 |
| `http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments` | Canonical XML 1.0 with Comments |
| `http://www.w3.org/2001/10/xml-exc-c14n#` | Exclusive Canonical XML 1.0 |
| `http://www.w3.org/2001/10/xml-exc-c14n#WithComments` | Exclusive C14N with Comments |
| `http://www.w3.org/2006/12/xml-c14n11` | Canonical XML 1.1 |
| `http://www.w3.org/2006/12/xml-c14n11#WithComments` | Canonical XML 1.1 with Comments |

#### SignatureMethod Element

```
SignatureMethod ::= (HMACOutputLength?, any)*
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Algorithm` | Yes | URI identifying signature algorithm |

**Standard Algorithms**:

| Algorithm URI | Description |
|---------------|-------------|
| `http://www.w3.org/2000/09/xmldsig#dsa-sha1` | DSA with SHA-1 (deprecated) |
| `http://www.w3.org/2000/09/xmldsig#rsa-sha1` | RSA with SHA-1 (deprecated) |
| `http://www.w3.org/2001/04/xmldsig-more#rsa-sha256` | RSA with SHA-256 |
| `http://www.w3.org/2001/04/xmldsig-more#rsa-sha384` | RSA with SHA-384 |
| `http://www.w3.org/2001/04/xmldsig-more#rsa-sha512` | RSA with SHA-512 |
| `http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256` | ECDSA with SHA-256 |
| `http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha384` | ECDSA with SHA-384 |
| `http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha512` | ECDSA with SHA-512 |
| `http://www.w3.org/2000/09/xmldsig#hmac-sha1` | HMAC-SHA1 |
| `http://www.w3.org/2001/04/xmldsig-more#hmac-sha256` | HMAC-SHA256 |
| `http://www.w3.org/2001/04/xmldsig-more#hmac-sha384` | HMAC-SHA384 |
| `http://www.w3.org/2001/04/xmldsig-more#hmac-sha512` | HMAC-SHA512 |

#### Reference Element

```
Reference ::= (Transforms?, DigestMethod, DigestValue)
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `URI` | No | URI to data being signed (empty = whole document) |
| `Id` | No | Identifier for reference |
| `Type` | No | Type of referenced data |

**URI Interpretation**:

| URI Value | Meaning |
|-----------|---------|
| `""` (empty) | Entire document (root element) |
| `#id` | Element with matching Id attribute |
| `#xpointer(/)` | Entire document including comments |
| `#xpointer(id('foo'))` | Element with Id "foo" |
| `http://...` | External resource |

#### Transforms Element

```
Transforms ::= (Transform+)
```

Transforms are applied in order to the referenced data before digesting.

#### Transform Element

```
Transform ::= (any | XPath)*
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Algorithm` | Yes | URI identifying transform algorithm |

**Standard Transform Algorithms**:

| Algorithm URI | Description |
|---------------|-------------|
| `http://www.w3.org/TR/2001/REC-xml-c14n-20010315` | Canonical XML 1.0 |
| `http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments` | C14N with Comments |
| `http://www.w3.org/2001/10/xml-exc-c14n#` | Exclusive C14N |
| `http://www.w3.org/2001/10/xml-exc-c14n#WithComments` | Exclusive C14N with Comments |
| `http://www.w3.org/2000/09/xmldsig#base64` | Base64 decoding |
| `http://www.w3.org/TR/1999/REC-xpath-19991116` | XPath filtering |
| `http://www.w3.org/2002/06/xmldsig-filter2` | XPath Filter 2.0 |
| `http://www.w3.org/TR/1999/REC-xslt-19991116` | XSLT transform |
| `http://www.w3.org/2000/09/xmldsig#enveloped-signature` | Remove enveloped signature |

#### DigestMethod Element

```
DigestMethod ::= (any)*
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Algorithm` | Yes | URI identifying digest algorithm |

**Standard Digest Algorithms**:

| Algorithm URI | Description | Output Size |
|---------------|-------------|-------------|
| `http://www.w3.org/2000/09/xmldsig#sha1` | SHA-1 (deprecated) | 160 bits |
| `http://www.w3.org/2001/04/xmlenc#sha256` | SHA-256 | 256 bits |
| `http://www.w3.org/2001/04/xmldsig-more#sha384` | SHA-384 | 384 bits |
| `http://www.w3.org/2001/04/xmlenc#sha512` | SHA-512 | 512 bits |

#### DigestValue Element

Contains the Base64-encoded digest value.

```xml
<DigestValue>dGhpcyBpcyBub3QgYSByZWFsIGRpZ2VzdA==</DigestValue>
```

#### SignatureValue Element

Contains the Base64-encoded signature value over the canonicalized SignedInfo.

```xml
<SignatureValue>dGhpcyBpcyBub3QgYSByZWFsIHNpZ25hdHVyZQ==</SignatureValue>
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier for reference |

#### KeyInfo Element

```
KeyInfo ::= (KeyName | KeyValue | RetrievalMethod | X509Data | PGPData | SPKIData | MgmtData | any)*
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier for reference |

**KeyInfo Child Elements**:

| Element | Description |
|---------|-------------|
| `KeyName` | String name identifying the key |
| `KeyValue` | Actual key value (DSAKeyValue, RSAKeyValue, ECKeyValue) |
| `RetrievalMethod` | URI and transform to retrieve key info |
| `X509Data` | X.509 certificate data |
| `PGPData` | PGP key data |
| `SPKIData` | SPKI key data |

#### KeyValue Sub-Elements

**RSAKeyValue**:
```xml
<KeyValue>
  <RSAKeyValue>
    <Modulus>Base64-encoded modulus</Modulus>
    <Exponent>Base64-encoded exponent</Exponent>
  </RSAKeyValue>
</KeyValue>
```

**DSAKeyValue**:
```xml
<KeyValue>
  <DSAKeyValue>
    <P>...</P>
    <Q>...</Q>
    <G>...</G>
    <Y>...</Y>
    <J>...</J>
    <Seed>...</Seed>
    <PgenCounter>...</PgenCounter>
  </DSAKeyValue>
</KeyValue>
```

**ECKeyValue** (XML Signature 1.1):
```xml
<KeyValue>
  <ECKeyValue>
    <NamedCurve URI="urn:oid:1.2.840.10045.3.1.7"/>
    <PublicKey>Base64-encoded point</PublicKey>
  </ECKeyValue>
</KeyValue>
```

#### X509Data Element

```xml
<X509Data>
  <X509IssuerSerial>
    <X509IssuerName>CN=Example CA,O=Example</X509IssuerName>
    <X509SerialNumber>123456789</X509SerialNumber>
  </X509IssuerSerial>
  <X509SKI>Base64-encoded Subject Key Identifier</X509SKI>
  <X509SubjectName>CN=Example User,O=Example</X509SubjectName>
  <X509Certificate>Base64-encoded DER certificate</X509Certificate>
  <X509CRL>Base64-encoded CRL</X509CRL>
</X509Data>
```

#### Object Element

Container for application-specific data.

```
Object ::= (any)*
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier for reference |
| `MimeType` | No | MIME type of content |
| `Encoding` | No | Encoding of content (e.g., Base64) |

---

## 3. XML Signature Processing

### Signature Generation

```
SIGNATURE GENERATION ALGORITHM
==============================

Input: Document D, Key K, References R[]
Output: Signed document with Signature element

1. For each Reference Ri in R[]:
   a. Obtain referenced data Di using URI
   b. Apply transforms Ti to Di -> Di'
   c. Compute digest: Hi = Hash(Di')
   d. Create Reference element with DigestValue = Base64(Hi)

2. Create SignedInfo element containing:
   - CanonicalizationMethod
   - SignatureMethod
   - All Reference elements

3. Canonicalize SignedInfo:
   SI_c14n = Canonicalize(SignedInfo)

4. Compute signature:
   SigValue = Sign(K, SI_c14n)

5. Create Signature element:
   <Signature>
     <SignedInfo>...</SignedInfo>
     <SignatureValue>Base64(SigValue)</SignatureValue>
     <KeyInfo>...</KeyInfo>  <!-- optional -->
   </Signature>

6. Insert Signature into document as appropriate
```

### Signature Validation

```
SIGNATURE VALIDATION ALGORITHM (Core Validation)
=================================================

Input: Signature element S, Key K (or means to obtain it)
Output: VALID or INVALID with reason

1. REFERENCE VALIDATION
   For each Reference Ri in SignedInfo:
   a. Obtain referenced data Di using URI
   b. Apply transforms Ti to Di -> Di'
   c. Compute digest: Hi_computed = Hash(Di')
   d. Compare: Hi_computed == DigestValue from Reference
   e. If mismatch: return INVALID (reference validation failed)

2. SIGNATURE VALIDATION
   a. Obtain signing key K (from KeyInfo or application)
   b. Canonicalize SignedInfo:
      SI_c14n = Canonicalize(SignedInfo)
   c. Verify signature:
      result = Verify(K, SI_c14n, Base64Decode(SignatureValue))
   d. If !result: return INVALID (signature validation failed)

3. Return VALID
```

---

## 4. Reference Processing

### URI Dereferencing

```
URI DEREFERENCING RULES
=======================

1. Same-Document References (starts with #):
   - "#id" -> XPointer shorthand for id()
   - "#xpointer(...)" -> Full XPointer expression

2. Empty URI (""):
   - Refers to document containing Signature
   - For enveloped signatures

3. External URIs (http://, file://, etc.):
   - Dereference according to URI scheme
   - Apply content negotiation if supported

4. Bare Name XPointer (#id):
   - Find element with matching Id attribute
   - Id attribute may be declared in DTD or schema
   - Or may use xml:id
   - Or application may indicate Id-ness
```

### Enveloped Signature Transform

**Algorithm URI**: `http://www.w3.org/2000/09/xmldsig#enveloped-signature`

```
ENVELOPED SIGNATURE TRANSFORM
=============================

Input: Node-set containing document
Output: Node-set with Signature element removed

Processing:
1. Identify the Signature element being processed
2. Remove that Signature element from node-set
3. Return modified node-set

Note: Only removes the Signature being validated, not other Signatures.
```

---

## 5. Canonicalization

### Canonical XML 1.0

**Algorithm URI**: `http://www.w3.org/TR/2001/REC-xml-c14n-20010315`

```
CANONICAL XML 1.0 RULES
=======================

1. Document Encoding: UTF-8 (no byte order mark)

2. Line Breaks: Normalize to #xA (LF)

3. Attribute Normalization:
   - Normalize according to XML 1.0 attribute normalization
   - Entity and character references expanded

4. Namespace Declarations:
   - Include all in-scope namespace declarations
   - Sort alphabetically by prefix
   - Empty default namespace (xmlns="") not rendered if not needed

5. Attribute Ordering:
   - Namespace declarations first (sorted by prefix)
   - Then attributes (sorted by namespace URI, then local name)

6. Empty Elements: Render as start-tag/end-tag pair

7. Whitespace:
   - Preserve all whitespace in content
   - Normalize attribute values

8. Comments: Removed (unless WithComments variant)

9. Processing Instructions: Preserved with normalized whitespace
```

### Exclusive Canonical XML

**Algorithm URI**: `http://www.w3.org/2001/10/xml-exc-c14n#`

```
EXCLUSIVE C14N DIFFERENCES FROM C14N 1.0
=========================================

Key Difference: Only visibly utilized namespace declarations are included.

A namespace declaration is "visibly utilized" if:
1. It is the namespace of the element
2. It is the namespace of a visible attribute
3. It is listed in InclusiveNamespaces PrefixList

Benefits:
- Smaller output (no inherited unused namespaces)
- Enables signing of document subsets that can be moved
```

### Canonicalization Algorithm Comparison

| Feature | C14N 1.0 | Exclusive C14N | C14N 1.1 |
|---------|----------|----------------|----------|
| Comments | Optional | Optional | Optional |
| Namespace inheritance | All in-scope | Visibly utilized | All in-scope |
| xml:id support | No | No | Yes |
| xml:base support | Limited | Limited | Full |

---

## 6. Signature Algorithms

### RSA Signatures

**RSA-SHA256** (Recommended):
```
Algorithm: http://www.w3.org/2001/04/xmldsig-more#rsa-sha256

Input: Canonicalized SignedInfo (octet stream)
Output: Base64-encoded signature

Process:
1. Hash = SHA-256(SignedInfo)
2. Signature = RSASSA-PKCS1-v1_5-SIGN(Key, Hash)
3. Return Base64(Signature)
```

### ECDSA Signatures

**ECDSA-SHA256**:
```
Algorithm: http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256

Input: Canonicalized SignedInfo (octet stream)
Output: Base64-encoded signature (r || s)

Process:
1. Hash = SHA-256(SignedInfo)
2. (r, s) = ECDSA-Sign(Key, Hash)
3. Signature = r || s (concatenation of big-endian integers)
4. Return Base64(Signature)
```

### Algorithm Security Status

| Algorithm | Status | Recommendation |
|-----------|--------|----------------|
| DSA-SHA1 | Deprecated | Do not use |
| RSA-SHA1 | Deprecated | Do not use |
| HMAC-SHA1 | Deprecated | Do not use |
| RSA-SHA256 | Recommended | Use for RSA |
| RSA-SHA384/512 | Recommended | Use for higher security |
| ECDSA-SHA256+ | Recommended | Use for elliptic curve |

---

## 7. XML Encryption Overview

### Specification References

| Specification | URI | Version |
|---------------|-----|---------|
| XML Encryption Syntax and Processing | https://www.w3.org/TR/xmlenc-core1/ | 1.1 |
| XML Encryption Syntax and Processing | https://www.w3.org/TR/xmlenc-core/ | 1.0 |

### Namespace

```
http://www.w3.org/2001/04/xmlenc#
```

**Prefix Convention**: `xenc` (e.g., `xenc:EncryptedData`)

### Encryption Types

| Type | Description | Result |
|------|-------------|--------|
| **Element Encryption** | Encrypt XML element | EncryptedData replaces element |
| **Content Encryption** | Encrypt element content | EncryptedData replaces content |
| **Arbitrary Data** | Encrypt non-XML data | EncryptedData contains data |

---

## 8. XML Encryption Structure

### Complete EncryptedData Schema

```xml
<EncryptedData xmlns="http://www.w3.org/2001/04/xmlenc#"
               Type="http://www.w3.org/2001/04/xmlenc#Element">
  <EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/>
  <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
    <EncryptedKey>
      <EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p"/>
      <ds:KeyInfo>
        <ds:KeyName>RecipientKey</ds:KeyName>
      </ds:KeyInfo>
      <CipherData>
        <CipherValue>Base64-encoded encrypted key</CipherValue>
      </CipherData>
    </EncryptedKey>
  </ds:KeyInfo>
  <CipherData>
    <CipherValue>Base64-encoded encrypted data</CipherValue>
  </CipherData>
</EncryptedData>
```

### Element Definitions

#### EncryptedData Element

```
EncryptedData ::= (EncryptionMethod?, KeyInfo?, CipherData, EncryptionProperties?)
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier |
| `Type` | No | Type of encrypted data |
| `MimeType` | No | MIME type of plaintext |
| `Encoding` | No | Encoding of plaintext |

**Type Values**:

| Type URI | Description |
|----------|-------------|
| `http://www.w3.org/2001/04/xmlenc#Element` | Encrypted XML element |
| `http://www.w3.org/2001/04/xmlenc#Content` | Encrypted element content |
| (none) | Arbitrary encrypted data |

#### EncryptedKey Element

```
EncryptedKey ::= (EncryptionMethod?, KeyInfo?, CipherData, ReferenceList?, CarriedKeyName?)
```

| Attribute | Required | Description |
|-----------|----------|-------------|
| `Id` | No | Identifier |
| `Type` | No | Always key data |
| `Recipient` | No | Hint for intended recipient |

#### CipherData Element

```
CipherData ::= (CipherValue | CipherReference)
```

**CipherValue**: Base64-encoded encrypted octets

**CipherReference**: URI to encrypted data with optional transforms

---

## 9. XML Encryption Processing

### Encryption Process

```
ENCRYPTION ALGORITHM
====================

Input: Plaintext P, Key K (or key agreement), Algorithm A
Output: EncryptedData element

1. SERIALIZE PLAINTEXT
   If encrypting XML element:
     P_bytes = Serialize(Element) as UTF-8
     Type = "http://www.w3.org/2001/04/xmlenc#Element"
   If encrypting element content:
     P_bytes = Serialize(Content) as UTF-8
     Type = "http://www.w3.org/2001/04/xmlenc#Content"

2. GENERATE DATA ENCRYPTION KEY (if using key encryption)
   DEK = RandomKey(Algorithm.KeySize)

3. ENCRYPT PLAINTEXT
   C_bytes = Encrypt(A, DEK or K, P_bytes)
   CipherValue = Base64(C_bytes)

4. ENCRYPT DATA ENCRYPTION KEY (if applicable)
   EncryptedKey = Encrypt(KEK_Algorithm, KEK, DEK)

5. CONSTRUCT EncryptedData ELEMENT

6. REPLACE ORIGINAL
   If Type=Element: Replace element with EncryptedData
   If Type=Content: Replace element children with EncryptedData
```

### Decryption Process

```
DECRYPTION ALGORITHM
====================

Input: EncryptedData element ED, Key K (or means to obtain)
Output: Decrypted data (element, content, or octets)

1. OBTAIN DECRYPTION KEY
   If KeyInfo contains EncryptedKey:
     a. Decrypt EncryptedKey using KEK
     b. DEK = decrypted key octets
   Else if KeyInfo references key:
     a. Resolve key reference
     b. DEK = resolved key
   Else:
     DEK = K (directly provided)

2. OBTAIN CIPHERTEXT
   If CipherValue:
     C_bytes = Base64Decode(CipherValue)
   If CipherReference:
     a. Dereference URI
     b. Apply transforms
     c. C_bytes = result octets

3. DECRYPT
   Algorithm = EncryptionMethod/@Algorithm
   P_bytes = Decrypt(Algorithm, DEK, C_bytes)

4. PROCESS RESULT
   If Type=Element:
     Parse P_bytes as XML
     Replace EncryptedData with parsed element
   If Type=Content:
     Parse P_bytes as XML fragment
     Replace EncryptedData with parsed content
```

---

## 10. Encryption Algorithms

### Block Encryption Algorithms

**AES-256-CBC** (Recommended):
```
Algorithm: http://www.w3.org/2001/04/xmlenc#aes256-cbc

Input: Plaintext, 256-bit key
Output: IV || Ciphertext

Process:
1. Generate random 16-byte IV
2. Pad plaintext (PKCS#7)
3. Encrypt with AES-256-CBC
4. Prepend IV to ciphertext
```

**AES-128-GCM** (Recommended for AEAD):
```
Algorithm: http://www.w3.org/2009/xmlenc11#aes128-gcm

Input: Plaintext, 128-bit key
Output: IV || Ciphertext || AuthTag

Process:
1. Generate random 12-byte IV
2. Encrypt with AES-128-GCM (96-bit IV, 128-bit tag)
3. Output = IV || Ciphertext || AuthTag
```

| Algorithm URI | Key Size | Mode | Status |
|---------------|----------|------|--------|
| `...#tripledes-cbc` | 192-bit | CBC | Deprecated |
| `...#aes128-cbc` | 128-bit | CBC | Legacy |
| `...#aes192-cbc` | 192-bit | CBC | Legacy |
| `...#aes256-cbc` | 256-bit | CBC | Recommended |
| `...11#aes128-gcm` | 128-bit | GCM | Recommended |
| `...11#aes192-gcm` | 192-bit | GCM | Recommended |
| `...11#aes256-gcm` | 256-bit | GCM | Recommended |

### Key Transport Algorithms

**RSA-OAEP** (Recommended):
```
Algorithm: http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p

Input: Key to encrypt, RSA public key
Output: Encrypted key

Default Parameters:
- Hash: SHA-1
- MGF: MGF1 with SHA-1
```

| Algorithm URI | Description | Status |
|---------------|-------------|--------|
| `...#rsa-1_5` | RSA PKCS#1 v1.5 | Deprecated (vulnerable) |
| `...#rsa-oaep-mgf1p` | RSA-OAEP | Recommended |
| `...11#rsa-oaep` | RSA-OAEP (1.1) | Recommended |

### Key Wrap Algorithms

**AES-256-KeyWrap**:
```
Algorithm: http://www.w3.org/2001/04/xmlenc#kw-aes256

Input: Key to wrap, 256-bit wrapping key
Output: Wrapped key (RFC 3394)

Use: Wrap a symmetric key with another symmetric key
```

| Algorithm URI | Key Size | Status |
|---------------|----------|--------|
| `...#kw-tripledes` | 192-bit | Deprecated |
| `...#kw-aes128` | 128-bit | OK |
| `...#kw-aes192` | 192-bit | OK |
| `...#kw-aes256` | 256-bit | Recommended |

---

## 11. Key Management

### KeyInfo in XML Security

KeyInfo can contain multiple means of identifying keys:

```xml
<ds:KeyInfo>
  <!-- Option 1: Named key -->
  <ds:KeyName>MyEncryptionKey</ds:KeyName>

  <!-- Option 2: Encrypted key inline -->
  <xenc:EncryptedKey>...</xenc:EncryptedKey>

  <!-- Option 3: Reference to encrypted key -->
  <ds:RetrievalMethod URI="#encrypted-key-1"
      Type="http://www.w3.org/2001/04/xmlenc#EncryptedKey"/>

  <!-- Option 4: Key agreement -->
  <xenc:AgreementMethod Algorithm="...#ECDH-ES">
    <xenc:OriginatorKeyInfo>...</xenc:OriginatorKeyInfo>
    <xenc:RecipientKeyInfo>...</xenc:RecipientKeyInfo>
  </xenc:AgreementMethod>

  <!-- Option 5: Certificate -->
  <ds:X509Data>
    <ds:X509Certificate>...</ds:X509Certificate>
  </ds:X509Data>
</ds:KeyInfo>
```

### Key Identifier Types

| Element | Description | Use Case |
|---------|-------------|----------|
| `KeyName` | String identifier | Pre-shared key lookup |
| `KeyValue` | Actual public key | Inline key delivery |
| `X509Data` | Certificate info | PKI-based systems |
| `EncryptedKey` | Wrapped key | Encrypt to recipients |
| `AgreementMethod` | Key derivation | Forward secrecy |
| `RetrievalMethod` | URI reference | External key store |

---

## 12. Namespaces and Schema

### Namespace URIs Reference

| Prefix | Namespace URI | Specification |
|--------|---------------|---------------|
| `ds` | `http://www.w3.org/2000/09/xmldsig#` | XML Signature 1.0 |
| `dsig11` | `http://www.w3.org/2009/xmldsig11#` | XML Signature 1.1 |
| `dsig-more` | `http://www.w3.org/2001/04/xmldsig-more#` | Additional algorithms |
| `xenc` | `http://www.w3.org/2001/04/xmlenc#` | XML Encryption 1.0 |
| `xenc11` | `http://www.w3.org/2009/xmlenc11#` | XML Encryption 1.1 |
| `ec` | `http://www.w3.org/2001/10/xml-exc-c14n#` | Exclusive C14N |

### Schema Locations

| Schema | Location |
|--------|----------|
| XML Signature | https://www.w3.org/TR/2008/REC-xmldsig-core-20080610/xmldsig-core-schema.xsd |
| XML Signature 1.1 | https://www.w3.org/TR/xmldsig-core1/xmldsig11-schema.xsd |
| XML Encryption | https://www.w3.org/TR/2002/REC-xmlenc-core-20021210/xenc-schema.xsd |
| XML Encryption 1.1 | https://www.w3.org/TR/xmlenc-core1/xenc-schema-11.xsd |

---

## 13. Security Considerations

### Signature Attacks

| Attack | Description | Mitigation |
|--------|-------------|------------|
| **Signature Wrapping** | Moving signed content | Validate XPath matches expected location |
| **Comment Injection** | Adding comments to change meaning | Use exclusive C14N |
| **Namespace Injection** | Manipulating namespace context | Validate namespace bindings |
| **Transform Abuse** | Using transforms to include unsigned data | Whitelist allowed transforms |
| **Key Substitution** | Using different key with valid signature | Bind key identity to application context |
| **Signature Exclusion** | Removing signature from document | Check signature presence before processing |

### Encryption Attacks

| Attack | Description | Mitigation |
|--------|-------------|------------|
| **Padding Oracle** | CBC padding attacks | Use authenticated encryption (GCM) |
| **Bleichenbacher** | RSA PKCS#1 v1.5 attack | Use RSA-OAEP only |
| **Compression** | CRIME/BREACH style attacks | Don't compress before encryption |
| **Ciphertext Modification** | Malleable encryption | Use authenticated encryption |
| **Key Reuse** | IV/nonce reuse | Never reuse IVs |

### Best Practices

```
SECURITY BEST PRACTICES
=======================

Signatures:
1. Use SHA-256 or stronger digests (never SHA-1)
2. Use RSA-2048+ or ECDSA with P-256+ curves
3. Use Exclusive C14N to prevent context manipulation
4. Validate document structure before signature verification
5. Verify all references point to expected content
6. Check signature covers security-relevant elements

Encryption:
1. Use AES-GCM (authenticated encryption)
2. Use RSA-OAEP for key transport (never PKCS#1 v1.5)
3. Use fresh random IVs for every encryption
4. Derive unique keys per message if possible
5. Validate decrypted content before processing
6. Zero sensitive key material after use

General:
1. Validate XML schema before processing
2. Limit XML entity expansion (XXE prevention)
3. Enforce algorithm allowlists
4. Log security-relevant failures
5. Use constant-time comparison for MACs/signatures
```

### Algorithm Recommendations

| Use Case | Recommended | Acceptable | Deprecated |
|----------|-------------|------------|------------|
| Digest | SHA-256, SHA-384, SHA-512 | - | SHA-1, MD5 |
| Signature | RSA-SHA256, ECDSA-SHA256 | RSA-SHA384/512 | RSA-SHA1, DSA |
| Key Transport | RSA-OAEP | - | RSA PKCS#1 v1.5 |
| Content Encryption | AES-256-GCM | AES-128-GCM | AES-CBC, 3DES |
| Key Wrap | AES-256-KW | AES-128-KW | 3DES-KW |
| Canonicalization | Exclusive C14N | C14N 1.1 | C14N 1.0 (with care) |

---

## 14. Implementation Checklist

### XML Signature Module

```
SIGNATURE GENERATION CHECKLIST
==============================
[ ] Parse input document
[ ] Identify elements to sign
[ ] Generate Reference elements:
    [ ] Dereference URIs
    [ ] Apply transforms in order
    [ ] Compute digest with specified algorithm
    [ ] Base64 encode digest value
[ ] Build SignedInfo element
[ ] Canonicalize SignedInfo
[ ] Compute signature over canonical SignedInfo
[ ] Base64 encode signature value
[ ] Construct complete Signature element
[ ] Insert signature into document
[ ] Validate generated signature (round-trip test)

SIGNATURE VERIFICATION CHECKLIST
================================
[ ] Parse Signature element
[ ] Extract SignedInfo
[ ] For each Reference:
    [ ] Dereference URI
    [ ] Apply transforms
    [ ] Compute digest
    [ ] Compare with DigestValue
    [ ] Fail fast on mismatch
[ ] Canonicalize SignedInfo (same algorithm as generation)
[ ] Obtain verification key
[ ] Verify signature value
[ ] Return detailed result (which reference failed, etc.)
```

### XML Encryption Module

```
ENCRYPTION CHECKLIST
====================
[ ] Identify content to encrypt
[ ] Serialize content (UTF-8 for XML)
[ ] Generate random data encryption key
[ ] Generate random IV
[ ] Encrypt content with DEK
[ ] Encrypt DEK with key encryption key (if applicable)
[ ] Build EncryptedData/EncryptedKey elements
[ ] Replace original content

DECRYPTION CHECKLIST
====================
[ ] Parse EncryptedData element
[ ] Determine encryption algorithm
[ ] Obtain decryption key:
    [ ] From EncryptedKey (decrypt with KEK)
    [ ] From KeyInfo (resolve reference)
    [ ] From application context
[ ] Extract IV from ciphertext
[ ] Decrypt ciphertext
[ ] If GCM: verify authentication tag
[ ] Parse decrypted content (if XML)
[ ] Replace EncryptedData with content
```

### Canonicalization Module

```
CANONICALIZATION CHECKLIST
==========================
[ ] Convert input to XPath node-set
[ ] Normalize line endings (CRLF -> LF)
[ ] For each node in document order:
    [ ] Elements: Output start/end tags
    [ ] Attributes: Sort and output
    [ ] Namespace declarations: Sort and output
    [ ] Text: Escape special characters
    [ ] Comments: Include if WithComments variant
    [ ] PIs: Output with normalized whitespace
[ ] Apply namespace prefix handling:
    [ ] C14N: All in-scope namespaces
    [ ] Exclusive: Only visibly utilized
[ ] Output UTF-8 encoded result
```

### Algorithm Support Matrix

```
MINIMUM REQUIRED ALGORITHMS
===========================

Signature Methods:
[MUST]    RSA with SHA-256
[SHOULD]  ECDSA with SHA-256
[MAY]     HMAC with SHA-256

Digest Methods:
[MUST]    SHA-256
[SHOULD]  SHA-384, SHA-512

Canonicalization:
[MUST]    Canonical XML 1.0
[MUST]    Exclusive Canonical XML 1.0
[SHOULD]  Canonical XML 1.1

Transforms:
[MUST]    Enveloped Signature
[MUST]    Canonicalization transforms
[SHOULD]  XPath Filter 2.0
[MAY]     Base64

Encryption Algorithms:
[MUST]    AES-256-CBC
[SHOULD]  AES-256-GCM (authenticated)
[MAY]     AES-128-GCM

Key Transport:
[MUST]    RSA-OAEP
[MAY]     ECDH-ES

Key Wrap:
[MUST]    AES-256-KeyWrap
[MAY]     AES-128-KeyWrap
```

---

## 15. Test Vectors

### Canonicalization Test Cases

**Test C14N-001: Basic Canonicalization**

Input:
```xml
<?xml version="1.0"?>

<!DOCTYPE doc [<!ATTLIST e9 attr CDATA "default">]>
<doc>
   <e1   />
   <e2   ></e2>
   <e3   name = "elem3"   id="elem3"   />
   <e4   name="elem4"   id="elem4"   ></e4>
</doc>
```

Expected C14N Output:
```xml
<doc>
   <e1></e1>
   <e2></e2>
   <e3 id="elem3" name="elem3"></e3>
   <e4 id="elem4" name="elem4"></e4>
</doc>
```

**Test C14N-002: Namespace Handling**

Input:
```xml
<doc xmlns="http://example.org/default"
     xmlns:a="http://example.org/a"
     xmlns:b="http://example.org/b">
   <a:elem a:attr="value"/>
</doc>
```

Expected Exclusive C14N (subset=`//a:elem`):
```xml
<a:elem xmlns:a="http://example.org/a" a:attr="value"></a:elem>
```

### Signature Test Cases

**Test SIG-001: Enveloped Signature**

Input document:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Document Id="doc1">
  <Data>Test content</Data>
</Document>
```

Expected signature structure shows Signature element inside Document with:
- SignedInfo containing CanonicalizationMethod, SignatureMethod, and Reference
- Reference with URI="" pointing to whole document
- Enveloped-signature and exclusive C14N transforms
- SHA-256 digest and RSA-SHA256 signature

**Test SIG-002: Detached Signature**

Signed data (external): `This is external data to be signed.`

Signature contains Reference with external URI and SHA-256 digest.

### Encryption Test Cases

**Test ENC-001: Element Encryption**

Input:
```xml
<Document>
  <Public>Not encrypted</Public>
  <Secret>Confidential data</Secret>
</Document>
```

After encrypting `<Secret>` element, it is replaced by EncryptedData with Type="Element".

**Test ENC-002: Content Encryption**

Input:
```xml
<Document>
  <Wrapper>
    <Item>Value 1</Item>
    <Item>Value 2</Item>
  </Wrapper>
</Document>
```

After encrypting content of `<Wrapper>`, children replaced by EncryptedData with Type="Content".

---

## References

### W3C Specifications

- **XML Signature 1.0**: https://www.w3.org/TR/xmldsig-core/
- **XML Signature 1.1**: https://www.w3.org/TR/xmldsig-core1/
- **XML Encryption 1.0**: https://www.w3.org/TR/xmlenc-core/
- **XML Encryption 1.1**: https://www.w3.org/TR/xmlenc-core1/
- **Canonical XML 1.0**: https://www.w3.org/TR/xml-c14n
- **Canonical XML 1.1**: https://www.w3.org/TR/xml-c14n11/
- **Exclusive C14N**: https://www.w3.org/TR/xml-exc-c14n/
- **XPath Filter 2.0**: https://www.w3.org/TR/xmldsig-filter2/

### Related RFCs

- **RFC 3275**: XML Signature Syntax and Processing
- **RFC 3394**: AES Key Wrap Algorithm
- **RFC 5649**: AES Key Wrap with Padding
- **RFC 8017**: PKCS #1 (RSA)

### Test Suites

- **XML Signature Interop**: https://www.w3.org/TR/xmldsig-core1-interop/
- **Apache Santuario Test Vectors**: https://santuario.apache.org/
- **W3C Test Collection**: https://www.w3.org/Signature/2002/02/01-xmldsig-interop.html

---

## Quick Reference Card

### Signature Element Order
```
Signature
|-- SignedInfo (required)
|   |-- CanonicalizationMethod (required)
|   |-- SignatureMethod (required)
|   +-- Reference+ (one or more)
|       |-- Transforms? (optional)
|       |-- DigestMethod (required)
|       +-- DigestValue (required)
|-- SignatureValue (required)
|-- KeyInfo? (optional)
+-- Object* (zero or more)
```

### Encryption Element Order
```
EncryptedData
|-- EncryptionMethod? (optional)
|-- KeyInfo? (optional)
|   |-- KeyName
|   |-- EncryptedKey
|   |-- AgreementMethod
|   +-- RetrievalMethod
|-- CipherData (required)
|   +-- CipherValue | CipherReference
+-- EncryptionProperties? (optional)
```

### Common Namespace Prefixes
```xml
xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
xmlns:xenc="http://www.w3.org/2001/04/xmlenc#"
xmlns:ec="http://www.w3.org/2001/10/xml-exc-c14n#"
```

### Minimum Algorithm Set
```
Signature:  RSA-SHA256
Digest:     SHA-256
C14N:       Exclusive C14N
Encryption: AES-256-GCM
Key Wrap:   RSA-OAEP
```
