# idl2xmi

A RIDL backend for exporting CORBA IDL declarations as UML XMI.

This is an initial backend skeleton. It registers as `:idl2xmi` and walks the
RIDL AST. The first mapping handles structs and enums; type mapping and broader
IDL3 coverage are intentionally left as follow-up work.

## Requirements

- Ruby supported by the RIDL master branch
- RIDL master

## Setup

```sh
bin/setup
git clone https://github.com/RemedyIT/ridl.git _ridl
export RUBYLIB="$PWD/_ridl/lib${RUBYLIB:+:$RUBYLIB}"
```

Run the generator on an IDL file:

```sh
bundle exec ruby script/idl2xmi.rb examples/basic.idl output.xmi
```

## Test

```sh
bundle exec rake test
```

The golden test runs the script on a small IDL fixture and compares the parsed
XMI tree with a committed expected file. Whitespace and XML attribute order do
not affect the comparison.

## Current mapping

- IDL `struct` declarations become UML `DataType` classifiers.
- Struct members become UML `Property` elements. The original IDL type name is
  retained as a `type` attribute as a starting point for a proper classifier
  reference mapping.
- IDL enums become UML `Enumeration` classifiers. Each enumerator becomes a
  `EnumerationLiteral`; its RIDL ordinal is retained in the `idl2xmi:index`
  attribute.

The output establishes the visitor and serialization flow. It is not yet a
complete UML profile or a complete IDL3 mapping.
