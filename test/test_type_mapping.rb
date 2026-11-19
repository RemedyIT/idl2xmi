# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require 'ridl/runner'
require 'ridl/require'

require_relative '../lib/idl2xmi'

class BasicTypeMappingTest < Minitest::Test
  def test_maps_basic_idl_types_to_idl_spellings
    cases = {
      IDL::Type::Boolean.new => 'boolean',
      IDL::Type::Char.new => 'char',
      IDL::Type::WChar.new => 'wchar',
      IDL::Type::Octet.new => 'octet',
      IDL::Type::TinyShort.new => 'int8',
      IDL::Type::UTinyShort.new => 'uint8',
      IDL::Type::Short.new => 'short',
      IDL::Type::UShort.new => 'unsigned short',
      IDL::Type::Long.new => 'long',
      IDL::Type::ULong.new => 'unsigned long',
      IDL::Type::LongLong.new => 'long long',
      IDL::Type::ULongLong.new => 'unsigned long long',
      IDL::Type::Float.new => 'float',
      IDL::Type::Double.new => 'double',
      IDL::Type::LongDouble.new => 'long double',
      IDL::Type::Any.new => 'any',
      IDL::Type::Object.new => 'Object',
      IDL::Type::ValueBase.new => 'ValueBase',
      IDL::Type::Native.new => 'native',
      IDL::Type::String.new => 'string',
      IDL::Type::String.new(32) => 'string<32>',
      IDL::Type::WString.new => 'wstring',
      IDL::Type::WString.new(16) => 'wstring<16>',
      IDL::Type::Fixed.new(8, 2) => 'fixed<8,2>',
      IDL::Type::Fixed.new => 'fixed'
    }
    visitor = IDL::Idl2xmi::XmiVisitor.new(StringIO.new)

    cases.each do |type, expected|
      assert_equal expected, visitor.send(:idl_type_name, type), type.class.name
    end
  end
end
