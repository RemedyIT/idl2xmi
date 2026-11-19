# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require 'rexml/document'
require 'rexml/xpath'
require 'ridl/runner'
require 'ridl/require'

require_relative '../lib/idl2xmi'

class StructXmiTest < Minitest::Test
  UML_NS = 'http://www.omg.org/spec/UML/20161101'.freeze

  def test_struct_with_one_long_member
    parser = IDL::Parser.new(idlversion: 3, ignore_pidl: true)
    parser.parse(<<~IDL)
      struct Record {
        long id;
      };
    IDL

    output = StringIO.new
    parser.visit_nodes(IDL::Idl2xmi::XmiVisitor.new(output))
    document = REXML::Document.new(output.string)

    datatype = REXML::XPath.first(
      document,
      "//packagedElement[@name='Record']",
      'uml' => UML_NS
    )
    refute_nil datatype
    assert_equal 'uml:DataType', datatype.attributes['xmi:type']

    properties = datatype.elements.to_a('ownedAttribute')
    assert_equal 1, properties.length
    assert_equal 'id', properties.first.attributes['name']
    assert_equal 'long', properties.first.attributes['type']
  end
end
