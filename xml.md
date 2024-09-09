# XML cases for going to/from XML

This does not fully follow the XML spec, but should successfully parse XML which conforms to the spec.

Note: UTF-8 has not been tested.

# tags
`<tag></tag>` generates the XML stream:

```
[
  open_tag: [tag: "tag"],
  close_tag: [tag: "tag"]
]
```

`<empty_tag/>` generates the XML stream:
```
[
  open_tag: [tag: "empty_tag"],
  close_tag: [tag: "empty_tag"]
]
```

The parser.exe converts the empty tag form to the _tag open/close_ form int he `parse_next` function.
This is also tested in the `parser_test.exs` file.


## namespaces

`<ns:tag></ns:tag>` and `<ns:tag/>` generate the XML stream:
```
[
  open_tag: [tag: "tag", namespace: "ns"],
  close_tag: [tag: "tag"]
]
```

for NDS, namespace is kept in the `NDS.namespace` field as a binary
(elixir string).  This defaults to the empty string value `""`


## attributes

`<tag attr0="0" attr1="1"></tag>` and `<empty_tag attr0="0" attr1="1"/>` generate the XML stream:
```
[
  open_tag: [tag: "tag", attrs: [attr0: "0", attr1: 1],
  close_tag: [tag: "tag"]
]
```


for NDS, attributes are kept in the `NDS.attr_list` field as a keyword
list.  This allows attributes to convert back to xml with the original
attribute ordering.  The default value for this is an empty list.

## text

<tag>text</tag> geerates the XML stream:
```
[
  open_tag: [tag: "tag"],
  text: ["text"],
  close_tag: [tag: "tag"]
]
```

## combinations

combining all the elements above would look something like the following: 

`<ns:tag attr0="0" attr1="1">text</ns:tag>` which generates the XML stream:
```
[
  open_tag: [tag: "tag", namespace: "ns", attrs: [attr0: "0", attr1: "1"]],
  text: "text",
  close_tag: [tag: "tag"]
]
```
Note, the order of the meta data in open_tag should allways be `[:tag, :namespace, :attrs]`.


# nested tags

the same code used to manage tags above should also be used for each
tag below, so there should not be a need to test nested tags with each
element above

Similarly, since nested tags is a recursive operation there should be
no point in testing tag depth beyond 1 level

## single tag

<tag><n_tag></n_tag></tag>

## list of same name tags

<tag>
  <n_tag></n_tag>
  <n_tag></n_tag>
  <n_tag></n_tag>
</tag>

## list of arbitrary tags

<tag>
  <n_tag></n_tag>
  <m_tag></m_tag>
  <o_tag></o_tag>
</tag>

# nested tags with text

## single tag

<tag>pre-text<n_tag></n_tag></tag>
<tag><n_tag></n_tag>post-text</tag>
<tag>pre-text<n_tag></n_tag>post-text</tag>

## list of same name tags

<tag>
  pre-text
  <n_tag></n_tag>
  <n_tag></n_tag>
  <n_tag></n_tag>
</tag>

<tag>
  <n_tag></n_tag>
  <n_tag></n_tag>
  <n_tag></n_tag>
  post-text
</tag>

<tag>
  pre-text
  <n_tag></n_tag>
  <n_tag></n_tag>
  <n_tag></n_tag>
  post-text
</tag>

<tag>
  pre-text
  <n_tag></n_tag>
  inter-text
  <n_tag></n_tag>
  inter-text
  <n_tag></n_tag>
  post-text
</tag>
