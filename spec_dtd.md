# XML DTD (Document Type Definition) Specification Reference

A comprehensive reference for XML Document Type Definitions based on W3C XML 1.0.

## Overview

A DTD defines the legal structure of an XML document:
- Which elements can appear
- What attributes elements can have
- What content elements can contain
- Default and fixed attribute values
- Entity definitions for text substitution

## Document Type Declaration

The DOCTYPE declaration connects an XML document to its DTD.

### Syntax

```
doctypedecl ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
```

### Forms

```xml
<!-- Internal subset only -->
<!DOCTYPE root [
  <!ELEMENT root (#PCDATA)>
]>

<!-- External subset only (SYSTEM) -->
<!DOCTYPE root SYSTEM "root.dtd">

<!-- External subset only (PUBLIC) -->
<!DOCTYPE root PUBLIC "-//Example//DTD Root//EN" "root.dtd">

<!-- Both external and internal -->
<!DOCTYPE root SYSTEM "root.dtd" [
  <!ENTITY copyright "2024 Example Corp">
]>
```

### Processing Order

1. External subset is processed first (if present)
2. Internal subset is processed second
3. Internal declarations take precedence over external

---

## Element Declarations

Element declarations define what elements can appear and their content models.

### Syntax

```
elementdecl ::= '<!ELEMENT' S Name S contentspec '>'
contentspec ::= 'EMPTY' | 'ANY' | Mixed | children
```

### Content Types

| Type | Syntax | Description |
|------|--------|-------------|
| EMPTY | `<!ELEMENT br EMPTY>` | No content allowed |
| ANY | `<!ELEMENT container ANY>` | Any content allowed |
| #PCDATA | `<!ELEMENT p (#PCDATA)>` | Text only |
| Mixed | `<!ELEMENT p (#PCDATA\|em\|strong)*>` | Text and specified elements |
| Children | `<!ELEMENT doc (head, body)>` | Element content only |

### Content Model Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `,` | Sequence (in order) | `(a, b, c)` - a then b then c |
| `\|` | Choice (one of) | `(a \| b \| c)` - a or b or c |
| `?` | Optional (0 or 1) | `a?` - zero or one a |
| `*` | Zero or more | `a*` - any number of a |
| `+` | One or more | `a+` - at least one a |
| `()` | Grouping | `(a, b)+` - sequence repeats |

### Examples

```xml
<!-- Empty element -->
<!ELEMENT br EMPTY>
<!ELEMENT img EMPTY>

<!-- Text only -->
<!ELEMENT title (#PCDATA)>

<!-- Mixed content (text and elements) -->
<!ELEMENT paragraph (#PCDATA | bold | italic)*>

<!-- Element sequence -->
<!ELEMENT letter (greeting, body, signature)>

<!-- Choice -->
<!ELEMENT payment (cash | credit | check)>

<!-- Complex model -->
<!ELEMENT chapter (title, (paragraph | figure | table)+, footnote*)>

<!-- Optional elements -->
<!ELEMENT person (name, address?, phone*)>

<!-- Nested groups -->
<!ELEMENT recipe (title, (ingredients, steps)+, notes?)>
```

### Validity Constraints

**VC: Unique Element Type Declaration**
- An element type must not be declared more than once

**VC: Proper Group/PE Nesting**
- Parameter entity replacement text must be properly nested with parentheses

---

## Attribute Declarations

Attribute declarations define what attributes an element can have.

### Syntax

```
AttlistDecl ::= '<!ATTLIST' S Name AttDef* S? '>'
AttDef      ::= S Name S AttType S DefaultDecl
```

### Attribute Types

| Type | Description | Example |
|------|-------------|---------|
| CDATA | Character data (any text) | `<!ATTLIST el attr CDATA #IMPLIED>` |
| ID | Unique identifier | `<!ATTLIST el id ID #REQUIRED>` |
| IDREF | Reference to ID | `<!ATTLIST el ref IDREF #IMPLIED>` |
| IDREFS | Space-separated ID references | `<!ATTLIST el refs IDREFS #IMPLIED>` |
| ENTITY | Entity name | `<!ATTLIST el ent ENTITY #IMPLIED>` |
| ENTITIES | Space-separated entity names | `<!ATTLIST el ents ENTITIES #IMPLIED>` |
| NMTOKEN | Name token | `<!ATTLIST el tok NMTOKEN #IMPLIED>` |
| NMTOKENS | Space-separated name tokens | `<!ATTLIST el toks NMTOKENS #IMPLIED>` |
| NOTATION | Notation name | `<!ATTLIST el not NOTATION (gif\|jpg) #IMPLIED>` |
| Enumeration | One of listed values | `<!ATTLIST el size (small\|medium\|large) "medium">` |

### Default Declarations

| Declaration | Meaning |
|-------------|---------|
| `#REQUIRED` | Attribute must be specified |
| `#IMPLIED` | Attribute is optional, no default |
| `#FIXED "value"` | Attribute has fixed value (can be omitted) |
| `"value"` | Default value if not specified |

