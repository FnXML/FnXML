# XML Core W3C Specifications Reference

> A comprehensive reference for W3C XML 1.0 (Fifth Edition) and Namespaces in XML 1.0 (Third Edition) specifications, formatted for LLM consumption.

---

## Table of Contents

1. [Document Structure](#1-document-structure)
2. [Character Definitions](#2-character-definitions)
3. [Names and Tokens](#3-names-and-tokens)
4. [Elements and Tags](#4-elements-and-tags)
5. [Attributes](#5-attributes)
6. [Entity Handling](#6-entity-handling)
7. [Document Type Definition (DTD)](#7-document-type-definition-dtd)
8. [CDATA Sections](#8-cdata-sections)
9. [Comments](#9-comments)
10. [Processing Instructions](#10-processing-instructions)
11. [Namespaces](#11-namespaces)
12. [Well-Formedness Constraints (WFC)](#12-well-formedness-constraints-wfc)
13. [Validity Constraints (VC)](#13-validity-constraints-vc)
14. [Attribute Normalization](#14-attribute-normalization)
15. [Character Encoding](#15-character-encoding)
16. [Processor Conformance](#16-processor-conformance)
17. [Complete Production Rules](#17-complete-production-rules)
18. [Predefined Entities](#18-predefined-entities)
19. [Reserved Names](#19-reserved-names)
20. [Error Classification](#20-error-classification)

---

## 1. Document Structure

### Production Rules

```ebnf
[1]  document     ::= prolog element Misc*
[22] prolog       ::= XMLDecl? Misc* (doctypedecl Misc*)?
[23] XMLDecl      ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
[24] VersionInfo  ::= S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
[25] Eq           ::= S? '=' S?
[26] VersionNum   ::= '1.' [0-9]+
[27] Misc         ::= Comment | PI | S
[32] SDDecl       ::= S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"'))
```

### Structure Overview

```
XML Document
├── Prolog (optional)
│   ├── XML Declaration (<?xml version="1.0"?>)
│   ├── Misc (comments, PIs, whitespace)
│   └── DOCTYPE Declaration (optional)
├── Root Element (exactly one)
│   └── Content (elements, text, comments, PIs, CDATA)
└── Misc (comments, PIs, whitespace)
```

### Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root SYSTEM "schema.dtd">
<!-- Document comment -->
<root>
  <child>Content</child>
</root>
```

---

## 2. Character Definitions

### Valid XML Characters [Production 2]

```ebnf
[2] Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
```

| Range | Description |
|-------|-------------|
| `#x9` | Tab (horizontal tab) |
| `#xA` | Line Feed (LF) |
| `#xD` | Carriage Return (CR) |
| `#x20-#xD7FF` | Space through most of Basic Multilingual Plane |
| `#xE000-#xFFFD` | Private Use Area through replacement character |
| `#x10000-#x10FFFF` | Supplementary planes (emoji, historic scripts, etc.) |

### Invalid Characters (MUST be rejected)

| Range | Description |
|-------|-------------|
| `#x0-#x8` | C0 control characters (NUL, SOH, STX, etc.) |
| `#xB-#xC` | Vertical tab, form feed |
| `#xE-#x1F` | More C0 controls (SO, SI, DLE, DC1-DC4, etc.) |
| `#xD800-#xDFFF` | UTF-16 surrogate pairs (invalid in UTF-8) |
| `#xFFFE-#xFFFF` | Non-characters |

### Discouraged Characters (valid but discouraged)

| Range | Description |
|-------|-------------|
| `#x7F-#x84` | DEL and C1 controls |
| `#x86-#x9F` | More C1 controls |
| `#xFDD0-#xFDEF` | Non-characters |
| `#x1FFFE-#x1FFFF` ... `#x10FFFE-#x10FFFF` | Plane non-characters |

### White Space [Production 3]

```ebnf
[3] S ::= (#x20 | #x9 | #xD | #xA)+
```

| Character | Code Point | Name |
|-----------|------------|------|
| Space | `#x20` | SPACE |
| Tab | `#x9` | HORIZONTAL TAB |
| CR | `#xD` | CARRIAGE RETURN |
| LF | `#xA` | LINE FEED |

### Line Ending Normalization (Section 2.11)

**MUST** be performed before parsing:
- `#xD #xA` (CRLF) → `#xA` (LF)
- `#xD` (standalone CR) → `#xA` (LF)

---

## 3. Names and Tokens

### Name Start Characters [Production 4]

```ebnf
[4] NameStartChar ::= ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] |
                      [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] |
                      [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] |
                      [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] |
                      [#x10000-#xEFFFF]
```

### Name Characters [Production 4a]

```ebnf
[4a] NameChar ::= NameStartChar | "-" | "." | [0-9] | #xB7 |
                  [#x0300-#x036F] | [#x203F-#x2040]
```

### Name Productions [Productions 5-8]

```ebnf
[5] Name     ::= NameStartChar (NameChar)*
[6] Names    ::= Name (#x20 Name)*
[7] Nmtoken  ::= (NameChar)+
[8] Nmtokens ::= Nmtoken (#x20 Nmtoken)*
```

### Key Differences

| Type | Starts With | Contains | Example |
|------|-------------|----------|---------|
| Name | NameStartChar | NameChar* | `element`, `_private`, `ns:name` |
| Nmtoken | NameChar | NameChar* | `123`, `-option`, `.config` |

---

## 4. Elements and Tags

### Productions

```ebnf
[39] element      ::= EmptyElemTag | STag content ETag
[40] STag         ::= '<' Name (S Attribute)* S? '>'
[41] Attribute    ::= Name Eq AttValue
[42] ETag         ::= '</' Name S? '>'
[43] content      ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
[44] EmptyElemTag ::= '<' Name (S Attribute)* S? '/>'
```

### Character Data [Production 14]

```ebnf
[14] CharData ::= [^<&]* - ([^<&]* ']]>' [^<&]*)
```

Text content cannot contain:
- `<` (start of markup)
- `&` (start of entity reference)
- `]]>` (CDATA section end delimiter)

### Well-Formedness Requirements

1. **Element Type Match** [WFC]: End-tag name MUST match start-tag name
2. **Proper Nesting**: Elements must be properly nested
3. **Single Root**: Exactly one root element

### Examples

```xml
<!-- Empty element (two equivalent forms) -->
<br/>
<br></br>

<!-- Element with content -->
<p>Text content with <em>nested</em> elements.</p>

<!-- Element with attributes -->
<img src="photo.jpg" alt="Description"/>
```

---

## 5. Attributes

### Productions

```ebnf
[41] Attribute ::= Name Eq AttValue
[10] AttValue  ::= '"' ([^<&"] | Reference)* '"' | "'" ([^<&'] | Reference)* "'"
```

### Attribute Value Constraints

| Character | Allowed? | Alternative |
|-----------|----------|-------------|
| `<` | **NO** | Use `&lt;` |
| `&` | Only in entity refs | Use `&amp;` |
| `"` | Not in `"..."` values | Use `&quot;` or `'...'` |
| `'` | Not in `'...'` values | Use `&apos;` or `"..."` |

### Well-Formedness Constraints

- **WFC: Unique Att Spec**: No duplicate attribute names in same element
- **WFC: No External Entity References**: Attribute values cannot reference external entities
- **WFC: No < in Attribute Values**: Neither directly nor through entity expansion

### Attribute Types (in DTD)

| Type | Description | Normalization |
|------|-------------|---------------|
| CDATA | Character data | Whitespace → space |
| ID | Unique identifier | Tokenized |
| IDREF | Reference to ID | Tokenized |
| IDREFS | Space-separated IDREFs | Tokenized |
| ENTITY | Unparsed entity name | Tokenized |
| ENTITIES | Space-separated ENTITYs | Tokenized |
| NMTOKEN | Name token | Tokenized |
| NMTOKENS | Space-separated NMTOKENs | Tokenized |
| NOTATION | Notation name | Tokenized |
| Enumeration | One of listed values | Tokenized |

### Default Declarations

| Declaration | Meaning |
|-------------|---------|
| `#REQUIRED` | Attribute must be specified |
| `#IMPLIED` | Attribute is optional, no default |
| `#FIXED "value"` | Must equal default if specified |
| `"value"` | Default used if not specified |

---

## 6. Entity Handling

### Entity Types

| Type | Parsed? | Where Used | Example |
|------|---------|------------|---------|
| Internal General | Yes | Document content | `<!ENTITY copyright "...">` |
| External Parsed | Yes | Document content | `<!ENTITY chapter SYSTEM "ch1.xml">` |
| External Unparsed | No | Attribute values only | `<!ENTITY logo SYSTEM "logo.gif" NDATA gif>` |
| Internal Parameter | Yes | DTD only | `<!ENTITY % common "...">` |
| External Parameter | Yes | DTD only | `<!ENTITY % types SYSTEM "types.ent">` |

### Entity Reference Productions

```ebnf
[66] CharRef    ::= '&#' [0-9]+ ';' | '&#x' [0-9a-fA-F]+ ';'
[67] Reference  ::= EntityRef | CharRef
[68] EntityRef  ::= '&' Name ';'
[69] PEReference ::= '%' Name ';'
```

### Entity Declaration Productions

```ebnf
[70] EntityDecl  ::= GEDecl | PEDecl
[71] GEDecl      ::= '<!ENTITY' S Name S EntityDef S? '>'
[72] PEDecl      ::= '<!ENTITY' S '%' S Name S PEDef S? '>'
[73] EntityDef   ::= EntityValue | (ExternalID NDataDecl?)
[74] PEDef       ::= EntityValue | ExternalID
[75] ExternalID  ::= 'SYSTEM' S SystemLiteral | 'PUBLIC' S PubidLiteral S SystemLiteral
[76] NDataDecl   ::= S 'NDATA' S Name
```

### Entity Value Productions

```ebnf
[9] EntityValue   ::= '"' ([^%&"] | PEReference | Reference)* '"' |
                      "'" ([^%&'] | PEReference | Reference)* "'"
[11] SystemLiteral ::= ('"' [^"]* '"') | ("'" [^']* "'")
[12] PubidLiteral  ::= '"' PubidChar* '"' | "'" (PubidChar - "'")* "'"
```

### Well-Formedness Constraints

- **WFC: Entity Declared**: Referenced entities must be declared (with exceptions for standalone)
- **WFC: Parsed Entity**: Entity references cannot name unparsed entities
- **WFC: No Recursion**: Entities cannot reference themselves directly or indirectly

---

## 7. Document Type Definition (DTD)

### DOCTYPE Declaration [Production 28]

```ebnf
[28]  doctypedecl    ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
[28a] DeclSep        ::= PEReference | S
[28b] intSubset      ::= (markupdecl | DeclSep)*
[29]  markupdecl     ::= elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment
[30]  extSubset      ::= TextDecl? extSubsetDecl
[31]  extSubsetDecl  ::= (markupdecl | conditionalSect | DeclSep)*
```

### Element Declarations [Productions 45-51]

```ebnf
[45] elementdecl ::= '<!ELEMENT' S Name S contentspec S? '>'
[46] contentspec ::= 'EMPTY' | 'ANY' | Mixed | children
[47] children    ::= (choice | seq) ('?' | '*' | '+')?
[48] cp          ::= (Name | choice | seq) ('?' | '*' | '+')?
[49] choice      ::= '(' S? cp (S? '|' S? cp)+ S? ')'
[50] seq         ::= '(' S? cp (S? ',' S? cp)* S? ')'
[51] Mixed       ::= '(' S? '#PCDATA' (S? '|' S? Name)* S? ')*' | '(' S? '#PCDATA' S? ')'
```

### Content Model Syntax

| Syntax | Meaning | Example |
|--------|---------|---------|
| `EMPTY` | No content allowed | `<!ELEMENT br EMPTY>` |
| `ANY` | Any content allowed | `<!ELEMENT container ANY>` |
| `(#PCDATA)` | Text only | `<!ELEMENT p (#PCDATA)>` |
| `(a,b,c)` | Sequence | `<!ELEMENT doc (head,body)>` |
| `(a\|b\|c)` | Choice | `<!ELEMENT item (p\|list)>` |
| `a?` | Optional (0 or 1) | `<!ELEMENT doc (title?)>` |
| `a*` | Zero or more | `<!ELEMENT list (item*)>` |
| `a+` | One or more | `<!ELEMENT list (item+)>` |
| `(#PCDATA\|a)*` | Mixed content | `<!ELEMENT p (#PCDATA\|em\|b)*>` |

### Attribute List Declarations [Productions 52-60]

```ebnf
[52] AttlistDecl  ::= '<!ATTLIST' S Name AttDef* S? '>'
[53] AttDef       ::= S Name S AttType S DefaultDecl
[54] AttType      ::= StringType | TokenizedType | EnumeratedType
[55] StringType   ::= 'CDATA'
[56] TokenizedType ::= 'ID' | 'IDREF' | 'IDREFS' | 'ENTITY' | 'ENTITIES' | 'NMTOKEN' | 'NMTOKENS'
[57] EnumeratedType ::= NotationType | Enumeration
[58] NotationType ::= 'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')'
[59] Enumeration  ::= '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'
[60] DefaultDecl  ::= '#REQUIRED' | '#IMPLIED' | (('#FIXED' S)? AttValue)
```

### Notation Declarations [Productions 82-83]

```ebnf
[82] NotationDecl ::= '<!NOTATION' S Name S (ExternalID | PublicID) S? '>'
[83] PublicID     ::= 'PUBLIC' S PubidLiteral
```

### Conditional Sections [Productions 61-65]

```ebnf
[61] conditionalSect    ::= includeSect | ignoreSect
[62] includeSect        ::= '<![' S? 'INCLUDE' S? '[' extSubsetDecl ']]>'
[63] ignoreSect         ::= '<![' S? 'IGNORE' S? '[' ignoreSectContents* ']]>'
[64] ignoreSectContents ::= Ignore ('<![' ignoreSectContents ']]>' Ignore)*
[65] Ignore             ::= Char* - (Char* ('<![' | ']]>') Char*)
```

---

## 8. CDATA Sections

### Productions

```ebnf
[18] CDSect  ::= CDStart CData CDEnd
[19] CDStart ::= '<![CDATA['
[20] CData   ::= (Char* - (Char* ']]>' Char*))
[21] CDEnd   ::= ']]>'
```

### Purpose

CDATA sections allow literal text containing `<` and `&` without escaping:

```xml
<script><![CDATA[
  if (a < b && c > d) {
    console.log("test");
  }
]]></script>
```

### Constraints

- Cannot contain `]]>` (the end delimiter)
- Cannot be nested
- Not recognized in attribute values (only in element content)

---

## 9. Comments

### Production

```ebnf
[15] Comment ::= '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
```

### Constraints

- **Cannot contain `--`**: The string `--` is not allowed within comments
- Must end with `-->`
- Not part of document's character data

### Examples

```xml
<!-- This is a valid comment -->
<!-- Single - hyphens - are - fine -->
<!-- This -- is INVALID -->
```

---

## 10. Processing Instructions

### Productions

```ebnf
[16] PI       ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
[17] PITarget ::= Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
```

### Constraints

- Target name cannot be `xml` (case-insensitive)
- Cannot contain `?>`
- Content is passed to application, not parsed as XML

### Examples

```xml
<?xml-stylesheet type="text/xsl" href="style.xsl"?>
<?php echo "Hello"; ?>
<?custom-app instruction-data?>
```

---

## 11. Namespaces

### Namespace-Aware Productions

```ebnf
[NS 1]  NSAttName      ::= PrefixedAttName | DefaultAttName
[NS 2]  PrefixedAttName ::= 'xmlns:' NCName
[NS 3]  DefaultAttName  ::= 'xmlns'
[NS 4]  NCName          ::= Name - (Char* ':' Char*)  /* Name without colons */
[NS 7]  QName           ::= PrefixedName | UnprefixedName
[NS 8]  PrefixedName    ::= Prefix ':' LocalPart
[NS 9]  UnprefixedName  ::= LocalPart
[NS 10] Prefix          ::= NCName
[NS 11] LocalPart       ::= NCName
```

### Reserved Namespaces

| Prefix | Namespace URI | Notes |
|--------|---------------|-------|
| `xml` | `http://www.w3.org/XML/1998/namespace` | Always bound, cannot be redeclared |
| `xmlns` | `http://www.w3.org/2000/xmlns/` | Declaration-only, cannot be used |

### Namespace Declaration Syntax

```xml
<!-- Prefix declaration -->
<root xmlns:prefix="http://example.com/ns">
  <prefix:element/>
</root>

<!-- Default namespace -->
<root xmlns="http://example.com/ns">
  <element/>  <!-- In default namespace -->
</root>

<!-- Undeclaring default namespace -->
<outer xmlns="http://example.com/ns">
  <inner xmlns="">  <!-- No namespace -->
  </inner>
</outer>
```

### Namespace Scope Rules

1. Declarations scope from start-tag to matching end-tag
2. Inner declarations override outer declarations
3. Default namespace applies to unprefixed elements only
4. Attributes are NOT in the default namespace (unprefixed attrs have no namespace)
5. Prefixed namespace declarations cannot be undeclared (value cannot be empty)

### Namespace Constraints

- **Prefix Declared**: Used prefixes must be declared in scope
- **No Prefix Undeclaring**: `xmlns:prefix=""` is invalid
- **Attributes Unique**: No duplicate attributes (considering expanded names)

---

## 12. Well-Formedness Constraints (WFC)

### Document Structure

| Constraint | Description |
|------------|-------------|
| **Element Type Match** | End-tag name must match start-tag name |
| **Unique Att Spec** | No duplicate attribute names in same element |

### Entity Constraints

| Constraint | Description |
|------------|-------------|
| **Entity Declared** | Referenced entities must be declared |
| **Parsed Entity** | Cannot reference unparsed entities in content |
| **No Recursion** | Entities cannot reference themselves |
| **In DTD** | Parameter entity references only in DTD |

### Attribute Constraints

| Constraint | Description |
|------------|-------------|
| **No External Entity References** | Attribute values cannot contain external entity refs |
| **No < in Attribute Values** | Neither directly nor via entity expansion |

### Character Constraints

| Constraint | Description |
|------------|-------------|
| **Legal Character** | Character references must match Char production |

### DTD Constraints

| Constraint | Description |
|------------|-------------|
| **External Subset** | External subset must match extSubset production |
| **PE Between Declarations** | Parameter entities in DeclSep must match extSubsetDecl |
| **PEs in Internal Subset** | Parameter entity refs cannot be inside markup declarations |
| **Proper Group/PE Nesting** | Parameter entity text must be properly nested with groups |

---

## 13. Validity Constraints (VC)

### Element Validation

| Constraint | Description |
|------------|-------------|
| **Root Element Type** | Root element must match DOCTYPE name |
| **Element Valid** | Element content must match declared content model |
| **Unique Element Type Declaration** | Element types declared at most once |

### Attribute Validation

| Constraint | Description |
|------------|-------------|
| **Attribute Value Type** | Value must conform to declared type |
| **Required Attribute** | #REQUIRED attributes must be specified |
| **Attribute Default Value Syntactically Correct** | Default values must match declared type |
| **Fixed Attribute Default** | #FIXED attributes must match default |
| **ID** | ID values must be unique; match Name production |
| **One ID per Element Type** | At most one ID attribute per element type |
| **ID Attribute Default** | ID attributes must be #IMPLIED or #REQUIRED |
| **IDREF** | IDREF values must reference existing IDs |
| **Entity Name** | ENTITY values must reference unparsed entities |
| **Name Token** | NMTOKEN values must match Nmtoken production |
| **Notation Attributes** | Values must match declared notations |
| **One Notation Per Element Type** | At most one NOTATION attribute per element type |
| **No Notation on Empty Element** | NOTATION attributes not allowed on EMPTY elements |
| **No Duplicate Tokens** | Enumeration values must be distinct |
| **Enumeration** | Values must match one of enumerated tokens |

### Entity Validation

| Constraint | Description |
|------------|-------------|
| **Entity Declared** | All referenced entities must be declared |
| **Notation Declared** | NDATA notation must be declared |
| **Unique Notation Name** | Notation names declared at most once |

---

## 14. Attribute Normalization

### Normalization Process (Section 3.3.3)

**Step 1: Line Break Normalization**
- All line breaks already normalized to `#xA`

**Step 2: Per-Character Processing**

| Input | Action |
|-------|--------|
| Character reference | Append referenced character |
| Entity reference | Recursively process replacement text |
| Whitespace (`#x20`, `#x9`, `#xD`, `#xA`) | Append `#x20` |
| Other character | Append as-is |

**Step 3: Post-Processing (Non-CDATA types only)**
- Strip leading and trailing `#x20`
- Collapse sequences of `#x20` to single `#x20`

### Normalization by Type

| Attribute Type | Whitespace Handling | Post-Processing |
|----------------|--------------------|-----------------|
| CDATA | Convert to space | None |
| All others | Convert to space | Trim and collapse |

### Example

Given `<!ENTITY d "&#xD;">` and attribute `a`:

| Declaration | Input | Normalized Value |
|-------------|-------|------------------|
| `CDATA` | `"  x  y  "` | `"  x  y  "` |
| `NMTOKENS` | `"  x  y  "` | `"x y"` |
| `CDATA` | `"x&d;y"` | `"x#xDy"` (CR preserved via char ref) |

---

## 15. Character Encoding

### Required Encodings

All XML processors MUST support:
- **UTF-8**
- **UTF-16** (with BOM)

### Encoding Declaration [Production 80]

```ebnf
[80] EncodingDecl ::= S 'encoding' Eq ('"' EncName '"' | "'" EncName "'")
[81] EncName      ::= [A-Za-z] ([A-Za-z0-9._] | '-')*
```

### Common Encoding Names

| Encoding | Names |
|----------|-------|
| Unicode | UTF-8, UTF-16, UTF-16BE, UTF-16LE |
| ISO Latin | ISO-8859-1 through ISO-8859-15 |
| Japanese | Shift_JIS, EUC-JP, ISO-2022-JP |
| Chinese | GB2312, GBK, GB18030, Big5 |
| Other | Windows-1252, KOI8-R, etc. |

### BOM Detection (Byte Order Mark)

| Bytes | Encoding |
|-------|----------|
| `EF BB BF` | UTF-8 (optional BOM) |
| `FE FF` | UTF-16 Big-Endian |
| `FF FE` | UTF-16 Little-Endian |
| `00 00 FE FF` | UTF-32 Big-Endian |
| `FF FE 00 00` | UTF-32 Little-Endian |

### Text Declaration [Production 77]

For external parsed entities:

```ebnf
[77] TextDecl ::= '<?xml' VersionInfo? EncodingDecl S? '?>'
```

Required for external entities not in UTF-8 or UTF-16.

---

## 16. Processor Conformance

### Validating Processors

**MUST**:
- Check well-formedness of document entity and all parsed entities
- Report well-formedness and validity constraint violations
- Read and process entire DTD and all external parsed entities
- Normalize attribute values per declarations
- Supply default attribute values

### Non-Validating Processors

**MUST**:
- Check well-formedness of document entity (including internal DTD subset)
- Process declarations in internal subset
- Normalize attributes using declarations read
- Supply defaults from declarations read

**MAY**:
- Read external entities
- Check validity constraints

### Information Passed to Application

Processors MUST pass to application:
- All characters in document that are not markup
- Character references resolved to characters
- Entity reference replacements (for internal entities)

---

## 17. Complete Production Rules

### Document

```ebnf
[1]  document     ::= prolog element Misc*
[22] prolog       ::= XMLDecl? Misc* (doctypedecl Misc*)?
[23] XMLDecl      ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
[24] VersionInfo  ::= S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
[25] Eq           ::= S? '=' S?
[26] VersionNum   ::= '1.' [0-9]+
[27] Misc         ::= Comment | PI | S
[32] SDDecl       ::= S 'standalone' Eq (("'" ('yes'|'no') "'") | ('"' ('yes'|'no') '"'))
```

### Characters

```ebnf
[2]  Char         ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
[3]  S            ::= (#x20 | #x9 | #xD | #xA)+
[4]  NameStartChar ::= ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
[4a] NameChar     ::= NameStartChar | "-" | "." | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
[5]  Name         ::= NameStartChar (NameChar)*
[6]  Names        ::= Name (#x20 Name)*
[7]  Nmtoken      ::= (NameChar)+
[8]  Nmtokens     ::= Nmtoken (#x20 Nmtoken)*
```

### Literals

```ebnf
[9]  EntityValue   ::= '"' ([^%&"] | PEReference | Reference)* '"' | "'" ([^%&'] | PEReference | Reference)* "'"
[10] AttValue      ::= '"' ([^<&"] | Reference)* '"' | "'" ([^<&'] | Reference)* "'"
[11] SystemLiteral ::= ('"' [^"]* '"') | ("'" [^']* "'")
[12] PubidLiteral  ::= '"' PubidChar* '"' | "'" (PubidChar - "'")* "'"
[13] PubidChar     ::= #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
```

### Character Data and Markup

```ebnf
[14] CharData ::= [^<&]* - ([^<&]* ']]>' [^<&]*)
[15] Comment  ::= '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
[16] PI       ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
[17] PITarget ::= Name - (('X'|'x') ('M'|'m') ('L'|'l'))
```

### CDATA

```ebnf
[18] CDSect  ::= CDStart CData CDEnd
[19] CDStart ::= '<![CDATA['
[20] CData   ::= (Char* - (Char* ']]>' Char*))
[21] CDEnd   ::= ']]>'
```

### DTD

```ebnf
[28]  doctypedecl    ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
[28a] DeclSep        ::= PEReference | S
[28b] intSubset      ::= (markupdecl | DeclSep)*
[29]  markupdecl     ::= elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment
[30]  extSubset      ::= TextDecl? extSubsetDecl
[31]  extSubsetDecl  ::= (markupdecl | conditionalSect | DeclSep)*
```

### Elements

```ebnf
[39] element      ::= EmptyElemTag | STag content ETag
[40] STag         ::= '<' Name (S Attribute)* S? '>'
[41] Attribute    ::= Name Eq AttValue
[42] ETag         ::= '</' Name S? '>'
[43] content      ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
[44] EmptyElemTag ::= '<' Name (S Attribute)* S? '/>'
```

### Element Declarations

```ebnf
[45] elementdecl ::= '<!ELEMENT' S Name S contentspec S? '>'
[46] contentspec ::= 'EMPTY' | 'ANY' | Mixed | children
[47] children    ::= (choice | seq) ('?' | '*' | '+')?
[48] cp          ::= (Name | choice | seq) ('?' | '*' | '+')?
[49] choice      ::= '(' S? cp (S? '|' S? cp)+ S? ')'
[50] seq         ::= '(' S? cp (S? ',' S? cp)* S? ')'
[51] Mixed       ::= '(' S? '#PCDATA' (S? '|' S? Name)* S? ')*' | '(' S? '#PCDATA' S? ')'
```

### Attribute Declarations

```ebnf
[52] AttlistDecl    ::= '<!ATTLIST' S Name AttDef* S? '>'
[53] AttDef         ::= S Name S AttType S DefaultDecl
[54] AttType        ::= StringType | TokenizedType | EnumeratedType
[55] StringType     ::= 'CDATA'
[56] TokenizedType  ::= 'ID' | 'IDREF' | 'IDREFS' | 'ENTITY' | 'ENTITIES' | 'NMTOKEN' | 'NMTOKENS'
[57] EnumeratedType ::= NotationType | Enumeration
[58] NotationType   ::= 'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')'
[59] Enumeration    ::= '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'
[60] DefaultDecl    ::= '#REQUIRED' | '#IMPLIED' | (('#FIXED' S)? AttValue)
```

### Conditional Sections

```ebnf
[61] conditionalSect    ::= includeSect | ignoreSect
[62] includeSect        ::= '<![' S? 'INCLUDE' S? '[' extSubsetDecl ']]>'
[63] ignoreSect         ::= '<![' S? 'IGNORE' S? '[' ignoreSectContents* ']]>'
[64] ignoreSectContents ::= Ignore ('<![' ignoreSectContents ']]>' Ignore)*
[65] Ignore             ::= Char* - (Char* ('<![' | ']]>') Char*)
```

### References

```ebnf
[66] CharRef     ::= '&#' [0-9]+ ';' | '&#x' [0-9a-fA-F]+ ';'
[67] Reference   ::= EntityRef | CharRef
[68] EntityRef   ::= '&' Name ';'
[69] PEReference ::= '%' Name ';'
```

### Entity Declarations

```ebnf
[70] EntityDecl ::= GEDecl | PEDecl
[71] GEDecl     ::= '<!ENTITY' S Name S EntityDef S? '>'
[72] PEDecl     ::= '<!ENTITY' S '%' S Name S PEDef S? '>'
[73] EntityDef  ::= EntityValue | (ExternalID NDataDecl?)
[74] PEDef      ::= EntityValue | ExternalID
[75] ExternalID ::= 'SYSTEM' S SystemLiteral | 'PUBLIC' S PubidLiteral S SystemLiteral
[76] NDataDecl  ::= S 'NDATA' S Name
```

### Text Declaration and Encoding

```ebnf
[77] TextDecl     ::= '<?xml' VersionInfo? EncodingDecl S? '?>'
[78] extParsedEnt ::= TextDecl? content
[80] EncodingDecl ::= S 'encoding' Eq ('"' EncName '"' | "'" EncName "'")
[81] EncName      ::= [A-Za-z] ([A-Za-z0-9._] | '-')*
```

### Notation Declarations

```ebnf
[82] NotationDecl ::= '<!NOTATION' S Name S (ExternalID | PublicID) S? '>'
[83] PublicID     ::= 'PUBLIC' S PubidLiteral
```

---

## 18. Predefined Entities

These entities are recognized without declaration:

| Entity | Character | Code Point | Usage |
|--------|-----------|------------|-------|
| `&lt;` | `<` | U+003C | Less-than sign |
| `&gt;` | `>` | U+003E | Greater-than sign |
| `&amp;` | `&` | U+0026 | Ampersand |
| `&apos;` | `'` | U+0027 | Apostrophe |
| `&quot;` | `"` | U+0022 | Quotation mark |

### Declaration Requirements (for validity)

If declared, `lt` and `amp` MUST use character references:

```xml
<!ENTITY lt   "&#60;">
<!ENTITY gt   "&#62;">
<!ENTITY amp  "&#38;">
<!ENTITY apos "&#39;">
<!ENTITY quot "&#34;">
```

---

## 19. Reserved Names

### Reserved Prefixes

Names beginning with `xml` (case-insensitive) are reserved:

| Name | Purpose |
|------|---------|
| `xml:lang` | Language identification (BCP 47 tags) |
| `xml:space` | Whitespace handling (`default` or `preserve`) |
| `xml:base` | Base URI (separate spec) |
| `xml:id` | Unique identifier (separate spec) |

### Reserved Processing Instruction Targets

The PI target `xml` (case-insensitive) is reserved for XML declarations.

---

## 20. Error Classification

### Fatal Errors

**Definition**: Errors that MUST be detected and reported. Processor MUST NOT continue normal processing.

Examples:
- Well-formedness constraint violations
- Invalid character data
- Mismatched tags
- Duplicate attributes
- Invalid entity references

### Errors

**Definition**: Violations that processors MAY recover from.

Examples:
- Validity constraint violations (for validating processors)
- Discouraged characters
- Non-deterministic content models

### Warnings

**Definition**: Conditions that processors MAY report at user option.

Examples:
- Undeclared entities (non-validating)
- Use of discouraged characters
- External entity not found

---

## References

- **XML 1.0 (Fifth Edition)**: https://www.w3.org/TR/xml/
- **Namespaces in XML 1.0 (Third Edition)**: https://www.w3.org/TR/xml-names/
- **xml:id Version 1.0**: https://www.w3.org/TR/xml-id/
- **xml:base**: https://www.w3.org/TR/xmlbase/
- **Unicode**: https://www.unicode.org/
- **IETF BCP 47**: https://tools.ietf.org/html/bcp47

---

## Quick Reference Card

### Valid XML Document Checklist

- [ ] Begins with XML declaration (recommended)
- [ ] Has exactly one root element
- [ ] All elements properly nested and closed
- [ ] All attribute values quoted
- [ ] No `<` in attribute values
- [ ] No duplicate attributes
- [ ] All entity references declared or predefined
- [ ] All characters are valid XML characters
- [ ] No `--` in comments
- [ ] No `]]>` in character data

### Common Entity Escapes

| Character | Entity | Char Ref |
|-----------|--------|----------|
| `<` | `&lt;` | `&#60;` |
| `>` | `&gt;` | `&#62;` |
| `&` | `&amp;` | `&#38;` |
| `'` | `&apos;` | `&#39;` |
| `"` | `&quot;` | `&#34;` |

### Content Model Quick Reference

| Pattern | Meaning |
|---------|---------|
| `EMPTY` | No content |
| `ANY` | Any content |
| `(#PCDATA)` | Text only |
| `(a,b)` | a then b |
| `(a\|b)` | a or b |
| `a?` | 0 or 1 |
| `a*` | 0 or more |
| `a+` | 1 or more |
