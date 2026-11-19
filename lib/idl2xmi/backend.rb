# frozen_string_literal: true

module IDL
  module Idl2xmi
    TITLE = 'RIDL IDL-to-XMI backend'.freeze
    COPYRIGHT = 'Copyright (c) 2026'.freeze
    VERSION = { major: 0, minor: 1, release: 0 }.freeze

    module ScannerMixin
      def chk_identifier(identifier)
        identifier
      end
    end

    Scanner.include(ScannerMixin)

    Backend.configure('idl2xmi', File.expand_path('../ridlbe/idl2xmi', __dir__),
                      TITLE, COPYRIGHT, VERSION) do |becfg|
      becfg.on_process_input do |parser, options|
        output = options[:output] ? File.open(options[:output], 'w') : $stdout
        begin
          parser.visit_nodes(::IDL::Idl2xmi::XmiVisitor.new(output))
        ensure
          output.close if options[:output] && !output.closed?
        end
      end
    end
  end
end
