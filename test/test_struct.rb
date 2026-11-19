# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'rexml/document'
require 'tmpdir'

class StructXmiTest < Minitest::Test
  def test_struct_with_one_long_member
    assert_fixture_matches_golden('struct_one_member')
  end

  def test_struct_with_all_basic_types
    assert_fixture_matches_golden('all_basic_types')
  end

  def test_enum_with_three_values
    assert_fixture_matches_golden('enum')
  end

  def test_module_containing_union
    assert_fixture_matches_golden('module_union')
  end

  def test_module_constants
    assert_fixture_matches_golden('constants')
  end

  def test_interface_members_and_inheritance
    assert_fixture_matches_golden('interface')
  end

  def test_fixed_size_arrays
    assert_fixture_matches_golden('arrays')
  end

  private

  def assert_fixture_matches_golden(name)
    script = File.expand_path('../script/idl2xmi.rb', __dir__)
    input = File.expand_path("fixtures/#{name}.idl", __dir__)
    expected = File.expand_path("golden/#{name}.xmi", __dir__)

    Dir.mktmpdir do |dir|
      generated = File.join(dir, 'generated.xmi')
      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, script, input, generated
      )

      assert status.success?, "generator failed: #{stderr}"
      assert_equal canonical_xml(expected), canonical_xml(generated)
    end
  end

  def canonical_xml(path)
    document = REXML::Document.new(File.read(path))
    canonical_element(document.root)
  end

  def canonical_element(element)
    attributes = element.attributes.to_a
                           .map { |attribute| [attribute.expanded_name, attribute.value] }
                           .sort
    children = element.elements.to_a.map { |child| canonical_element(child) }
    [element.expanded_name, attributes, children]
  end
end
