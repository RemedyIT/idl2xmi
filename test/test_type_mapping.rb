# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require 'ridl/runner'
require 'ridl/require'

require_relative '../lib/idl2xmi'

class BasicTypeMappingTest < Minitest::Test
  def test_maps_basic_idl_types_to_uml_classifiers
    cases = {
      IDL::Type::Void.new => 'idl2xmi--CORBA.void',
      IDL::Type::Boolean.new => 'idl2xmi--CORBA.boolean',
      IDL::Type::Char.new => 'idl2xmi--CORBA.char',
      IDL::Type::WChar.new => 'idl2xmi--CORBA.wchar',
      IDL::Type::Octet.new => 'idl2xmi--CORBA.octet',
      IDL::Type::TinyShort.new => 'idl2xmi--CORBA.int8',
      IDL::Type::UTinyShort.new => 'idl2xmi--CORBA.uint8',
      IDL::Type::Short.new => 'idl2xmi--CORBA.short',
      IDL::Type::UShort.new => 'idl2xmi--CORBA.unsignedShort',
      IDL::Type::Long.new => 'idl2xmi--CORBA.long',
      IDL::Type::ULong.new => 'idl2xmi--CORBA.unsignedLong',
      IDL::Type::LongLong.new => 'idl2xmi--CORBA.longLong',
      IDL::Type::ULongLong.new => 'idl2xmi--CORBA.unsignedLongLong',
      IDL::Type::Float.new => 'idl2xmi--CORBA.float',
      IDL::Type::Double.new => 'idl2xmi--CORBA.double',
      IDL::Type::LongDouble.new => 'idl2xmi--CORBA.longDouble',
      IDL::Type::Any.new => 'idl2xmi--CORBA.any',
      IDL::Type::Object.new => 'idl2xmi--CORBA.Object',
      IDL::Type::ValueBase.new => 'idl2xmi--CORBA.ValueBase',
      IDL::Type::String.new => 'idl2xmi--CORBA.string',
      IDL::Type::WString.new => 'idl2xmi--CORBA.wstring'
    }
    visitor = IDL::Idl2xmi::XmiVisitor.new(StringIO.new)

    cases.each do |type, expected|
      assert_equal expected, visitor.send(:type_id, type), type.class.name
    end
  end
end
