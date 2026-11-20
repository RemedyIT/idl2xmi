# frozen_string_literal: true

module IDL
  module Idl2xmi
    class XmiVisitor
      XMI_NS = 'http://www.omg.org/spec/XMI/20131001'.freeze
      UML_NS = 'http://www.omg.org/spec/UML/20161101'.freeze
      IDL2XMI_NS = 'https://github.com/jwillemsen/idl2xmi/profile'.freeze
      CXX_TYPE_NAMES = {
        IDL::Type::Void => 'void',
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
        @elements_by_name = {}
        @forward_declarations = {}
      end

      def visit_nodes(parser)
        parser.walk_nodes(self)
        emit_deferred_nodes(parser.root) if parser.respond_to?(:root) && parser.root
        emit_forward_declarations
        @document.write(@output, 2)
        @output.write("\n")
      end

      def enter_module(node)
        package = element('packagedElement', 'uml:Package', node)
        if node.respond_to?(:is_templated?) && node.is_templated?
          package.add_attribute('idl2xmi:template', stable_id(node.template.scoped_name))
          package.add_attribute('idl2xmi:arguments', node.template_params.map { |param| idl_type_name(param) }.join(','))
        end
        current_container.add_element(package)
        @containers.push(package)
      end

      def leave_module(_node)
        @containers.pop
      end

      def visit_include(node)
        include_element = REXML::Element.new('idl2xmi:include')
        include_element.add_attribute('xmi:id', stable_id("include::#{node.filename}"))
        include_element.add_attribute('filename', node.filename.to_s)
        current_container.add_element(include_element)
      end

      def enter_interface(node)
        @forward_declarations.delete(node.scoped_name)
        interface = element('packagedElement', 'uml:Interface', node)
        interface.add_attribute('isAbstract', node.is_abstract?.to_s)
        interface.add_attribute('idl2xmi:local', node.is_local?.to_s)
        interface.add_attribute('idl2xmi:pseudo', node.is_pseudo?.to_s)
        current_container.add_element(interface)
        add_generalizations(interface, node, node.bases)
        @containers.push(interface)
      end

      def leave_interface(_node)
        @containers.pop
      end

      def declare_interface(node)
        declare_classifier(node, 'uml:Interface')
      end

      def enter_component(node)
        @forward_declarations.delete(node.scoped_name)
        component = element('packagedElement', 'uml:Component', node)
        component.add_attribute('idl2xmi:kind', 'component')
        add_generalizations(component, node, [node.base].compact)
        add_references(component, 'idl2xmi:supports', node.interfaces)
        current_container.add_element(component)
        @containers.push(component)
      end

      def leave_component(_node)
        @containers.pop
      end

      def declare_component(node)
        declare_classifier(node, 'uml:Component')
      end

      def enter_connector(node)
        connector = element('packagedElement', 'uml:Component', node)
        connector.add_attribute('idl2xmi:kind', 'connector')
        add_generalizations(connector, node, [node.base].compact)
        current_container.add_element(connector)
        @containers.push(connector)
      end

      def leave_connector(_node)
        @containers.pop
      end

      def enter_home(node)
        home = element('packagedElement', 'uml:Class', node)
        home.add_attribute('idl2xmi:kind', 'home')
        home.add_attribute('idl2xmi:manages', type_id(node.component))
        home.add_attribute('idl2xmi:primaryKey', type_id(node.primarykey)) if node.primarykey
        add_generalizations(home, node, [node.base].compact)
        add_references(home, 'idl2xmi:supports', node.interfaces)
        current_container.add_element(home)
        @containers.push(home)
      end

      def leave_home(_node)
        @containers.pop
      end

      def visit_port(node)
        port = REXML::Element.new('ownedPort')
        port.add_attribute('xmi:type', 'uml:Port')
        port.add_attribute('xmi:id', stable_id(node.scoped_name))
        port.add_attribute('name', node.lm_name.to_s)
        port.add_attribute('type', type_id(node.idltype))
        port.add_attribute('idl2xmi:kind', node.porttype.to_s)
        port.add_attribute('idl2xmi:multiple', node.multiple?.to_s)
        apply_annotations(port, node)
        current_container.add_element(port)
      end

      def visit_porttype(node)
        porttype = element('packagedElement', 'uml:Interface', node)
        porttype.add_attribute('idl2xmi:kind', 'porttype')
        current_container.add_element(porttype)
        @containers.push(porttype)
        node.ports.each { |port| visit_port(port) }
        node.attributes.each { |attribute| visit_attribute(attribute) }
        @containers.pop
      end

      def visit_valuebox(node)
        valuebox = element('packagedElement', 'uml:DataType', node)
        valuebox.add_attribute('idl2xmi:kind', 'valuebox')
        valuebox.add_attribute('idl2xmi:boxedType', idl_type_name(node.boxed_type))
        current_container.add_element(valuebox)
      end

      def enter_valuetype(node)
        @forward_declarations.delete(node.scoped_name)
        valuetype = element('packagedElement', 'uml:Class', node)
        valuetype.add_attribute('isAbstract', node.is_abstract?.to_s)
        valuetype.add_attribute('idl2xmi:kind', node.is_a?(IDL::AST::Eventtype) ? 'eventtype' : 'valuetype')
        valuetype.add_attribute('idl2xmi:custom', node.is_custom?.to_s)
        valuetype.add_attribute('idl2xmi:truncatable', node.is_truncatable?.to_s)
        add_generalizations(valuetype, node, node.bases)
        add_references(valuetype, 'idl2xmi:supports', node.interfaces)
        current_container.add_element(valuetype)
        @containers.push(valuetype)

        # RIDL deliberately omits these value members from walk_members.
        node.state_members.each { |member| add_state_member(member) }
        node.interface_members.each do |member|
          member.is_a?(IDL::AST::Operation) ? visit_operation(member) : visit_attribute(member)
        end
        node.initializers.each { |initializer| visit_factory(initializer) }
      end

      def leave_valuetype(_node)
        @containers.pop
      end

      def declare_valuetype(node)
        declare_classifier(node, 'uml:Class')
      end

      def visit_factory(node)
        visit_initializer(node, 'factory')
      end

      def visit_finder(node)
        visit_initializer(node, 'finder')
      end

      def visit_template_reference(node)
        reference = REXML::Element.new('idl2xmi:templateInstantiation')
        reference.add_attribute('xmi:id', stable_id(node.scoped_name))
        reference.add_attribute('name', node.lm_name.to_s)
        template = node.respond_to?(:template) ? node.template : nil
        template_params = node.respond_to?(:params) ? node.params : []
        reference.add_attribute('template', stable_id(template.scoped_name)) if template
        reference.add_attribute('arguments', template_params.map { |param| param.scoped_name }.join(','))
        apply_annotations(reference, node)
        current_container.add_element(reference)
      end

      def enter_struct(node)
        @forward_declarations.delete(node.scoped_name)
        datatype = element('packagedElement', 'uml:DataType', node)
        current_container.add_element(datatype)
        node.members.each do |member|
          add_member(datatype, member)
        end
        add_generalizations(datatype, node, [node.base].compact)
        @containers.push(datatype)
      end

      def leave_struct(_node)
        @containers.pop
      end

      def declare_struct(node)
        declare_classifier(node, 'uml:DataType')
      end

      def enter_exception(node)
        exception = element('packagedElement', 'uml:DataType', node)
        exception.add_attribute('idl2xmi:kind', 'exception')
        current_container.add_element(exception)
        node.members.each { |member| add_member(exception, member) }
        @containers.push(exception)
      end

      def leave_exception(_node)
        @containers.pop
      end

      def visit_enum(node)
        enumeration = element('packagedElement', 'uml:Enumeration', node)
        current_container.add_element(enumeration)
      end

      def visit_enumerator(node)
        literal = REXML::Element.new('ownedLiteral')
        literal.add_attribute('xmi:type', 'uml:EnumerationLiteral')
        literal.add_attribute('xmi:id', stable_id(node.scoped_name))
        literal.add_attribute('name', node.lm_name.to_s)
        literal.add_attribute('idl2xmi:index', node.value.to_s)
        apply_annotations(literal, node)
        @elements_by_name[node.enum.scoped_name]&.add_element(literal)
      end

      def visit_bitmask(node)
        mask = element('packagedElement', 'uml:Enumeration', node)
        mask.add_attribute('idl2xmi:kind', 'bitmask')
        mask.add_attribute('idl2xmi:bitBound', node.bitbound_bits.to_s)
        current_container.add_element(mask)
        node.bitvalues.each do |bitvalue|
          literal = REXML::Element.new('ownedLiteral')
          literal.add_attribute('xmi:type', 'uml:EnumerationLiteral')
          literal.add_attribute('xmi:id', stable_id(bitvalue.scoped_name))
          literal.add_attribute('name', bitvalue.lm_name.to_s)
          literal.add_attribute('idl2xmi:position', bitvalue.position.to_s)
          literal.add_attribute('idl2xmi:mask', (1 << bitvalue.position).to_s) if bitvalue.position
          apply_annotations(literal, bitvalue)
          mask.add_element(literal)
        end
      end

      def visit_bitvalue(_node)
        # Bit values are emitted by visit_bitmask; RIDL skips these AST children.
      end

      def visit_bitset(node)
        bitset = element('packagedElement', 'uml:DataType', node)
        bitset.add_attribute('idl2xmi:kind', 'bitset')
        add_generalizations(bitset, node, [node.base].compact)
        current_container.add_element(bitset)
        node.bitfields.each_with_index do |field, index|
          property = REXML::Element.new('ownedAttribute')
          property.add_attribute('xmi:type', 'uml:Property')
          property_name = field.lm_name.to_s
          property_id = property_name.empty? ? "#{node.scoped_name}::bitfield#{index}" : field.scoped_name
          property.add_attribute('xmi:id', stable_id(property_id))
          property.add_attribute('name', property_name) unless property_name.empty?
          property.add_attribute('type', idl_type_name(field.idltype))
          property.add_attribute('idl2xmi:bits', field.bits.to_s)
          apply_annotations(property, field)
          bitset.add_element(property)
        end
      end

      def visit_bitfield(_node)
        # Bit fields are emitted by visit_bitset; RIDL skips these AST children.
      end

      def enter_union(node)
        @forward_declarations.delete(node.scoped_name)
        union = element('packagedElement', 'uml:DataType', node)
        union.add_attribute('idl2xmi:kind', 'union')
        union.add_attribute('idl2xmi:discriminatorType', idl_type_name(node.switchtype))
        current_container.add_element(union)

        # RIDL's AST walk intentionally skips union arms, so emit these members
        # while visiting the union node itself.
        node.members.each do |member|
          property = add_member(union, member)
          property.add_attribute('idl2xmi:labels', member.labels.map { |label| union_label(label) }.join(','))
        end
        @containers.push(union)
      end

      def leave_union(_node)
        @containers.pop
      end

      def declare_union(node)
        declare_classifier(node, 'uml:DataType')
      end

      def visit_const(node)
        constant = REXML::Element.new('ownedAttribute')
        constant.add_attribute('xmi:type', 'uml:Property')
        constant.add_attribute('xmi:id', stable_id(node.scoped_name))
        constant.add_attribute('name', node.lm_name.to_s)
        constant.add_attribute('type', idl_type_name(node.idltype))
        constant.add_attribute('isStatic', 'true')
        constant.add_attribute('isReadOnly', 'true')
        constant.add_attribute('default', node.value.to_s) unless node.value.nil?
        apply_annotations(constant, node)
        current_container.add_element(constant)
      end

      def visit_typedef(node)
        alias_type = element('packagedElement', 'uml:DataType', node)
        alias_type.add_attribute('idl2xmi:kind', 'typedef')
        alias_type.add_attribute('idl2xmi:aliasedType', idl_type_name(node.idltype))
        current_container.add_element(alias_type)
      end

      def visit_operation(node)
        operation = REXML::Element.new('ownedOperation')
        operation.add_attribute('xmi:type', 'uml:Operation')
        operation.add_attribute('xmi:id', stable_id(node.scoped_name))
        operation.add_attribute('name', node.lm_name.to_s)
        operation.add_attribute('idl2xmi:oneway', 'true') if node.oneway
        unless node.raises.empty?
          operation.add_attribute('raisedException', node.raises.map { |exception| type_id(exception) }.join(' '))
        end
        Array(node.context).each_with_index do |value, index|
          context = REXML::Element.new('idl2xmi:context')
          context.add_attribute('xmi:id', stable_id("#{node.scoped_name}::context#{index}"))
          context.add_attribute('value', value.to_s)
          operation.add_element(context)
        end
        unless IDL::Type::Void === node.idltype
          result = REXML::Element.new('ownedParameter')
          result.add_attribute('xmi:type', 'uml:Parameter')
          result.add_attribute('xmi:id', stable_id("#{node.scoped_name}::return"))
          result.add_attribute('name', 'return')
          result.add_attribute('type', idl_type_name(node.idltype))
          result.add_attribute('direction', 'return')
          apply_annotations(result, node)
          operation.add_element(result)
        end
        node.params.each do |parameter|
          argument = REXML::Element.new('ownedParameter')
          argument.add_attribute('xmi:type', 'uml:Parameter')
          argument.add_attribute('xmi:id', stable_id(parameter.scoped_name))
          argument.add_attribute('name', parameter.lm_name.to_s)
          argument.add_attribute('type', idl_type_name(parameter.idltype))
          argument.add_attribute('direction', parameter_direction(parameter.attribute))
          apply_annotations(argument, parameter)
          operation.add_element(argument)
        end
        apply_annotations(operation, node)
        current_container.add_element(operation)
      end

      def visit_attribute(node)
        attribute = REXML::Element.new('ownedAttribute')
        attribute.add_attribute('xmi:type', 'uml:Property')
        attribute.add_attribute('xmi:id', stable_id(node.scoped_name))
        attribute.add_attribute('name', node.lm_name.to_s)
        attribute.add_attribute('type', idl_type_name(node.idltype))
        attribute.add_attribute('isReadOnly', node.readonly.to_s)
        unless node.get_raises.empty?
          attribute.add_attribute('idl2xmi:getRaises', node.get_raises.map { |exception| type_id(exception) }.join(' '))
        end
        unless node.set_raises.empty?
          attribute.add_attribute('idl2xmi:setRaises', node.set_raises.map { |exception| type_id(exception) }.join(' '))
        end
        apply_annotations(attribute, node)
        current_container.add_element(attribute)
      end

      private

      def emit_deferred_nodes(root)
        root.walk_members do |node|
          if IDL::AST::TemplateModule === node
            emit_template_module(node)
          elsif IDL::AST::Porttype === node
            parent = container_for(node.enclosure)
            with_container(parent) { visit_porttype(node) }
          elsif node.respond_to?(:walk_members)
            emit_deferred_nodes(node)
          end
        end
      end

      def emit_template_module(node)
        template = element('packagedElement', 'uml:Package', node)
        template.add_attribute('idl2xmi:kind', 'templateModule')
        current_container_for_enclosure(node).add_element(template)
        @elements_by_name[node.scoped_name] = template
        @containers.push(template)
        node.params.each do |parameter|
          signature_parameter = REXML::Element.new('idl2xmi:templateParameter')
          signature_parameter.add_attribute('xmi:id', stable_id(parameter.scoped_name))
          signature_parameter.add_attribute('name', parameter.lm_name.to_s)
          if parameter.respond_to?(:idltype)
            signature_type = IDL::Type::Any === parameter.idltype ? 'typename' : idl_type_name(parameter.idltype)
            signature_parameter.add_attribute('type', signature_type)
          end
          apply_annotations(signature_parameter, parameter)
          template.add_element(signature_parameter)
        end
        node.walk_members { |member| emit_template_node(member) }
        @containers.pop
      end

      def emit_template_node(node)
        case node
        when IDL::AST::Include
          visit_include(node)
        when IDL::AST::Module
          enter_module(node)
          node.walk_members { |member| emit_template_node(member) }
          leave_module(node)
        when IDL::AST::Interface
          if node.is_forward?
            declare_interface(node)
          else
            enter_interface(node)
            node.walk_members { |member| emit_template_node(member) }
            leave_interface(node)
          end
        when IDL::AST::Component
          if node.is_forward?
            declare_component(node)
          else
            enter_component(node)
            node.walk_members { |member| emit_template_node(member) }
            leave_component(node)
          end
        when IDL::AST::Connector
          enter_connector(node)
          node.walk_members { |member| emit_template_node(member) }
          leave_connector(node)
        when IDL::AST::Home
          enter_home(node)
          node.walk_members { |member| emit_template_node(member) }
          leave_home(node)
        when IDL::AST::Valuetype, IDL::AST::Eventtype
          if node.is_forward?
            declare_valuetype(node)
          else
            enter_valuetype(node)
            node.walk_members { |member| emit_template_node(member) }
            leave_valuetype(node)
          end
        when IDL::AST::Valuebox
          visit_valuebox(node)
        when IDL::AST::Exception
          enter_exception(node)
          node.walk_members { |member| emit_template_node(member) }
          leave_exception(node)
        when IDL::AST::Struct
          if node.is_forward?
            declare_struct(node)
          else
            enter_struct(node)
            node.walk_members { |member| emit_template_node(member) }
            leave_struct(node)
          end
        when IDL::AST::Union
          if node.is_forward?
            declare_union(node)
          else
            enter_union(node)
            node.walk_members { |member| emit_template_node(member) }
            leave_union(node)
          end
        when IDL::AST::Enum
          visit_enum(node)
        when IDL::AST::Enumerator
          visit_enumerator(node)
        when IDL::AST::Const
          visit_const(node)
        when IDL::AST::Typedef
          visit_typedef(node)
        when IDL::AST::Operation
          visit_operation(node)
        when IDL::AST::Attribute
          visit_attribute(node)
        when IDL::AST::Port
          visit_port(node)
        when IDL::AST::Porttype
          visit_porttype(node)
        when IDL::AST::Initializer
          visit_factory(node)
        when IDL::AST::Finder
          visit_finder(node)
        when IDL::AST::BitMask
          visit_bitmask(node)
        when IDL::AST::BitSet
          visit_bitset(node)
        when IDL::AST::TemplateModuleReference
          visit_template_reference(node)
        when IDL::AST::TemplateParam
          # Parameters are emitted with their owning template signature.
        when IDL::AST::Member, IDL::AST::UnionMember, IDL::AST::StateMember,
             IDL::AST::Parameter, IDL::AST::BitValue, IDL::AST::BitField
          # These are emitted by their owning declaration.
        else
          raise "Unsupported IDL AST node in template module: #{node.class.name}"
        end
      end

      def current_container_for_enclosure(node)
        return @model unless node.enclosure && @elements_by_name[node.enclosure.scoped_name]

        @elements_by_name[node.enclosure.scoped_name]
      end

      def container_for(node)
        return @model unless node && @elements_by_name[node.scoped_name]

        @elements_by_name[node.scoped_name]
      end

      def with_container(container)
        @containers.push(container)
        yield
      ensure
        @containers.pop
      end

      def current_container
        @containers.last
      end

      def element(tag, xmi_type, node)
        result = REXML::Element.new(tag)
        result.add_attribute('xmi:type', xmi_type)
        result.add_attribute('xmi:id', stable_id(node.scoped_name))
        result.add_attribute('name', node.lm_name.to_s)
        @elements_by_name[node.scoped_name] = result
        apply_annotations(result, node)
        result
      end

      def idl_type_name(type)
        if type.respond_to?(:cxx_type)
          type.cxx_type
        elsif IDL::Type::Const === type
          idl_type_name(type.type)
        elsif IDL::Type::NodeType === type
          "::#{type.node.scoped_name}"
        elsif IDL::Type::Array === type
          type.sizes.reverse.inject(idl_type_name(type.basetype)) do |element_type, size|
            dimension = constant_value(size)
            "std::array<#{element_type}, #{dimension}>"
          end
        elsif IDL::Type::Sequence === type
          element_type = idl_type_name(type.basetype)
          type.size ? "TAOX11_NAMESPACE::IDL::bounded_vector<#{element_type}, #{constant_value(type.size)}>" : "std::vector<#{element_type}>"
        elsif IDL::Type::Map === type
          key_type = idl_type_name(type.keytype)
          value_type = idl_type_name(type.valuetype)
          type.size ? "TAOX11_NAMESPACE::IDL::bounded_map<#{key_type}, #{value_type}, #{constant_value(type.size)}>" : "std::map<#{key_type}, #{value_type}>"
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

      def parameter_direction(direction)
        {
          IDL::AST::Parameter::IN => 'in',
          IDL::AST::Parameter::OUT => 'out',
          IDL::AST::Parameter::INOUT => 'inout'
        }.fetch(direction)
      end

      def type_id(type)
        return idl_type_name(type) unless type.respond_to?(:node) || type.respond_to?(:scoped_name)

        node = type.respond_to?(:node) ? type.node : type
        node = node.resolved_node if node.respond_to?(:resolved_node)
        stable_id(node.scoped_name)
      end

      def add_member(container, member)
        property = REXML::Element.new('ownedAttribute')
        property.add_attribute('xmi:type', 'uml:Property')
        property.add_attribute('xmi:id', stable_id(member.scoped_name))
        property.add_attribute('name', member.lm_name.to_s)
        property.add_attribute('type', idl_type_name(member.idltype))
        apply_annotations(property, member)
        container.add_element(property)
        property
      end

      def add_state_member(member)
        property = add_member(current_container, member)
        property.add_attribute('idl2xmi:visibility', member.visibility.to_s)
      end

      def visit_initializer(node, kind)
        operation = REXML::Element.new('ownedOperation')
        operation.add_attribute('xmi:type', 'uml:Operation')
        operation.add_attribute('xmi:id', stable_id(node.scoped_name))
        operation.add_attribute('name', node.lm_name.to_s)
        operation.add_attribute('idl2xmi:kind', kind)
        operation.add_attribute('raisedException', node.raises.map { |exception| type_id(exception) }.join(' ')) unless node.raises.empty?
        node.params.each do |parameter|
          argument = REXML::Element.new('ownedParameter')
          argument.add_attribute('xmi:type', 'uml:Parameter')
          argument.add_attribute('xmi:id', stable_id(parameter.scoped_name))
          argument.add_attribute('name', parameter.lm_name.to_s)
          argument.add_attribute('type', idl_type_name(parameter.idltype))
          argument.add_attribute('direction', 'in')
          operation.add_element(argument)
        end
        apply_annotations(operation, node)
        current_container.add_element(operation)
      end

      def declare_classifier(node, xmi_type)
        @forward_declarations[node.scoped_name] = [node, xmi_type]
      end

      def emit_forward_declarations
        @forward_declarations.each_value do |node, xmi_type|
          declaration = element('idl2xmi:forwardDeclaration', xmi_type, node)
          current_container_for_enclosure(node).add_element(declaration)
        end
      end

      def add_generalizations(target, node, bases)
        bases.compact.each do |base|
          general = base.respond_to?(:node) ? base.node : base
          generalization = REXML::Element.new('generalization')
          generalization.add_attribute('xmi:type', 'uml:Generalization')
          generalization.add_attribute('xmi:id', stable_id("#{node.scoped_name}::#{general.scoped_name}"))
          generalization.add_attribute('general', stable_id(general.scoped_name))
          target.add_element(generalization)
        end
      end

      def add_references(target, attribute, references)
        return if references.nil? || references.empty?

        target.add_attribute(attribute, references.map { |reference| type_id(reference) }.join(' '))
      end

      def constant_value(value)
        if value.respond_to?(:node)
          value.node.value
        elsif value.respond_to?(:value)
          value.value
        else
          value
        end
      end

      def apply_annotations(target, node)
        return unless node.respond_to?(:annotations)

        index = 0
        node.annotations.each do |annotation|
          annotation_element = REXML::Element.new('idl2xmi:annotation')
          annotation_element.add_attribute('xmi:id', stable_id("#{node.scoped_name}::annotation#{index}"))
          annotation_element.add_attribute('name', annotation.id.to_s)
          annotation.fields.each do |name, value|
            field = REXML::Element.new('idl2xmi:field')
            field.add_attribute('name', name.to_s)
            field.add_attribute('value', annotation_value(value))
            annotation_element.add_element(field)
          end
          target.add_element(annotation_element)
          index += 1
        end
      end

      def annotation_value(value)
        case value
        when Array
          value.map { |item| annotation_value(item) }.join(',')
        when Hash
          value.map { |key, item| "#{key}=#{annotation_value(item)}" }.join(',')
        else
          value.to_s
        end
      end

      def stable_id(name)
        "idl2xmi-#{name.to_s.gsub(/[^A-Za-z0-9_.-]/, '_')}"
      end
    end
  end
end
