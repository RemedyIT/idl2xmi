# frozen_string_literal: true

module IDL
  module Idl2xmi
    class XmiVisitor
      XMI_NS = 'http://www.omg.org/spec/XMI/20131001'.freeze
      UML_NS = 'http://www.omg.org/spec/UML/20161101'.freeze
      IDL2XMI_NS = 'https://github.com/jwillemsen/idl2xmi/profile'.freeze
      BASIC_TYPE_NAMES = {
        IDL::Type::Boolean => 'boolean',
        IDL::Type::Char => 'char',
        IDL::Type::WChar => 'wchar',
        IDL::Type::Octet => 'octet',
        IDL::Type::Short => 'short',
        IDL::Type::UShort => 'unsigned short',
        IDL::Type::Long => 'long',
        IDL::Type::ULong => 'unsigned long',
        IDL::Type::LongLong => 'long long',
        IDL::Type::ULongLong => 'unsigned long long',
        IDL::Type::Float => 'float',
        IDL::Type::Double => 'double',
        IDL::Type::LongDouble => 'long double',
        IDL::Type::String => 'string',
        IDL::Type::WString => 'wstring'
      }.freeze

      def initialize(output)
        @output = output
        @document = REXML::Document.new
        @xmi = REXML::Element.new('xmi:XMI')
        @xmi.add_namespace('xmi', XMI_NS)
        @xmi.add_namespace('uml', UML_NS)
        @xmi.add_namespace('idl2xmi', IDL2XMI_NS)
        @xmi.add_attribute('xmi:version', '2.5.1')
        @model = REXML::Element.new('uml:Model')
        @model.add_attribute('xmi:id', 'idl2xmi-model')
        @model.add_attribute('name', 'IDL model')
        @xmi.add_element(@model)
        @document.add_element(@xmi)
        @containers = [@model]
        @enum_stack = []
      end

      def visit_nodes(parser)
        parser.walk_nodes(self)
        @document.write(@output, 2)
        @output.write("\n")
      end

      def enter_module(node)
        package = element('packagedElement', 'uml:Package', node.lm_name)
        current_container.add_element(package)
        @containers.push(package)
      end

      def leave_module(_node)
        @containers.pop
      end

      def enter_struct(node)
        datatype = element('packagedElement', 'uml:DataType', node.lm_name)
        current_container.add_element(datatype)
        node.members.each do |member|
          property = REXML::Element.new('ownedAttribute')
          property.add_attribute('xmi:type', 'uml:Property')
          property.add_attribute('xmi:id', stable_id("#{node.scoped_name}::#{member.lm_name}"))
          property.add_attribute('name', member.lm_name.to_s)
          property.add_attribute('type', idl_type_name(member.idltype))
          datatype.add_element(property)
        end
      end

      def visit_enum(node)
        enumeration = element('packagedElement', 'uml:Enumeration', node.lm_name)
        current_container.add_element(enumeration)
        @enum_stack.push(enumeration)
      end

      def visit_enumerator(node)
        literal = REXML::Element.new('ownedLiteral')
        literal.add_attribute('xmi:type', 'uml:EnumerationLiteral')
        literal.add_attribute('xmi:id', stable_id(node.scoped_name))
        literal.add_attribute('name', node.lm_name.to_s)
        literal.add_attribute('idl2xmi:index', node.value.to_s)
        @enum_stack.last&.add_element(literal)
      end

      private

      def current_container
        @containers.last
      end

      def element(tag, xmi_type, name)
        result = REXML::Element.new(tag)
        result.add_attribute('xmi:type', xmi_type)
        result.add_attribute('xmi:id', stable_id(name))
        result.add_attribute('name', name.to_s)
        result
      end

      def idl_type_name(type)
        if IDL::Type::NodeType === type
          type.node.scoped_name.to_s
        else
          BASIC_TYPE_NAMES.fetch(type.class, type.typename.to_s)
        end
      end

      def stable_id(name)
        "idl2xmi-#{name.to_s.gsub(/[^A-Za-z0-9_.-]/, '_')}"
      end
    end
  end
end
