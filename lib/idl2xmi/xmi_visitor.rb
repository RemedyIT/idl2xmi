# frozen_string_literal: true

module IDL
  module Idl2xmi
    class XmiVisitor
      XMI_NS = 'http://www.omg.org/spec/XMI/20131001'.freeze
      UML_NS = 'http://www.omg.org/spec/UML/20161101'.freeze
      IDL2XMI_NS = 'https://github.com/jwillemsen/idl2xmi/profile'.freeze
      CXX_TYPE_NAMES = {
        IDL::Type::Boolean => 'bool',
        IDL::Type::Char => 'char',
        IDL::Type::WChar => 'wchar_t',
        IDL::Type::Octet => 'uint8_t',
        IDL::Type::TinyShort => 'int8_t',
        IDL::Type::UTinyShort => 'uint8_t',
        IDL::Type::Short => 'int16_t',
        IDL::Type::UShort => 'uint16_t',
        IDL::Type::Long => 'int32_t',
        IDL::Type::ULong => 'uint32_t',
        IDL::Type::LongLong => 'int64_t',
        IDL::Type::ULongLong => 'uint64_t',
        IDL::Type::Float => 'float',
        IDL::Type::Double => 'double',
        IDL::Type::LongDouble => 'long double',
        IDL::Type::Any => 'TAOX11_NAMESPACE::CORBA::Any',
        IDL::Type::Object => 'TAOX11_NAMESPACE::CORBA::Object',
        IDL::Type::ValueBase => 'TAOX11_NAMESPACE::CORBA::ValueBase',
        IDL::Type::Native => 'void*',
        IDL::Type::String => 'std::string',
        IDL::Type::WString => 'std::wstring'
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
        package = element('packagedElement', 'uml:Package', node)
        current_container.add_element(package)
        @containers.push(package)
      end

      def leave_module(_node)
        @containers.pop
      end

      def enter_struct(node)
        datatype = element('packagedElement', 'uml:DataType', node)
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

      def leave_struct(_node)
        # Struct members are emitted from enter_struct; nothing to close here.
      end

      def visit_enum(node)
        enumeration = element('packagedElement', 'uml:Enumeration', node)
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

      def enter_union(node)
        union = element('packagedElement', 'uml:DataType', node)
        union.add_attribute('idl2xmi:kind', 'union')
        union.add_attribute('idl2xmi:discriminatorType', idl_type_name(node.switchtype))
        current_container.add_element(union)

        # RIDL's AST walk intentionally skips union arms, so emit these members
        # while visiting the union node itself.
        node.members.each do |member|
          property = REXML::Element.new('ownedAttribute')
          property.add_attribute('xmi:type', 'uml:Property')
          property.add_attribute('xmi:id', stable_id(member.scoped_name))
          property.add_attribute('name', member.lm_name.to_s)
          property.add_attribute('type', idl_type_name(member.idltype))
          property.add_attribute('idl2xmi:labels', member.labels.map { |label| union_label(label) }.join(','))
          union.add_element(property)
        end
      end

      def leave_union(_node)
        # Union arms are emitted from enter_union.
      end

      private

      def current_container
        @containers.last
      end

      def element(tag, xmi_type, node)
        result = REXML::Element.new(tag)
        result.add_attribute('xmi:type', xmi_type)
        result.add_attribute('xmi:id', stable_id(node.scoped_name))
        result.add_attribute('name', node.lm_name.to_s)
        result
      end

      def idl_type_name(type)
        if type.respond_to?(:cxx_type)
          type.cxx_type
        elsif IDL::Type::NodeType === type
          "::#{type.node.scoped_name}"
        elsif IDL::Type::String === type || IDL::Type::WString === type
          bounded_type_name(type.class == IDL::Type::String ? 'TAOX11_IDL::bounded_string' : 'TAOX11_IDL::bounded_wstring', type.size)
        elsif IDL::Type::Fixed === type
          type.digits ? "TAOX11_NAMESPACE::IDL::Fixed<#{type.digits}, #{type.scale}>" : 'TAOX11_NAMESPACE::IDL::Fixed'
        else
          CXX_TYPE_NAMES.fetch(type.class, type.typename.to_s)
        end
      end

      def bounded_type_name(name, bound)
        type_name = if name == 'TAOX11_IDL::bounded_string' && bound.nil?
                      'std::string'
                    elsif name == 'TAOX11_IDL::bounded_wstring' && bound.nil?
                      'std::wstring'
                    elsif bound
                      "#{name}<#{bound}>"
                    else
                      name
                    end
        type_name
      end

      def union_label(label)
        return 'default' if label == :default

        label.respond_to?(:value) ? label.value.to_s : label.to_s
      end

      def stable_id(name)
        "idl2xmi-#{name.to_s.gsub(/[^A-Za-z0-9_.-]/, '_')}"
      end
    end
  end
end
