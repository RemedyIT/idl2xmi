# Proposal: standard UML/XMI mapping for OMG IDL 4

## Issue summary

The UML Profile for CORBA and CORBA Components (CCCMP) 1.0 defines a UML
mapping for CORBA 3.0.3 IDL and the CORBA Component Model. It predates OMG IDL
4 and therefore cannot represent every declaration accepted by a current IDL
4 compiler. There is no replacement OMG specification defining a complete,
portable IDL 4 to UML/XMI mapping.

This leaves tools with two incompatible choices: discard IDL 4 semantics or
invent tool-specific XMI. A standard extension of CCCMP is needed.

## Normative basis

- CCCMP 1.0: <https://www.omg.org/spec/CCCMP/1.0>
- CCCMP normative profile XMI: <https://www.omg.org/spec/CCCMP/20070501>
- OMG IDL 4.2: <https://www.omg.org/spec/IDL/4.2>
- XMI 2.5.1: <https://www.omg.org/spec/XMI/2.5.1>
- UML 2.5.1: <https://www.omg.org/spec/UML/2.5.1>

## Missing mappings and proposed resolution

| IDL construct or information | CCCMP status | Proposed UML representation |
|---|---|---|
| `int8`, `uint8` | No primitive classifiers | `IDL4Primitive` stereotype on UML `DataType`; standardized names `int8` and `uint8`. IDL fixed-width aliases that are semantically identical to classic primitives continue to use the corresponding `CORBAPrimitive`. |
| `map<K,V[,N]>` | No mapping | `IDL4Map` stereotype on UML `DataType`, with `keyType: Type[1]`, `valueType: Type[1]`, and `bound: UnlimitedNatural[0..1]`. |
| `bitmask` and bit values | No mapping | `IDL4BitMask` on UML `Enumeration`, tag `bitBound`; `IDL4BitValue` on `EnumerationLiteral`, tag `position`. The numeric mask is derived as `1 << position`. |
| `bitset` | No mapping | `IDL4BitSet` on UML `DataType`; use UML `Generalization` for bitset inheritance. |
| `bitfield` | No mapping | `IDL4BitField` on UML `Property`, tag `bits: PositiveInteger`; the UML property type is the IDL bitfield type. |
| Struct inheritance | Explicitly incompatible with the CCCMP constraint that a `CORBAStruct` has no generalization | Permit one UML `Generalization` from a `CORBAStruct` to another `CORBAStruct`; add an `IDL4StructInheritance` marker only when a consumer must distinguish the revised rule. |
| Annotation declarations and applications | No mapping | Map an annotation declaration to a UML `Stereotype` in a generated UML `Profile`. Map annotation members to stereotype properties and each application to a normal UML stereotype application. Define a generic `IDL4AnnotationApplication` fallback for annotations whose declaration is unavailable. |
| Template modules and bound modules | No mapping | UML `TemplateSignature`/`TemplateParameter` on a Package stereotyped `IDL4TemplateModule`; UML `TemplateBinding` for a bound module. Parameters retain their IDL kind and optional type constraint. |
| IDL3+ `porttype`, extended/mirrored ports, and `connector` | Not in CCCMP 1.0 | `IDL4PortType` on UML `Interface`, `IDL4Connector` on UML `Component`, and `IDL4Port` on UML `Port` with a `kind` enumeration and `multiple` tag. Reuse CCCMP ComponentIDL stereotypes for classic CCM provides/uses/emits/publishes/consumes ports. |
| Forward declarations | No lossless source mapping | `IDL4ForwardDeclaration` on the eventual UML classifier, with an optional `isResolved` tag. A semantic-only export may omit it after resolution. |
| `#include`/import provenance | No mapping | UML `PackageImport` or `ElementImport` when resolvable; otherwise `IDL4SourceImport` with a URI. This is optional source-trace information, not an IDL semantic element. |
| `typeid` and `typeprefix` | No mapping | `IDL4RepositoryIdentity` on UML `NamedElement` with optional `typeId` and `typePrefix` tags. |
| `native` | Missing (also recorded by OMG issue CORP-8) | `IDL4Native` on UML `DataType`, with optional standardized repository identifier; no assumed language-specific target type. |
| `oneway` operation | Not represented losslessly | `IDL4Oneway` on UML `Operation`; constraint: no return value, no `out`/`inout` parameters, and no user exceptions, following IDL rules. |
| Operation `context` clauses | Not represented losslessly | `IDL4OperationContext` on UML `Operation`, tag `value: String[1..*]`. Mark deprecated consistently with IDL. |
| Attribute `getraises`/`setraises` | UML Property has no equivalent | `IDL4AttributeRaises` on UML `Property`, with ordered references `getRaises` and `setRaises` to exception classifiers. |
| Enumerator ordinal | CCCMP has a `members` tag but no portable per-literal ordinal | `IDL4EnumLiteralValue` on UML `EnumerationLiteral`, tag `value: Integer`; values are derived when IDL does not specify them. |

