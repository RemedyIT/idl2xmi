# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require 'ridl/runner'
require 'ridl/require'

require_relative '../lib/idl2xmi'

class BasicTypeMappingTest < Minitest::Test
  def test_maps_basic_idl_types_to_taox11_cxx_types
    cases = {
      IDL::Type::Boolean.new => 'bool',
      IDL::Type::Char.new => 'char',
      IDL::Type::WChar.new => 'wchar_t',
      IDL::Type::Octet.new => 'uint8_t',
      IDL::Type::TinyShort.new => 'int8_t',
      IDL::Type::UTinyShort.new => 'uint8_t',
      IDL::Type::Short.new => 'int16_t',
      IDL::Type::UShort.new => 'uint16_t',
      IDL::Type::Long.new => 'int32_t',
      IDL::Type::ULong.new => 'uint32_t',
      IDL::Type::LongLong.new => 'int64_t',
      IDL::Type::ULongLong.new => 'uint64_t',
      IDL::Type::Float.new => 'float',
      IDL::Type::Double.new => 'double',
      IDL::Type::LongDouble.new => 'long double',
      IDL::Type::Any.new => 'TAOX11_NAMESPACE::CORBA::Any',
      IDL::Type::Object.new => 'TAOX11_NAMESPACE::CORBA::Object',
      IDL::Type::ValueBase.new => 'TAOX11_NAMESPACE::CORBA::ValueBase',
      IDL::Type::Native.new => 'void*',
      IDL::Type::String.new => 'std::string',
      IDL::Type::String.new(32) => 'TAOX11_IDL::bounded_string<32>',
      IDL::Type::WString.new => 'std::wstring',
      IDL::Type::WString.new(16) => 'TAOX11_IDL::bounded_wstring<16>',
      IDL::Type::Fixed.new(8, 2) => 'TAOX11_NAMESPACE::IDL::Fixed<8, 2>',
      IDL::Type::Fixed.new => 'TAOX11_NAMESPACE::IDL::Fixed'
    }
    visitor = IDL::Idl2xmi::XmiVisitor.new(StringIO.new)

    cases.each do |type, expected|
      assert_equal expected, visitor.send(:idl_type_name, type), type.class.name
    end
  end
end
