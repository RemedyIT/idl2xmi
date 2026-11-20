# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require 'ridl/runner'
require 'ridl/require'

require_relative '../lib/idl2xmi'

class BasicTypeMappingTest < Minitest::Test
  def test_maps_basic_idl_types_to_uml_classifiers
    cases = {
      IDL::Type::Void.new => 'idl2xmi-CORBA__void',
      IDL::Type::Boolean.new => 'idl2xmi-CORBA__boolean',
      IDL::Type::Char.new => 'idl2xmi-CORBA__char',
      IDL::Type::WChar.new => 'idl2xmi-CORBA__wchar',
      IDL::Type::Octet.new => 'idl2xmi-CORBA__octet',
      IDL::Type::TinyShort.new => 'idl2xmi-CORBA__int8',
      IDL::Type::UTinyShort.new => 'idl2xmi-CORBA__uint8',
      IDL::Type::Short.new => 'idl2xmi-CORBA__short',
      IDL::Type::UShort.new => 'idl2xmi-CORBA__unsignedShort',
      IDL::Type::Long.new => 'idl2xmi-CORBA__long',
      IDL::Type::ULong.new => 'idl2xmi-CORBA__unsignedLong',
      IDL::Type::LongLong.new => 'idl2xmi-CORBA__longLong',
      IDL::Type::ULongLong.new => 'idl2xmi-CORBA__unsignedLongLong',
      IDL::Type::Float.new => 'idl2xmi-CORBA__float',
      IDL::Type::Double.new => 'idl2xmi-CORBA__double',
      IDL::Type::LongDouble.new => 'idl2xmi-CORBA__longDouble',
      IDL::Type::Any.new => 'idl2xmi-CORBA__any',
      IDL::Type::Object.new => 'idl2xmi-CORBA__Object',
      IDL::Type::ValueBase.new => 'idl2xmi-CORBA__ValueBase',
      IDL::Type::String.new => 'idl2xmi-CORBA__string',
      IDL::Type::WString.new => 'idl2xmi-CORBA__wstring'
    }
    visitor = IDL::Idl2xmi::XmiVisitor.new(StringIO.new)

    cases.each do |type, expected|
      assert_equal expected, visitor.send(:type_id, type), type.class.name
    end
  end
end
