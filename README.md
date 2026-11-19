# idl2xmi

A RIDL backend for exporting CORBA IDL declarations as UML XMI.

The backend registers as `:idl2xmi` and walks the RIDL AST. It currently maps
modules, constants, interfaces, structs, enums, unions, arrays, and basic IDL
types, and exceptions to UML XMI.

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

The golden test recursively finds IDL files under `test/fixtures` and compares
each generated XMI tree with the corresponding file under `test/golden`, keeping
the same relative path. Whitespace and XML attribute order do not affect the
comparison. If a golden file is missing, the test prints the generated XMI so
it can be committed as the expected output.

Regenerate all committed golden files with the backend itself:

```sh
bundle exec ruby script/update_golden.rb
```

## Current mapping

- IDL `struct` declarations become UML `DataType` classifiers.
- Modules become UML `Package` elements, and structs become UML `DataType`
  classifiers with `Property` elements for their members.
- Constants become static, read-only UML properties. Interfaces become UML
  interfaces with generalizations, operations, parameters, and attributes.
- Exceptions become UML `DataType` classifiers. Operation `raises` references
  use UML's `raisedException`; attribute `getraises` and `setraises` are kept
  as `idl2xmi` profile attributes.
- Fixed-size IDL arrays use nested `std::array` type names.
- Basic IDL types use TAOX11 `cxx_type` spellings. RIDL master does not load
  TAOX11's type extensions, so the backend provides the same mappings for
  standalone use, including bounded strings and fixed point types.
- IDL enums become UML `Enumeration` classifiers. Each enumerator becomes a
  `EnumerationLiteral`; its RIDL ordinal is retained in the `idl2xmi:index`
  attribute.
- IDL unions become UML `DataType` classifiers with a discriminator type and
  properties whose `idl2xmi:labels` attribute records the case labels.

The output is not yet a complete UML profile or a complete IDL3 mapping.
