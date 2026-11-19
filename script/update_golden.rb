#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rbconfig'

root = File.expand_path('..', __dir__)
generator = File.join(__dir__, 'idl2xmi.rb')
fixtures = Dir[File.join(root, 'test', 'fixtures', '*.idl')].sort

fixtures.each do |input|
  name = File.basename(input, '.idl')
  output = File.join(root, 'test', 'golden', "#{name}.xmi")
  warn "Generating #{output} from #{input}"
  abort "Failed generating #{output}" unless system(RbConfig.ruby, generator, input, output)
end