The proposed stereotypes use the `IDL4` prefix in this repository. Final OMG
names should follow the naming convention selected by the responsible RTF/FTF.

## Constraints

1. An IDL4 map bound, when present, is greater than zero.
2. A bit value position is unique within its bitmask and less than `bitBound`.
3. The sum and placement of bitfield widths obey the IDL 4 bitset rules.
4. Struct and bitset generalizations target the same IDL declaration kind.
5. An annotation application conforms to its annotation declaration.
6. A bound template module supplies exactly one compatible argument per formal
   template parameter.
7. Language mapping spellings such as `std::vector` or `int32_t` are not used
   as UML type identities. UML `type` references always target classifiers.

## Machine-readable artifact issue

The normative CCCMP profile is an Enterprise Architect export using XMI 2.1,
UML 2.1 schema URIs, generated element identifiers, and no declared stable
profile namespace URI. Modern XMI consumers therefore cannot reliably create a
standard stereotype application namespace or reference a stable profile
element other than by the generated fragment identifiers.

Proposed resolution:

1. Publish a canonical CCCMP revision in XMI 2.5.1/UML 2.5.1.
2. Assign stable namespace URIs to `BaseIDL`, `ComponentIDL`, and the other
   nested profiles.
3. Assign stable, human-readable IDs to profiles and stereotypes.
4. Publish explicit namespace/version migration rules from CCCMP 1.0.
5. Add normative XMI examples for a module, struct, union, interface, valuetype,
   component, and home.

## Reference implementation behavior

`idl2xmi` applies CCCMP `BaseIDL` and `ComponentIDL` stereotypes wherever the
normative profile has a mapping. Constructs in the table above are emitted only
through the separate `IDL4` extension namespace. This separation makes the
non-standard portion visible and gives the OMG proposal executable examples.

## Suggested OMG issue text

**Summary:** Define a UML/XMI profile mapping for OMG IDL 4 and modernize the
CCCMP machine-readable profile.

**Problem:** CCCMP 1.0 is based on CORBA 3.0.3 and does not map IDL 4 maps,
bitmasks, bitsets, bitfields, struct inheritance, annotations, template modules,
or later IDL3+ component constructs. Its normative profile is supplied only as
an XMI 2.1 Enterprise Architect export without stable profile namespace URIs.
Consequently, current IDL tools cannot exchange complete IDL 4 models through
portable OMG-standard XMI.

**Proposal:** Adopt the stereotypes, tags, and constraints in the “Missing
mappings and proposed resolution” table above as a new UML Profile for IDL 4,
defined as a compatible extension of CCCMP BaseIDL/ComponentIDL. Publish the
profile normatively as UML 2.5.1/XMI 2.5.1 with stable namespace URIs and
normative examples. Relax the CCCMP `CORBAStruct` no-generalization constraint
for IDL 4 struct inheritance.

