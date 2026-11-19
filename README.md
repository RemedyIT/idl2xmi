# idl2xmi

A RIDL backend for exporting CORBA IDL declarations as UML XMI.

The backend registers as `:idl2xmi` and walks the RIDL AST with IDL version 4
enabled. It maps the RIDL IDL 4 declaration and type nodes to UML XMI, using
`idl2xmi` profile data where UML has no direct representation.

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
- IDL4 maps, sequences, bounded strings, bitmasks, bitsets, and extended-width
  integer types retain their TAOX11 C++ type spelling; bitmask values and
  bitset fields are represented as enumeration literals and properties.
- IDL3 valuetypes, eventtypes, valueboxes, components, connectors, homes,
  ports, and porttypes are represented as UML classifiers and operations with
  IDL-specific profile attributes. Template modules retain their signature,
  and instantiated modules retain their template and argument references.
- RIDL annotations are retained as nested `idl2xmi:annotation` elements.

The output is an IDL-to-XMI interchange mapping, not a UML profile that makes
all IDL semantics executable in a UML tool. The supported declarations and
types are covered by recursive IDL fixtures and committed XMI goldens.
