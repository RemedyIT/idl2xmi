# idl2xmi

A RIDL backend for exporting CORBA IDL declarations as UML XMI.

The backend registers as `:idl2xmi` and walks the RIDL AST. It currently maps
modules, structs, enums, unions, and basic IDL types to UML XMI.

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

Regenerate all committed golden files with the backend itself:

```sh
bundle exec ruby script/update_golden.rb
```

## Current mapping

- IDL `struct` declarations become UML `DataType` classifiers.
- Modules become UML `Package` elements, and structs become UML `DataType`
  classifiers with `Property` elements for their members.
- Basic IDL types use TAOX11 `cxx_type` spellings. RIDL master does not load
  TAOX11's type extensions, so the backend provides the same mappings for
  standalone use, including bounded strings and fixed point types.
- IDL enums become UML `Enumeration` classifiers. Each enumerator becomes a
  `EnumerationLiteral`; its RIDL ordinal is retained in the `idl2xmi:index`
  attribute.
- IDL unions become UML `DataType` classifiers with a discriminator type and
  properties whose `idl2xmi:labels` attribute records the case labels.

The output is not yet a complete UML profile or a complete IDL3 mapping.
