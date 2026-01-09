# XML Namespaces 1.0 (Third Edition) - W3C Specification

Source: https://www.w3.org/TR/xml-names/
Status: W3C Recommendation, 8 December 2009

---

## Definitions

### Core Concepts

| Term | Definition |
|------|------------|
| **XML Namespace** | Identified by a URI reference; element and attribute names may be placed in an XML namespace |
| **Expanded Name** | A pair consisting of a namespace name and a local name |
| **Namespace Name** | For a name N in a namespace identified by URI I, the namespace name is I. For a name not in a namespace, the namespace name has no value |
| **Local Name** | The name N itself (without prefix) |
| **Qualified Name (QName)** | A name subject to namespace interpretation, appearing as prefixed or unprefixed |
| **Local Part** | The LocalPart of a qualified name |

### Declaration Concepts

| Term | Definition |
|------|------------|
| **Namespace Declaration** | A reserved attribute whose name is `xmlns` or begins `xmlns:` |
| **Namespace Prefix** | The NCName in a PrefixedAttName (e.g., `foo` in `xmlns:foo`) |
| **Default Namespace** | The namespace name in a `xmlns="..."` attribute value |

### Document Conformance

| Term | Definition |
|------|------------|
| **Namespace-Well-Formed** | A document that conforms to this specification |
| **Namespace-Valid** | A namespace-well-formed document that is also XML 1.0 valid, with all non-element/attribute Name tokens matching NCName |
| **Namespace-Validating Processor** | A validating XML processor that reports namespace validity violations |

---

## Grammar Productions

### Namespace Declaration Attributes

```
[1]  NSAttName      ::= PrefixedAttName | DefaultAttName
[2]  PrefixedAttName ::= 'xmlns:' NCName    [NSC: Reserved Prefixes and Namespace Names]
[3]  DefaultAttName  ::= 'xmlns'
```

### NCName (Non-Colonized Name)

```
[4]  NCName         ::= Name - (Char* ':' Char*)
                        /* An XML Name, minus the ":" */
```

**Note**: NCName is any valid XML Name that contains no colons.

### Qualified Names

```
[7]  QName          ::= PrefixedName | UnprefixedName
[8]  PrefixedName   ::= Prefix ':' LocalPart
[9]  UnprefixedName ::= LocalPart
[10] Prefix         ::= NCName
[11] LocalPart      ::= NCName
```

### Element Tags

```
[12] STag           ::= '<' QName (S Attribute)* S? '>'
                        [NSC: Prefix Declared]

[13] ETag           ::= '</' QName S? '>'
                        [NSC: Prefix Declared]

[14] EmptyElemTag   ::= '<' QName (S Attribute)* S? '/>'
                        [NSC: Prefix Declared]
```

### Attributes

```
[15] Attribute      ::= NSAttName Eq AttValue
                      | QName Eq AttValue
                        [NSC: Prefix Declared]
                        [NSC: No Prefix Undeclaring]
                        [NSC: Attributes Unique]
```

### DTD Declarations (for reference)

```
[16] doctypedecl    ::= '<!DOCTYPE' S QName (S ExternalID)? S? ('[' ... ']' S?)? '>'
[17] elementdecl    ::= '<!ELEMENT' S QName S contentspec S? '>'
[18] cp             ::= (QName | choice | seq) ('?' | '*' | '+')?
[19] Mixed          ::= '(' S? '#PCDATA' (S? '|' S? QName)* S? ')*'
                      | '(' S? '#PCDATA' S? ')'
[20] AttlistDecl    ::= '<!ATTLIST' S QName AttDef* S? '>'
[21] AttDef         ::= S (QName | NSAttName) S AttType S DefaultDecl
```

### Legacy Productions (Appendix F)

```
[5]  NCNameChar      ::= NameChar - ':'
                         /* An XML NameChar, minus the ":" */

[6]  NCNameStartChar ::= NCName - (Char Char Char*)
                         /* The first letter of an NCName */
```

---

## Namespace Constraints (NSC)

### NSC: Reserved Prefixes and Namespace Names

**Applies to**: Production [2] PrefixedAttName

**Rules**:

1. **xml prefix**:
   - Permanently bound to: `http://www.w3.org/XML/1998/namespace`
   - MAY be declared, but MUST NOT be bound to any other namespace
   - Other prefixes MUST NOT be bound to this namespace
   - MUST NOT be declared as default namespace

2. **xmlns prefix**:
   - Permanently bound to: `http://www.w3.org/2000/xmlns/`
   - MUST NOT be declared at all
   - Other prefixes MUST NOT be bound to this namespace
   - Element names MUST NOT have `xmlns` as prefix

