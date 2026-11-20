# frozen_string_literal: true

module IDL
  module Idl2xmi
    class XmiVisitor
      XMI_NS = 'http://www.omg.org/spec/XMI/20131001'.freeze
      UML_NS = 'http://www.omg.org/spec/UML/20161101'.freeze
      CCCMP_ARTIFACT = 'https://www.omg.org/spec/CCCMP/20070501'.freeze
      BASE_IDL_NS = "#{CCCMP_ARTIFACT}/BaseIDL".freeze
      COMPONENT_IDL_NS = "#{CCCMP_ARTIFACT}/ComponentIDL".freeze
      IDL4_NS = 'https://www.remedy.nl/idl2xmi/profile/IDL4/1.0'.freeze
      BASE_IDL_PROFILE_ID = 'EAPK_C6301B3D_712C_46e5_827E_8DEE3343B2E7'.freeze
      COMPONENT_IDL_PROFILE_ID = 'EAPK_EF67E907_FC69_420a_9A9F_E206AAEDAD77'.freeze
      CORBA_PRIMITIVES = {
        IDL::Type::Void => 'void', IDL::Type::Boolean => 'boolean',
        IDL::Type::Char => 'char', IDL::Type::WChar => 'wchar',
        IDL::Type::Octet => 'octet', IDL::Type::Short => 'short',
        IDL::Type::UShort => 'unsignedShort', IDL::Type::Long => 'long',
        IDL::Type::ULong => 'unsignedLong', IDL::Type::LongLong => 'longLong',
        IDL::Type::ULongLong => 'unsignedLongLong', IDL::Type::Float => 'float',
        IDL::Type::Double => 'double', IDL::Type::LongDouble => 'longDouble',
        IDL::Type::Any => 'any'
      }.freeze
      IDL4_PRIMITIVES = {
        IDL::Type::TinyShort => 'int8', IDL::Type::UTinyShort => 'uint8'
      }.freeze
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
        @xmi.add_namespace('BaseIDL', BASE_IDL_NS)
        @xmi.add_namespace('ComponentIDL', COMPONENT_IDL_NS)
        @xmi.add_namespace('IDL4', IDL4_NS)
        @xmi.add_attribute('xmi:version', '2.5.1')
        @model = REXML::Element.new('uml:Model')
        @model.add_attribute('xmi:id', 'idl2xmi-model')
        @model.add_attribute('name', 'IDL model')
        @xmi.add_element(@model)
        @document.add_element(@xmi)
        @containers = [@model]
        @elements_by_name = {}
        @forward_declarations = {}
        @profile_applications = []
        @template_types = {}
        @constants_containers = {}
        emit_corba_primitive_package
      end

      def visit_nodes(parser)
        parser.walk_nodes(self)
        emit_deferred_nodes(parser.root) if parser.respond_to?(:root) && parser.root
        emit_forward_declarations
        emit_profile_applications
        @document.write(@output, 2)
        @output.write("\n")
      end

      def enter_module(node)
        package = element('packagedElement', 'uml:Package', node)
        if node.respond_to?(:is_templated?) && node.is_templated?
          apply_idl4_profile('TemplateBinding', 'base_Package', package,
                             'template' => stable_id(node.template.scoped_name),
                             'arguments' => node.template_params.map { |param| idl_type_name(param) }.join(','))
        end
        current_container.add_element(package)
        apply_profile('BaseIDL', 'CORBAModule', 'base_Package', package)
        @containers.push(package)
      end

      def leave_module(_node)
        @containers.pop
      end

      def visit_include(node)
        include_element = extension_element('include')
        include_element.add_attribute('xmi:id', stable_id("include::#{node.filename}"))
        include_element.add_attribute('filename', node.filename.to_s)
        current_container.add_element(include_element)
      end

      def enter_interface(node)
        @forward_declarations.delete(node.scoped_name)
        interface = element('packagedElement', 'uml:Interface', node)
        interface.add_attribute('isAbstract', node.is_abstract?.to_s)
        apply_profile('BaseIDL', 'CORBAInterface', 'base_Interface', interface,
                      'isLocal' => node.is_local?.to_s)
        apply_idl4_profile('PseudoInterface', 'base_Interface', interface) if node.is_pseudo?
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
        component = element('packagedElement', 'uml:Class', node)
        apply_profile('ComponentIDL', 'CORBAComponent', 'base_Class', component)
        add_generalizations(component, node, [node.base].compact)
        add_references(component, 'supports', node.interfaces)
        current_container.add_element(component)
        @containers.push(component)
      end

      def leave_component(_node)
        @containers.pop
      end

      def declare_component(node)
        declare_classifier(node, 'uml:Class')
      end

      def enter_connector(node)
        connector = element('packagedElement', 'uml:Component', node)
        apply_idl4_profile('Connector', 'base_Component', connector)
        add_generalizations(connector, node, [node.base].compact)
        current_container.add_element(connector)
        @containers.push(connector)
      end

      def leave_connector(_node)
        @containers.pop
      end

      def enter_home(node)
        home = element('packagedElement', 'uml:Interface', node)
        apply_profile('ComponentIDL', 'CORBAHome', 'base_Interface', home)
        add_component_association(node, home, 'CORBAManages', node.component)
        add_component_association(node, home, 'CORBAPrimaryKey', node.primarykey) if node.primarykey
        add_generalizations(home, node, [node.base].compact)
        add_references(home, 'supports', node.interfaces)
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
        classic_ports = {
            'facet' => ['CORBAProvides', {}],
            'receptacle' => ['CORBAUses', { 'multiple' => node.multiple?.to_s }],
            'emitter' => ['CORBAEmits', {}],
            'publisher' => ['CORBAPublishes', {}],
            'consumer' => ['CORBAConsumes', {}]
        }
        if (mapping = classic_ports[node.porttype.to_s])
          apply_profile('ComponentIDL', mapping[0], 'base_Port', port, mapping[1])
        else
          apply_idl4_profile('Port', 'base_Port', port,
                             'kind' => node.porttype.to_s,
                             'multiple' => node.multiple?.to_s)
        end
        apply_annotations(port, node)
        current_container.add_element(port)
      end

      def visit_porttype(node)
        porttype = element('packagedElement', 'uml:Interface', node)
        apply_idl4_profile('PortType', 'base_Interface', porttype)
        current_container.add_element(porttype)
        @containers.push(porttype)
        node.ports.each { |port| visit_port(port) }
        node.attributes.each { |attribute| visit_attribute(attribute) }
        @containers.pop
      end

      def visit_valuebox(node)
        valuebox = element('packagedElement', 'uml:DataType', node)
        add_generalization_to_type(valuebox, node.boxed_type, "#{node.scoped_name}::boxed")
        apply_profile('BaseIDL', 'CORBABoxedValue', 'base_DataType', valuebox)
        current_container.add_element(valuebox)
      end

      def enter_valuetype(node)
        @forward_declarations.delete(node.scoped_name)
        valuetype = element('packagedElement', 'uml:Interface', node)
        valuetype.add_attribute('isAbstract', node.is_abstract?.to_s)
        apply_profile('BaseIDL', 'CORBAValue', 'base_Interface', valuetype,
                      'isCustom' => node.is_custom?.to_s,
                      'isTruncatable' => node.is_truncatable?.to_s)
        apply_profile('ComponentIDL', 'CORBAEvent', 'base_Interface', valuetype) if node.is_a?(IDL::AST::Eventtype)
        add_generalizations(valuetype, node, node.bases)
        add_references(valuetype, 'supports', node.interfaces)
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
        declare_classifier(node, 'uml:Interface')
      end

      def visit_factory(node)
        visit_initializer(node, 'factory')
      end

      def visit_finder(node)
        visit_initializer(node, 'finder')
      end

      def visit_template_reference(node)
        reference = extension_element('templateInstantiation')
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
        apply_profile('BaseIDL', 'CORBAStruct', 'base_DataType', datatype)
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
        apply_profile('BaseIDL', 'CORBAException', 'base_DataType', exception)
        current_container.add_element(exception)
        node.members.each { |member| add_member(exception, member) }
        @containers.push(exception)
      end

      def leave_exception(_node)
        @containers.pop
      end

      def visit_enum(node)
        enumeration = element('packagedElement', 'uml:Enumeration', node)
        members = node.respond_to?(:enumerators) ? node.enumerators.map { |value| value.lm_name.to_s }.join(',') : ''
        apply_profile('BaseIDL', 'CORBAEnum', 'base_Enumeration', enumeration,
                      'members' => members)
        current_container.add_element(enumeration)
      end

      def visit_enumerator(node)
        literal = REXML::Element.new('ownedLiteral')
        literal.add_attribute('xmi:type', 'uml:EnumerationLiteral')
        literal.add_attribute('xmi:id', stable_id(node.scoped_name))
        literal.add_attribute('name', node.lm_name.to_s)
        apply_idl4_profile('EnumLiteralValue', 'base_EnumerationLiteral', literal,
                           'value' => node.value.to_s)
        apply_annotations(literal, node)
        @elements_by_name[node.enum.scoped_name]&.add_element(literal)
      end

      def visit_bitmask(node)
        mask = element('packagedElement', 'uml:Enumeration', node)
        apply_idl4_profile('BitMask', 'base_Enumeration', mask,
                           'bitBound' => node.bitbound_bits.to_s)
        current_container.add_element(mask)
        node.bitvalues.each do |bitvalue|
          literal = REXML::Element.new('ownedLiteral')
          literal.add_attribute('xmi:type', 'uml:EnumerationLiteral')
          literal.add_attribute('xmi:id', stable_id(bitvalue.scoped_name))
          literal.add_attribute('name', bitvalue.lm_name.to_s)
          apply_idl4_profile('BitValue', 'base_EnumerationLiteral', literal,
                             'position' => bitvalue.position.to_s)
          apply_annotations(literal, bitvalue)
          mask.add_element(literal)
        end
      end

      def visit_bitvalue(_node)
        # Bit values are emitted by visit_bitmask; RIDL skips these AST children.
      end

      def visit_bitset(node)
        bitset = element('packagedElement', 'uml:DataType', node)
        apply_idl4_profile('BitSet', 'base_DataType', bitset)
        add_generalizations(bitset, node, [node.base].compact)
        current_container.add_element(bitset)
        node.bitfields.each_with_index do |field, index|
          property = REXML::Element.new('ownedAttribute')
          property.add_attribute('xmi:type', 'uml:Property')
          property_name = field.lm_name.to_s
          property_id = property_name.empty? ? "#{node.scoped_name}::bitfield#{index}" : field.scoped_name
          property.add_attribute('xmi:id', stable_id(property_id))
          property.add_attribute('name', property_name) unless property_name.empty?
          property.add_attribute('type', member_type_id(field.idltype))
          apply_idl4_profile('BitField', 'base_Property', property,
                             'bits' => field.bits.to_s)
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
        apply_profile('BaseIDL', 'CORBAUnion', 'base_DataType', union)
        discriminator = REXML::Element.new('ownedAttribute')
        discriminator.add_attribute('xmi:type', 'uml:Property')
        discriminator.add_attribute('xmi:id', stable_id("#{node.scoped_name}::discriminator"))
        discriminator.add_attribute('name', 'discriminator')
        discriminator.add_attribute('type', type_id(node.switchtype))
        discriminator.add_attribute('isOrdered', 'true')
        union.add_element(discriminator)
        apply_profile('BaseIDL', 'CORBASwitch', 'base_Property', discriminator)
        current_container.add_element(union)

        # RIDL's AST walk intentionally skips union arms, so emit these members
        # while visiting the union node itself.
        node.members.each do |member|
          property = add_member(union, member)
          labels = member.labels.map { |label| union_label(label) }
          stereotype = labels.include?('default') ? 'CORBADefault' : 'CORBACase'
          tags = stereotype == 'CORBACase' ? { 'label' => labels.join(',') } : {}
          apply_profile('BaseIDL', stereotype, 'base_Property', property, tags)
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
        constant.add_attribute('type', member_type_id(node.idltype))
        constant.add_attribute('isStatic', 'true')
        constant.add_attribute('isReadOnly', 'true')
        constant.add_attribute('default', node.value.to_s) unless node.value.nil?
        apply_annotations(constant, node)
        constant_owner.add_element(constant)
        apply_profile('BaseIDL', 'CORBAConstant', 'base_Property', constant,
                      'constValue' => node.value.to_s)
      end

      def visit_typedef(node)
        alias_type = element('packagedElement', 'uml:DataType', node)
        apply_standard_typedef(alias_type, node)
        current_container.add_element(alias_type)
      end

      def visit_operation(node)
        operation = REXML::Element.new('ownedOperation')
        operation.add_attribute('xmi:type', 'uml:Operation')
        operation.add_attribute('xmi:id', stable_id(node.scoped_name))
        operation.add_attribute('name', node.lm_name.to_s)
        apply_idl4_profile('Oneway', 'base_Operation', operation) if node.oneway
        unless node.raises.empty?
          operation.add_attribute('raisedException', node.raises.map { |exception| type_id(exception) }.join(' '))
        end
        unless Array(node.context).empty?
          apply_idl4_profile('OperationContext', 'base_Operation', operation,
                             'value' => Array(node.context).join(' '))
        end
        unless IDL::Type::Void === node.idltype
          result = REXML::Element.new('ownedParameter')
          result.add_attribute('xmi:type', 'uml:Parameter')
          result.add_attribute('xmi:id', stable_id("#{node.scoped_name}::return"))
          result.add_attribute('name', 'return')
          result.add_attribute('type', member_type_id(node.idltype))
          result.add_attribute('direction', 'return')
          apply_annotations(result, node)
          operation.add_element(result)
        end
        node.params.each do |parameter|
          argument = REXML::Element.new('ownedParameter')
          argument.add_attribute('xmi:type', 'uml:Parameter')
          argument.add_attribute('xmi:id', stable_id(parameter.scoped_name))
          argument.add_attribute('name', parameter.lm_name.to_s)
          argument.add_attribute('type', member_type_id(parameter.idltype))
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
        attribute.add_attribute('type', member_type_id(node.idltype))
        attribute.add_attribute('isReadOnly', node.readonly.to_s)
        if !node.get_raises.empty? || !node.set_raises.empty?
          apply_idl4_profile('AttributeRaises', 'base_Property', attribute,
                             'getRaises' => node.get_raises.map { |exception| type_id(exception) }.join(' '),
                             'setRaises' => node.set_raises.map { |exception| type_id(exception) }.join(' '))
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
        apply_idl4_profile('TemplateModule', 'base_Package', template)
        current_container_for_enclosure(node).add_element(template)
        @elements_by_name[node.scoped_name] = template
        @containers.push(template)
        node.params.each do |parameter|
          signature_parameter = extension_element('templateParameter')
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

      def constant_owner
        return current_container unless %w[uml:Package uml:Model].include?(current_container.attributes['xmi:type']) || current_container == @model

        key = current_container.attributes['xmi:id']
        @constants_containers[key] ||= begin
          constants = REXML::Element.new('packagedElement')
          constants.add_attribute('xmi:type', 'uml:Class')
          constants.add_attribute('xmi:id', stable_id("#{key}::Constants"))
          constants.add_attribute('name', 'Constants')
          current_container.add_element(constants)
          apply_profile('BaseIDL', 'CORBAConstants', 'base_Class', constants)
          constants
        end
      end

      def apply_standard_typedef(alias_type, node)
        type = node.idltype
        case type
        when IDL::Type::Array
          add_template_members(alias_type, type.basetype, 1, 1, node.scoped_name)
          apply_profile('BaseIDL', 'CORBAArray', 'base_DataType', alias_type,
                        'index' => type.sizes.map { |size| constant_value(size) }.join(','))
        when IDL::Type::Sequence
          upper = type.size ? constant_value(type.size).to_i - 1 : '*'
          add_template_members(alias_type, type.basetype, 0, upper, node.scoped_name)
          tags = type.size ? { 'bound' => constant_value(type.size).to_s } : {}
          apply_profile('BaseIDL', 'CORBASequence', 'base_DataType', alias_type, tags)
        when IDL::Type::String, IDL::Type::WString
          if type.size
            stereotype = IDL::Type::String === type ? 'CORBAString' : 'CORBAWstring'
            apply_profile('BaseIDL', stereotype, 'base_DataType', alias_type,
                          'bound' => constant_value(type.size).to_s)
          else
            add_generalization_to_type(alias_type, type, "#{node.scoped_name}::alias")
            apply_profile('BaseIDL', 'CORBATypeDef', 'base_DataType', alias_type)
          end
        when IDL::Type::Fixed
          apply_profile('BaseIDL', 'CORBAFixed', 'base_DataType', alias_type,
                        'digits' => type.digits.to_s, 'scale' => type.scale.to_s)
        when IDL::Type::Map
          apply_idl4_profile('Map', 'base_DataType', alias_type,
                             'keyType' => standard_type_id(type.keytype),
                             'valueType' => standard_type_id(type.valuetype),
                             'bound' => (constant_value(type.size).to_s if type.size))
        else
          add_generalization_to_type(alias_type, type, "#{node.scoped_name}::alias")
          apply_profile('BaseIDL', 'CORBATypeDef', 'base_DataType', alias_type)
        end
      end

      def add_template_members(container, element_type, lower, upper, scope)
        members = REXML::Element.new('ownedAttribute')
        members.add_attribute('xmi:type', 'uml:Property')
        members.add_attribute('xmi:id', stable_id("#{scope}::members"))
        members.add_attribute('name', 'members')
        members.add_attribute('type', type_id(element_type))
        members.add_attribute('lower', lower.to_s)
        members.add_attribute('upper', upper.to_s)
        container.add_element(members)
      end

      def add_component_association(node, home, stereotype, target_type)
        association = REXML::Element.new('packagedElement')
        association.add_attribute('xmi:type', 'uml:Association')
        association.add_attribute('xmi:id', stable_id("#{node.scoped_name}::#{stereotype}"))
        association.add_attribute('name', stereotype)
        [[home.attributes['xmi:id'], 'home'], [type_id(target_type), 'target']].each do |type, role|
          owned_end = REXML::Element.new('ownedEnd')
          owned_end.add_attribute('xmi:type', 'uml:Property')
          owned_end.add_attribute('xmi:id', stable_id("#{node.scoped_name}::#{stereotype}::#{role}"))
          owned_end.add_attribute('name', role)
          owned_end.add_attribute('type', type)
          association.add_element(owned_end)
        end
        current_container.add_element(association)
        apply_profile('ComponentIDL', stereotype, 'base_Association', association)
      end

      def extension_element(name)
        REXML::Element.new("IDL4:#{name}")
      end

      def apply_profile(prefix, stereotype, base_attribute, target, tags = {})
        application = REXML::Element.new("#{prefix}:#{stereotype}")
        element_id = target.attributes['xmi:id']
        application.add_attribute('xmi:id', stable_id("profile::#{prefix}::#{stereotype}::#{element_id}"))
        application.add_attribute(base_attribute, element_id)
        tags.each { |name, value| application.add_attribute(name, value) unless value.nil? }
        @profile_applications << application
      end

      def apply_idl4_profile(stereotype, base_attribute, target, tags = {})
        apply_profile('IDL4', stereotype, base_attribute, target, tags)
      end

      def emit_profile_applications
        add_profile_application('BaseIDL', BASE_IDL_PROFILE_ID)
        add_profile_application('ComponentIDL', COMPONENT_IDL_PROFILE_ID)
        add_profile_application('IDL4', nil, IDL4_NS)
        @profile_applications.each { |application| @xmi.add_element(application) }
      end

      def add_profile_application(name, fragment, href = CCCMP_ARTIFACT)
        application = REXML::Element.new('profileApplication')
        application.add_attribute('xmi:type', 'uml:ProfileApplication')
        application.add_attribute('xmi:id', stable_id("profileApplication::#{name}"))
        profile = REXML::Element.new('appliedProfile')
        profile.add_attribute('href', fragment ? "#{href}##{fragment}" : href)
        application.add_element(profile)
        @model.add_element(application)
      end

      def emit_corba_primitive_package
        package = REXML::Element.new('packagedElement')
        package.add_attribute('xmi:type', 'uml:Package')
        package.add_attribute('xmi:id', stable_id('CORBA'))
        package.add_attribute('name', 'CORBA')
        @model.add_element(package)

        (CORBA_PRIMITIVES.values + %w[string wstring]).uniq.each do |name|
          primitive = REXML::Element.new('packagedElement')
          primitive.add_attribute('xmi:type', 'uml:DataType')
          primitive.add_attribute('xmi:id', primitive_id(name))
          primitive.add_attribute('name', name)
          package.add_element(primitive)
          apply_profile('BaseIDL', 'CORBAPrimitive', 'base_DataType', primitive)
        end
        { 'Object' => ['CORBAInterface', { 'isLocal' => 'false' }],
          'ValueBase' => ['CORBAValue', { 'isCustom' => 'false', 'isTruncatable' => 'false' }] }.each do |name, (stereotype, tags)|
          predefined = REXML::Element.new('packagedElement')
          predefined.add_attribute('xmi:type', 'uml:Interface')
          predefined.add_attribute('xmi:id', primitive_id(name))
          predefined.add_attribute('name', name)
          package.add_element(predefined)
          apply_profile('BaseIDL', stereotype, 'base_Interface', predefined, tags)
        end
        IDL4_PRIMITIVES.values.each do |name|
          primitive = REXML::Element.new('packagedElement')
          primitive.add_attribute('xmi:type', 'uml:DataType')
          primitive.add_attribute('xmi:id', primitive_id(name))
          primitive.add_attribute('name', name)
          package.add_element(primitive)
          apply_idl4_profile('Primitive', 'base_DataType', primitive, 'idlName' => name)
        end
        @corba_package = package
      end

      def primitive_id(name)
        stable_id("CORBA::#{name}")
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
        standard_type_id(type)
      end

      def member_type_id(type)
        type_id(type)
      end

      def standard_type_id(type)
        return standard_type_id(type.type) if IDL::Type::Const === type
        if IDL::Type::NodeType === type
          node = type.node
          node = node.resolved_node if node.respond_to?(:resolved_node)
          return stable_id(node.scoped_name)
        end
        return stable_id(type.scoped_name) if type.respond_to?(:scoped_name)

        primitive = CORBA_PRIMITIVES[type.class]
        return primitive_id(primitive) if primitive
        idl4_primitive = IDL4_PRIMITIVES[type.class]
        return primitive_id(idl4_primitive) if idl4_primitive
        return primitive_id('Object') if IDL::Type::Object === type
        return primitive_id('ValueBase') if IDL::Type::ValueBase === type
        if IDL::Type::String === type || IDL::Type::WString === type
          return primitive_id(IDL::Type::String === type ? 'string' : 'wstring') unless type.size
        end

        ensure_template_type(type)
      end

      def ensure_template_type(type)
        signature = idl_type_name(type)
        return @template_types[signature] if @template_types.key?(signature)

        classifier = REXML::Element.new('packagedElement')
        classifier.add_attribute('xmi:type', 'uml:DataType')
        classifier.add_attribute('xmi:id', stable_id("CORBA::template::#{signature}"))
        classifier.add_attribute('name', signature)
        @corba_package.add_element(classifier)
        @template_types[signature] = classifier.attributes['xmi:id']

        case type
        when IDL::Type::String, IDL::Type::WString
          stereotype = IDL::Type::String === type ? 'CORBAString' : 'CORBAWstring'
          apply_profile('BaseIDL', stereotype, 'base_DataType', classifier,
                        'bound' => constant_value(type.size).to_s)
        when IDL::Type::Fixed
          apply_profile('BaseIDL', 'CORBAFixed', 'base_DataType', classifier,
                        'digits' => type.digits.to_s, 'scale' => type.scale.to_s)
        when IDL::Type::Sequence
          upper = type.size ? constant_value(type.size).to_i - 1 : '*'
          add_template_members(classifier, type.basetype, 0, upper, signature)
          tags = type.size ? { 'bound' => constant_value(type.size).to_s } : {}
          apply_profile('BaseIDL', 'CORBAAnonymousSequence', 'base_DataType', classifier, tags)
        when IDL::Type::Array
          add_template_members(classifier, type.basetype, 1, 1, signature)
          apply_profile('BaseIDL', 'CORBAAnonymousArray', 'base_DataType', classifier,
                        'index' => type.sizes.map { |size| constant_value(size) }.join(','))
        when IDL::Type::Map
          apply_idl4_profile('Map', 'base_DataType', classifier,
                             'keyType' => standard_type_id(type.keytype),
                             'valueType' => standard_type_id(type.valuetype),
                             'bound' => (constant_value(type.size).to_s if type.size))
        when IDL::Type::Native
          apply_idl4_profile('Native', 'base_DataType', classifier)
        else
          apply_idl4_profile('UnmappedType', 'base_DataType', classifier,
                             'idlType' => type.typename.to_s)
        end
        @template_types[signature]
      end

      def add_generalization_to_type(target, type, suffix)
        generalization = REXML::Element.new('generalization')
        generalization.add_attribute('xmi:type', 'uml:Generalization')
        generalization.add_attribute('xmi:id', stable_id(suffix))
        generalization.add_attribute('general', type_id(type))
        target.add_element(generalization)
      end

      def add_member(container, member)
        property = REXML::Element.new('ownedAttribute')
        property.add_attribute('xmi:type', 'uml:Property')
        property.add_attribute('xmi:id', stable_id(member.scoped_name))
        property.add_attribute('name', member.lm_name.to_s)
        property.add_attribute('type', member_type_id(member.idltype))
        property.add_attribute('isOrdered', 'true')
        apply_annotations(property, member)
        container.add_element(property)
        apply_profile('BaseIDL', 'CORBAField', 'base_Property', property,
                      'identifier' => member.lm_name.to_s)
        property
      end

      def add_state_member(member)
        property = add_member(current_container, member)
        apply_profile('BaseIDL', 'CORBAValueMember', 'base_Property', property,
                      'isPublicMember' => (member.visibility.to_s == 'public').to_s)
      end

      def visit_initializer(node, kind)
        operation = REXML::Element.new('ownedOperation')
        operation.add_attribute('xmi:type', 'uml:Operation')
        operation.add_attribute('xmi:id', stable_id(node.scoped_name))
        operation.add_attribute('name', node.lm_name.to_s)
        home_member = node.respond_to?(:enclosure) && IDL::AST::Home === node.enclosure
        stereotype = if kind == 'finder'
                       'CORBAFinder'
                     elsif home_member
                       'CORBAFactory'
                     else
                       'CORBAValueFactory'
                     end
        profile = home_member || kind == 'finder' ? 'ComponentIDL' : 'BaseIDL'
        apply_profile(profile, stereotype, 'base_Operation', operation)
        operation.add_attribute('raisedException', node.raises.map { |exception| type_id(exception) }.join(' ')) unless node.raises.empty?
        node.params.each do |parameter|
          argument = REXML::Element.new('ownedParameter')
          argument.add_attribute('xmi:type', 'uml:Parameter')
          argument.add_attribute('xmi:id', stable_id(parameter.scoped_name))
          argument.add_attribute('name', parameter.lm_name.to_s)
          argument.add_attribute('type', member_type_id(parameter.idltype))
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
          declaration = element('packagedElement', xmi_type, node)
          apply_idl4_profile('ForwardDeclaration', "base_#{xmi_type.split(':').last}", declaration)
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

        if attribute == 'supports'
          references.each_with_index do |reference, index|
            generalization = REXML::Element.new('generalization')
            generalization.add_attribute('xmi:type', 'uml:Generalization')
            generalization.add_attribute('xmi:id', stable_id("#{target.attributes['xmi:id']}::supports::#{index}"))
            generalization.add_attribute('general', type_id(reference))
            target.add_element(generalization)
            apply_profile('BaseIDL', 'CORBASupports', 'base_Generalization', generalization)
          end
          return
        end

        raise "Unsupported classifier reference kind: #{attribute}"
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
          comment = REXML::Element.new('ownedComment')
          comment.add_attribute('xmi:type', 'uml:Comment')
          comment.add_attribute('xmi:id', stable_id("#{node.scoped_name}::annotation#{index}"))
          comment.add_attribute('annotatedElement', target.attributes['xmi:id'])
          values = annotation.fields.map { |name, value| "#{name}=#{annotation_value(value)}" }.join(';')
          body = REXML::Element.new('body')
          body.text = "@#{annotation.id}(#{values})"
          comment.add_element(body)
          target.add_element(comment)
          apply_idl4_profile('AnnotationApplication', 'base_Comment', comment,
                             'name' => annotation.id.to_s, 'values' => values)
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
