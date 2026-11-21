# idl2xmi

A RIDL backend for exporting CORBA IDL declarations as OMG UML XMI.

The backend registers as `:idl2xmi` and walks the RIDL AST with IDL version 4
enabled. By default it applies the OMG UML Profile for CORBA and CORBA
Components (CCCMP) 1.0. IDL 4 constructs absent from CCCMP are kept in a
separate `IDL4` extension profile so that non-standard mappings are explicit.

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

## Standards mapping

- The UML model is serialized as XMI 2.5.1.
- Classic CORBA IDL uses the normative CCCMP `BaseIDL` profile.
- CORBA Component Model declarations use CCCMP `ComponentIDL` where defined.
- UML `type` attributes reference UML classifiers. A `CORBA` package contains
  the CCCMP primitive `DataType` classifiers; C++ spellings are not used as
  model type identities.
- Anonymous template types (e.g. `fixed<8, 2>`) and template arguments are
  named with their IDL spelling.
- `xmi:id`s are stable and collision free: `idl2xmi-` plus the scoped name
  with `::` written as `.` for declarations (`idl2xmi-M.S.field`), the owner
  id plus `--part` for generated children (`idl2xmi-M.op--return`), and
  `idl2xmi--` for built-in elements (`idl2xmi--CORBA.long`).
- IDL 4 constructs missing from CCCMP use only the separate `IDL4` namespace.
  The complete gap analysis and proposed OMG resolution is in
  [docs/omg-idl4-xmi-proposal.md](docs/omg-idl4-xmi-proposal.md).

The generated standards-based output is covered by recursive IDL fixtures and
committed XMI goldens. Separate semantic tests verify the CCCMP stereotype
applications, classifier type references, union mapping, CCM mappings, and
isolation of IDL 4 extensions.