3. **Reserved prefix pattern**:
   - Prefixes beginning with `x`, `m`, `l` (any case combination) are reserved
   - Users SHOULD NOT use them
   - Processors MUST NOT treat them as fatal errors

### NSC: Prefix Declared

**Applies to**: Productions [12], [13], [14], [15]

**Rule**: The namespace prefix, unless it is `xml` or `xmlns`, MUST have been declared in a namespace declaration attribute in either:
- The start-tag of the element where the prefix is used, OR
- An ancestor element (within scope)

### NSC: No Prefix Undeclaring

**Applies to**: Production [15] Attribute

**Rule**: In a namespace declaration for a prefix (where NSAttName is a PrefixedAttName), the attribute value MUST NOT be empty.

**Note**: This constraint does NOT apply to default namespace declarations (`xmlns=""`), which ARE allowed to have empty values.

### NSC: Attributes Unique

**Applies to**: Production [15] Attribute

**Rule**: No tag may contain two attributes which:
1. Have identical names, OR
2. Have qualified names with the same local part AND prefixes bound to identical namespace names

**Equivalently**: No element may have two attributes with the same expanded name.

---

## Namespace Scoping Rules

### Prefix Binding Scope

The scope of a namespace declaration declaring a prefix extends:
- **FROM**: The beginning of the start-tag in which it appears
- **TO**: The end of the corresponding end-tag
- **EXCLUDING**: The scope of any inner declarations with the same NSAttName

For empty tags, the scope is the tag itself.

### Default Namespace Scope

The scope of a default namespace declaration extends:
- **FROM**: The beginning of the start-tag in which it appears
- **TO**: The end of the corresponding end-tag
- **EXCLUDING**: The scope of any inner default namespace declarations

For empty tags, the scope is the tag itself.

### What Namespaces Apply To

| Construct | Namespace Applied |
|-----------|-------------------|
| Prefixed element name | URI bound to prefix |
| Unprefixed element name (default NS in scope) | Default namespace URI |
| Unprefixed element name (no default NS) | No namespace (namespace name has no value) |
| Prefixed attribute name | URI bound to prefix |
| Unprefixed attribute name | **No namespace** (never uses default) |
| Namespace declaration attributes | In `http://www.w3.org/2000/xmlns/` namespace |

**Important**: Default namespace declarations do NOT apply directly to attribute names. Unprefixed attributes have no namespace.

---

## Reserved Namespace URIs

| Prefix | Namespace URI | Notes |
|--------|---------------|-------|
| `xml` | `http://www.w3.org/XML/1998/namespace` | Pre-declared, may be redeclared to same URI |
| `xmlns` | `http://www.w3.org/2000/xmlns/` | Pre-declared, MUST NOT be declared |

---

## URI Comparison Rules

Namespace URIs are compared as **character strings**:
- Comparison is **case-sensitive**
- No %-escaping normalization is applied
- No URI dereferencing or semantic comparison

**Examples of DIFFERENT namespaces** (case variations):
```
http://www.example.org/wine
http://www.Example.org/wine
http://www.example.org/Wine
```

**Examples of DIFFERENT namespaces** (%-escaping variations):
```
http://www.example.org/~wilbur
http://www.example.org/%7ewilbur
http://www.example.org/%7Ewilbur
```

**Recommendation**: Use of %-escaped characters in namespace names is strongly discouraged.

---

## Expanded Name Resolution

### Algorithm for Elements

```
function expand_element_name(qname, context):
    if qname contains ':'
        (prefix, local) = split_on_first_colon(qname)
        uri = lookup_prefix(prefix, context)
        if uri is None:
            ERROR: NSC Prefix Declared violation
        return (uri, local)
    else
        local = qname
        uri = get_default_namespace(context)  # may be None
        return (uri, local)
```

### Algorithm for Attributes

```
function expand_attribute_name(qname, context):
    if qname starts with 'xmlns:' or qname == 'xmlns':
        # Namespace declaration - special handling
        return (XMLNS_NAMESPACE, qname)

    if qname contains ':'
        (prefix, local) = split_on_first_colon(qname)
        uri = lookup_prefix(prefix, context)
        if uri is None:
            ERROR: NSC Prefix Declared violation
        return (uri, local)
    else
        # Unprefixed attributes have NO namespace
        return (None, qname)
```

---

## Document Conformance Requirements

A document is **namespace-well-formed** if:

1. It is well-formed according to XML 1.0
2. All element names match the QName production
3. All attribute names match the QName production (or NSAttName for declarations)
4. All namespace constraints are satisfied
5. All other Name tokens (entities, PIs, notations) match NCName

**Consequences**:
- Element and attribute names contain zero or one colon
- Entity names contain no colons
- Processing instruction targets contain no colons
- Notation names contain no colons

