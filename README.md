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
```

For development, expose this checkout as a RIDL backend:

```sh
export RIDL_BE_PATH="$PWD/lib"
bundle exec ridlc :idl2xmi examples/basic.idl
```

Use RIDL's `-o` option to choose an output file. Without it, XMI is written to
standard output.

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