### Examples

```xml
<!-- Required attribute -->
<!ATTLIST img src CDATA #REQUIRED>

<!-- Optional attribute -->
<!ATTLIST img alt CDATA #IMPLIED>

<!-- Default value -->
<!ATTLIST table border CDATA "1">

<!-- Fixed value -->
<!ATTLIST html xmlns CDATA #FIXED "http://www.w3.org/1999/xhtml">

<!-- ID attribute -->
<!ATTLIST element id ID #IMPLIED>

<!-- IDREF attribute -->
<!ATTLIST link href IDREF #REQUIRED>

<!-- Enumeration -->
<!ATTLIST input type (text|password|checkbox|radio|submit) "text">

<!-- Multiple attributes -->
<!ATTLIST img
    src    CDATA    #REQUIRED
    alt    CDATA    #IMPLIED
    width  CDATA    #IMPLIED
    height CDATA    #IMPLIED
    class  NMTOKENS #IMPLIED
>
```

### Validity Constraints

**VC: ID**
- ID values must be unique within the document
- An element may have at most one ID attribute

**VC: IDREF**
- IDREF values must match an ID value in the document

**VC: Attribute Default Value Syntactically Correct**
- Default values must match the declared type

**VC: Enumeration**
- Attribute value must match one of the enumerated values

---

## Entity Declarations

Entities provide text substitution mechanisms.

### General Entities

Used in document content with `&name;` syntax.

```
EntityDecl  ::= GEDecl | PEDecl
GEDecl      ::= '<!ENTITY' S Name S EntityDef S? '>'
EntityDef   ::= EntityValue | (ExternalID NDataDecl?)
```

#### Internal General Entities

```xml
<!ENTITY copyright "Copyright 2024 Example Corp.">
<!ENTITY author "John Smith">
<!ENTITY warning "WARNING: This is experimental.">

<!-- Usage in document -->
<footer>&copyright; by &author;</footer>
```

#### External General Entities

```xml
<!-- Parsed external entity (XML content) -->
<!ENTITY chapter1 SYSTEM "chapter1.xml">

<!-- Unparsed external entity (binary data) -->
<!ENTITY logo SYSTEM "logo.png" NDATA png>

<!-- Public identifier -->
<!ENTITY boilerplate PUBLIC "-//Example//TEXT Boilerplate//EN" "boilerplate.xml">
```

### Parameter Entities

Used in DTD only with `%name;` syntax.

```
PEDecl     ::= '<!ENTITY' S '%' S Name S PEDef S? '>'
PEDef      ::= EntityValue | ExternalID
```

#### Internal Parameter Entities

```xml
<!-- Define reusable content model -->
<!ENTITY % inline "em | strong | code | a">
<!ENTITY % block "p | div | ul | ol">

<!-- Use in element declarations -->
<!ELEMENT p (#PCDATA | %inline;)*>
<!ELEMENT div (%block;)+>

<!-- Define reusable attributes -->
<!ENTITY % common.attrs "
    id    ID       #IMPLIED
    class NMTOKENS #IMPLIED
    style CDATA    #IMPLIED
">

<!ATTLIST p %common.attrs;>
<!ATTLIST div %common.attrs;>
```

#### External Parameter Entities

```xml
<!-- Import external DTD module -->
<!ENTITY % html-entities SYSTEM "html-entities.dtd">
%html-entities;

<!-- Conditional sections -->
<!ENTITY % draft "INCLUDE">
<!ENTITY % final "IGNORE">
```

### Predefined Entities

These entities are built-in and need not be declared:

| Entity | Character | Description |
|--------|-----------|-------------|
| `&lt;` | `<` | Less than |
| `&gt;` | `>` | Greater than |
| `&amp;` | `&` | Ampersand |
| `&apos;` | `'` | Apostrophe |
| `&quot;` | `"` | Quotation mark |

### Character References

```xml
&#60;      <!-- Decimal: < -->
&#x3C;     <!-- Hexadecimal: < -->
&#169;     <!-- Copyright symbol -->
&#x2022;   <!-- Bullet point -->
```

### Validity Constraints

**VC: Entity Declared**
- General entities must be declared before use

**WFC: Parsed Entity**
- Entity replacement text must be well-formed

**WFC: No Recursion**
- Entities must not contain references to themselves (directly or indirectly)

---

## Notation Declarations

Notations identify non-XML data formats.

### Syntax

```
NotationDecl ::= '<!NOTATION' S Name S (ExternalID | PublicID) S? '>'
```

### Examples

