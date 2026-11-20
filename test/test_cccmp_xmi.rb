# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'rexml/document'

class CccmpXmiTest < Minitest::Test
  NS = {
    'xmi' => 'http://www.omg.org/spec/XMI/20131001',
    'uml' => 'http://www.omg.org/spec/UML/20161101',
    'BaseIDL' => 'https://www.omg.org/spec/CCCMP/20070501/BaseIDL',
    'ComponentIDL' => 'https://www.omg.org/spec/CCCMP/20070501/ComponentIDL',
    'IDL4' => 'https://www.remedy.nl/idl2xmi/profile/IDL4/1.0'
  }.freeze

  def test_struct_uses_base_idl_profile_and_corba_primitive
    document = generate('struct_one_member.idl')
    struct = by_id(document, 'idl2xmi-Record')
    member = by_id(document, 'idl2xmi-Record.id')

    assert_equal 'uml:DataType', struct.attributes['xmi:type']
    assert_equal 'idl2xmi--CORBA.long', member.attributes['type']
    assert profile_application(document, 'BaseIDL:CORBAStruct', 'base_DataType', 'idl2xmi-Record')
    assert profile_application(document, 'BaseIDL:CORBAField', 'base_Property', 'idl2xmi-Record.id')
    assert profile_application(document, 'BaseIDL:CORBAPrimitive', 'base_DataType', 'idl2xmi--CORBA.long')
  end

  def test_union_uses_switch_case_and_default_stereotypes
    document = generate('module_union.idl')

    assert profile_application(document, 'BaseIDL:CORBAUnion', 'base_DataType', 'idl2xmi-Example.Choice')
    assert profile_application(document, 'BaseIDL:CORBASwitch', 'base_Property', 'idl2xmi-Example.Choice--discriminator')
    refute_empty REXML::XPath.match(document, '//BaseIDL:CORBACase', NS)
    refute_empty REXML::XPath.match(document, '//BaseIDL:CORBADefault', NS)
  end

  def test_idl4_constructs_are_separated_from_cccmp
    document = generate('idl4_types.idl')

    refute_empty REXML::XPath.match(document, '//IDL4:Map', NS)
    refute_empty REXML::XPath.match(document, '//IDL4:BitMask', NS)
    refute_empty REXML::XPath.match(document, '//IDL4:BitSet', NS)
  end

  def test_module_constants_use_the_cccmp_constants_class
    document = generate('constants.idl')
    constants = REXML::XPath.first(document, "//*[@name='Constants' and @xmi:type='uml:Class']", NS)

    refute_nil constants
    assert profile_application(document, 'BaseIDL:CORBAConstants', 'base_Class', constants.attributes['xmi:id'])
    refute_empty REXML::XPath.match(document, '//BaseIDL:CORBAConstant', NS)
  end

  def test_array_typedef_uses_corba_array
    document = generate('arrays.idl')

    assert profile_application(document, 'BaseIDL:CORBAArray', 'base_DataType', 'idl2xmi-LongArray')
  end

  def test_ccm_home_associations_ports_and_factories_use_component_idl
    document = generate('idl3_entities.idl')
    home = by_id(document, 'idl2xmi-WorkerHome')

    assert_equal 'uml:Interface', home.attributes['xmi:type']
    assert profile_application(document, 'ComponentIDL:CORBAHome', 'base_Interface', 'idl2xmi-WorkerHome')
    assert profile_application(document, 'ComponentIDL:CORBAManages', 'base_Association', 'idl2xmi-WorkerHome--CORBAManages')
    assert profile_application(document, 'ComponentIDL:CORBAPrimaryKey', 'base_Association', 'idl2xmi-WorkerHome--CORBAPrimaryKey')
    refute_empty REXML::XPath.match(document, '//ComponentIDL:CORBAProvides', NS)
    refute_empty REXML::XPath.match(document, '//ComponentIDL:CORBAUses', NS)
    refute_empty REXML::XPath.match(document, '//ComponentIDL:CORBAFactory', NS)
    refute_empty REXML::XPath.match(document, '//ComponentIDL:CORBAFinder', NS)
  end

  def test_every_fixture_has_unique_xmi_ids
    Dir[File.expand_path('fixtures/**/*.idl', __dir__)].sort.each do |path|
      fixture = path.delete_prefix(File.expand_path('fixtures', __dir__) + File::SEPARATOR)
      ids = REXML::XPath.match(generate(fixture), '//@xmi:id', NS).map(&:value)
      duplicates = ids.tally.select { |_id, count| count > 1 }.keys

      assert_empty duplicates, "duplicate xmi:ids in #{fixture}"
    end
  end

  def test_user_module_named_corba_does_not_clash_with_builtin_package
    document = generate('id_collisions.idl')

    assert_equal 'CORBA', by_id(document, 'idl2xmi-CORBA').attributes['name']
    assert_equal 'CORBA', by_id(document, 'idl2xmi--CORBA').attributes['name']
    refute_equal by_id(document, 'idl2xmi-a.b'), by_id(document, 'idl2xmi-a__b')
  end

  def test_bounded_sequence_upper_multiplicity_equals_bound
    document = generate('id_collisions.idl')

    assert_equal '3', by_id(document, 'idl2xmi-ThreeLongs--members').attributes['upper']
    assert_equal '0', by_id(document, 'idl2xmi-ThreeLongs--members').attributes['lower']
  end

  def test_operation_annotations_are_not_copied_to_the_return_parameter
    document = generate('id_collisions.idl')
    result = by_id(document, 'idl2xmi-Ops.annotated--return')

    assert_empty REXML::XPath.match(result, 'ownedComment', NS)
    assert_equal ['@deprecated()'],
                 REXML::XPath.match(document, "//*[@annotatedElement='idl2xmi-Ops.annotated']/body", NS).map(&:text)
  end

  def test_forward_declaration_after_definition_is_not_emitted
    document = generate('id_collisions.idl')

    assert_empty REXML::XPath.match(document, "//IDL4:ForwardDeclaration[@base_Interface='idl2xmi-Ops']", NS)
  end

  def test_type_names_are_idl_not_cxx
    names = %w[all_basic_types.idl templates.idl id_collisions.idl].flat_map do |fixture|
      REXML::XPath.match(generate(fixture), '//@name | //@arguments', NS).map(&:value)
    end

    assert_includes names, 'fixed<8, 2>'
    assert_includes names, 'long' # template binding argument, was int32_t
    assert_empty names.grep(/std::|TAOX11|_t\b/)
  end

  def test_output_starts_with_xml_declaration
    script = File.expand_path('../script/idl2xmi.rb', __dir__)
    stdout, = Open3.capture3(RbConfig.ruby, script, File.expand_path('fixtures/enum.idl', __dir__))

    assert stdout.start_with?("<?xml version='1.0' encoding='UTF-8'?>")
  end

  def test_constant_values_use_uml_value_specifications
    document = generate('constants.idl')
    values = REXML::XPath.match(document, '//defaultValue', NS)

    refute_empty values
    assert(values.all? { |value| value.attributes['xmi:type'].start_with?('uml:Literal') })
    assert_empty REXML::XPath.match(document, '//ownedAttribute[@default]', NS)
  end

  private

  def generate(fixture)
    script = File.expand_path('../script/idl2xmi.rb', __dir__)
    input = File.expand_path("fixtures/#{fixture}", __dir__)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, input)
    assert status.success?, "generator failed for #{fixture}: #{stderr}"
    REXML::Document.new(stdout)
  end

  def by_id(document, id)
    REXML::XPath.first(document, "//*[@xmi:id='#{id}']", NS)
  end

  def profile_application(document, name, base, id)
    REXML::XPath.first(document, "//#{name}[@#{base}='#{id}']", NS)
  end
end
