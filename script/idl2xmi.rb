#!/usr/bin/env ruby
# frozen_string_literal: true

unless (1..2).cover?(ARGV.length)
  warn "Usage: #{$PROGRAM_NAME} INPUT.idl [OUTPUT.xmi]"
  exit 2
end

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'ridl/runner'
require 'ridl/require'
require 'idl2xmi'

input_path, output_path = ARGV
parser = IDL::Parser.new(idlversion: 4, ignore_pidl: true)
parser.parse(File.read(input_path))

output = output_path ? File.open(output_path, 'w') : $stdout
begin
  parser.visit_nodes(IDL::Idl2xmi::XmiVisitor.new(output))
ensure
  output.close if output_path && !output.closed?
end
