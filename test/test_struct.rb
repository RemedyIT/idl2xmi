# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'rexml/document'
require 'tmpdir'

class GoldenXmiTest < Minitest::Test
  def test_every_idl_fixture_matches_its_golden_file
    fixtures_dir = File.expand_path('fixtures', __dir__)
    golden_dir = File.expand_path('golden', __dir__)
    fixtures = Dir[File.join(fixtures_dir, '**', '*.idl')].sort
    refute_empty fixtures, 'no IDL fixtures found'

    missing_goldens = []
    fixtures.each do |input|
      relative_path = input.delete_prefix(fixtures_dir + File::SEPARATOR)
      expected = File.join(golden_dir, relative_path.sub(/\.idl\z/, '.xmi'))
      assert_fixture_matches_golden(input, expected, relative_path, missing_goldens)
    end

    assert_empty missing_goldens, "missing golden files: #{missing_goldens.join(', ')}"
  end

  private

  def assert_fixture_matches_golden(input, expected, relative_path, missing_goldens)
    script = File.expand_path('../script/idl2xmi.rb', __dir__)

    Dir.mktmpdir do |dir|
      generated = File.join(dir, relative_path.sub(/\.idl\z/, '.xmi'))
      FileUtils.mkdir_p(File.dirname(generated))
      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, script, '--legacy', input, generated
      )

      assert status.success?, "generator failed for #{relative_path}: #{stderr}"
      unless File.file?(expected)
        missing_goldens << expected
        warn "Missing golden file: #{expected}\nGenerated XMI:\n#{File.read(generated)}"
        return
      end

      assert_equal canonical_xml(expected), canonical_xml(generated), relative_path
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