---

## Processor Conformance Requirements

A conforming processor MUST:
1. Report violations of namespace well-formedness
2. Recognize and act on namespace declarations and prefixes

A conforming processor is NOT required to:
- Validate that namespace names are legal URI references

A **namespace-validating** processor additionally:
- Reports violations of namespace validity

---

## Error Conditions

| Error | Constraint Violated | Description |
|-------|---------------------|-------------|
| Undeclared prefix | NSC: Prefix Declared | Using prefix without declaration |
| Empty prefix binding | NSC: No Prefix Undeclaring | `xmlns:foo=""` in NS 1.0 |
| Duplicate attribute | NSC: Attributes Unique | Two attrs with same expanded name |
| Invalid xml prefix binding | NSC: Reserved Prefixes | Binding xml to wrong URI |
| xmlns prefix declared | NSC: Reserved Prefixes | Any declaration of xmlns prefix |
| Wrong binding to xml namespace | NSC: Reserved Prefixes | Non-xml prefix bound to xml namespace |
| Wrong binding to xmlns namespace | NSC: Reserved Prefixes | Any prefix bound to xmlns namespace |
| Invalid QName | Grammar | Name not matching QName production |
| Invalid NCName | Grammar | Colon in entity/PI/notation name |

---

## Examples

### Valid: Simple Prefixed Namespace

```xml
<edi:price xmlns:edi='http://ecommerce.example.org/schema' units='Euro'>32.18</edi:price>
```

- Element `edi:price` has expanded name: `(http://ecommerce.example.org/schema, price)`
- Attribute `units` has expanded name: `(None, units)`

### Valid: Default Namespace

```xml
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head><title>Test</title></head>
</html>
```

- Element `html` has expanded name: `(http://www.w3.org/1999/xhtml, html)`
- Element `head` has expanded name: `(http://www.w3.org/1999/xhtml, head)`

### Valid: Mixed Prefixed and Default

```xml
<book xmlns='urn:loc.gov:books' xmlns:isbn='urn:ISBN:0-395-36341-6'>
    <title>Cheaper by the Dozen</title>
    <isbn:number>1568491379</isbn:number>
</book>
```

- `book` expanded: `(urn:loc.gov:books, book)`
- `title` expanded: `(urn:loc.gov:books, title)`
- `isbn:number` expanded: `(urn:ISBN:0-395-36341-6, number)`

### Valid: Undeclaring Default Namespace

```xml
<root xmlns='http://example.org'>
  <child xmlns=''>
    <!-- child is NOT in any namespace -->
  </child>
</root>
```

### Invalid: Duplicate Expanded Attribute Names

```xml
<x xmlns:n1="http://www.w3.org" xmlns:n2="http://www.w3.org">
  <bad n1:a="1" n2:a="2"/>  <!-- ERROR: same expanded name -->
</x>
```

### Invalid: Undeclared Prefix

```xml
<foo:bar/>  <!-- ERROR: prefix 'foo' not declared -->
```

### Invalid: Empty Prefix Binding (NS 1.0)

```xml
<x xmlns:foo="">  <!-- ERROR: cannot undeclare prefix in NS 1.0 -->
</x>
```

### Valid: Unprefixed Attribute Different from Prefixed

```xml
<x xmlns:n1="http://www.w3.org" xmlns="http://www.w3.org">
  <good a="1" n1:a="2"/>  <!-- VALID: different expanded names -->
</x>
```

- `a` expanded: `(None, a)`
- `n1:a` expanded: `(http://www.w3.org, a)`

---

## Implementation Checklist

### Parser Requirements

- [ ] Parse QNames (split prefix:local)
- [ ] Validate NCName production (no colons in local parts)
- [ ] Track namespace context stack
- [ ] Resolve prefixed names to expanded names
- [ ] Apply default namespace to unprefixed elements
- [ ] Leave unprefixed attributes without namespace

### Validation Requirements

- [ ] NSC: Prefix Declared - all prefixes must be bound
- [ ] NSC: No Prefix Undeclaring - `xmlns:prefix=""` is error
- [ ] NSC: Attributes Unique - no duplicate expanded names
- [ ] NSC: Reserved Prefixes - xml/xmlns rules enforced
- [ ] NCName validation for entity/PI/notation names

### Context Management

- [ ] Push new context on element open
- [ ] Pop context on element close
- [ ] Inherit parent bindings
- [ ] Override with local declarations
- [ ] Pre-bind `xml` prefix

---

## References

- [XML 1.0](https://www.w3.org/TR/xml/) - Base XML specification
- [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) - URI syntax
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) - Requirement level keywords
