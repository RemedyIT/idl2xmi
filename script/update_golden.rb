#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rbconfig'
require 'fileutils'

root = File.expand_path('..', __dir__)
fixtures_dir = File.join(root, 'test', 'fixtures')
golden_dir = File.join(root, 'test', 'golden')
generator = File.join(__dir__, 'idl2xmi.rb')
fixtures = Dir[File.join(fixtures_dir, '**', '*.idl')].sort

fixtures.each do |input|
  relative_path = input.delete_prefix(fixtures_dir + File::SEPARATOR)
  output = File.join(golden_dir, relative_path.sub(/\.idl\z/, '.xmi'))
  FileUtils.mkdir_p(File.dirname(output))
  warn "Generating #{output} from #{input}"
  abort "Failed generating #{output}" unless system(RbConfig.ruby, generator, input, output)
end