```xml
<!-- Image formats -->
<!NOTATION gif SYSTEM "image/gif">
<!NOTATION png SYSTEM "image/png">
<!NOTATION jpg PUBLIC "-//JPEG//NOTATION JPEG//EN" "image/jpeg">

<!-- Application formats -->
<!NOTATION pdf SYSTEM "application/pdf">

<!-- Used with unparsed entities -->
<!ENTITY logo SYSTEM "logo.png" NDATA png>

<!-- Used with NOTATION attributes -->
<!ATTLIST image format NOTATION (gif | png | jpg) #REQUIRED>
```

---

## Conditional Sections

Conditional sections allow including or excluding parts of the DTD.

### Syntax

```
conditionalSect ::= includeSect | ignoreSect
includeSect     ::= '<![' S? 'INCLUDE' S? '[' extSubsetDecl ']]>'
ignoreSect      ::= '<![' S? 'IGNORE' S? '[' ignoreSectContents* ']]>'
```

### Examples

```xml
<!-- Direct usage -->
<![INCLUDE[
  <!ELEMENT draft-note (#PCDATA)>
]]>

<![IGNORE[
  <!ELEMENT deprecated (#PCDATA)>
]]>

<!-- Parameterized (common pattern) -->
<!ENTITY % include-extensions "INCLUDE">

<![%include-extensions;[
  <!ELEMENT extension (#PCDATA)>
]]>
```

---

## Complete DTD Example

```xml
<!-- book.dtd -->

<!-- Parameter entities for reuse -->
<!ENTITY % text "#PCDATA | em | strong">
<!ENTITY % common.attrs "
    id    ID       #IMPLIED
    class CDATA    #IMPLIED
">

<!-- Root element -->
<!ELEMENT book (title, author+, chapter+)>
<!ATTLIST book
    isbn   CDATA    #REQUIRED
    lang   CDATA    "en"
    %common.attrs;
>

<!-- Metadata -->
<!ELEMENT title (#PCDATA)>
<!ELEMENT author (#PCDATA)>
<!ATTLIST author
    email CDATA #IMPLIED
>

<!-- Content structure -->
<!ELEMENT chapter (heading, (paragraph | figure | note)+)>
<!ATTLIST chapter
    %common.attrs;
>

<!ELEMENT heading (#PCDATA)>
<!ELEMENT paragraph (%text;)*>
<!ELEMENT note (%text;)*>
<!ATTLIST note
    type (info | warning | tip) "info"
>

<!-- Inline elements -->
<!ELEMENT em (#PCDATA)>
<!ELEMENT strong (#PCDATA)>

<!-- Figures -->
<!ELEMENT figure (image, caption?)>
<!ELEMENT image EMPTY>
<!ATTLIST image
    src    CDATA #REQUIRED
    alt    CDATA #IMPLIED
    width  CDATA #IMPLIED
    height CDATA #IMPLIED
>
<!ELEMENT caption (#PCDATA)>

<!-- Common entities -->
<!ENTITY copyright "All rights reserved.">
<!ENTITY mdash "&#x2014;">
```

### Using the DTD

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE book SYSTEM "book.dtd">
<book isbn="978-0-123456-78-9">
  <title>XML Fundamentals</title>
  <author email="author@example.com">Jane Doe</author>
  <chapter id="ch1">
    <heading>Introduction</heading>
    <paragraph>Welcome to <em>XML</em>.</paragraph>
    <note type="tip">Start with the basics.</note>
  </chapter>
</book>
```

---

## Validation Summary

### Well-Formedness (WFC)

All XML documents must satisfy:
- Proper nesting of elements
- Matching start and end tags
- Unique attribute names per element
- Entity references properly formed

### Validity (VC)

Valid documents additionally must:
- Have a DOCTYPE declaration
- Root element matches DOCTYPE name
- All elements declared in DTD
- Element content matches declared model
- All attributes declared for their elements
- Attribute values match declared types
- Required attributes present
- ID values unique
- IDREF values reference existing IDs
- Entities declared before use

---

## Quick Reference

### Element Content Models

```
EMPTY           - No content
ANY             - Any content
(#PCDATA)       - Text only
(#PCDATA|a|b)*  - Mixed content
(a, b, c)       - Sequence
(a | b | c)     - Choice
a?              - Optional
a*              - Zero or more
a+              - One or more
```

### Attribute Types

```
CDATA           - Any text
ID              - Unique identifier
IDREF/IDREFS    - ID reference(s)
NMTOKEN/NMTOKENS - Name token(s)
ENTITY/ENTITIES - Entity name(s)
NOTATION        - Notation name
(a|b|c)         - Enumeration
```

### Attribute Defaults

```
#REQUIRED       - Must be specified
#IMPLIED        - Optional, no default
#FIXED "val"    - Fixed value
"val"           - Default value
```

### Entity Types

```
<!ENTITY name "value">                    - Internal general
<!ENTITY name SYSTEM "uri">               - External parsed
<!ENTITY name SYSTEM "uri" NDATA type>    - External unparsed
<!ENTITY % name "value">                  - Internal parameter
<!ENTITY % name SYSTEM "uri">             - External parameter
```
