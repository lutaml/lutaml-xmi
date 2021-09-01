require "nokogiri"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"

module Lutaml
  module XMI
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class XML
        LOVER_VALUE_MAPPINGS = {
          "0" => "C",
          "1" => "M",
        }.freeze
        attr_reader :main_model, :xmi_cache

        # @param [String] io - file object with path to .xmi file
        #        [Hash] options - options for parsing
        #
        # @return [Lutaml::XMI::Model::Document]
        def self.parse(io, _options = {})
          new.parse(Nokogiri::XML(io.read))
        end

        def parse(xmi_doc)
          @xmi_cache = {}
          @main_model = xmi_doc
          ::Lutaml::Uml::Document
            .new(serialize_to_hash(xmi_doc))
        end

        private

        def serialize_to_hash(xmi_doc)
          model = xmi_doc.xpath('//uml:Model[@xmi:type="uml:Model"]').first
          {
            name: model["name"],
            packages: serialize_model_packages(model)
          }
        end

        def serialize_model_packages(model)
          model.xpath('./packagedElement[@xmi:type="uml:Package"]').map do |package|
            {
              xmi_id: package["xmi:id"],
              name: package["name"],
              classes: serialize_model_classes(package),
              enums: serialize_model_enums(package),
              data_types: serialize_model_data_types(package),
              diagrams: serialize_model_diagrams(package),
              packages: serialize_model_packages(package),
              definition: doc_node_attribute_value(package, "documentation"),
              stereotype: doc_node_attribute_value(package, "stereotype")
            }
          end
        end

        def serialize_model_classes(model)
          model.xpath('./packagedElement[@xmi:type="uml:Class" or @xmi:type="uml:AssociationClass"]').map do |klass|
            {
              xmi_id: klass["xmi:id"],
              xmi_uuid: klass["xmi:uuid"],
              name: klass["name"],
              package: model,
              attributes: serialize_class_attributes(klass),
              associations: serialize_model_associations(klass),
              operations: serialize_class_operations(klass),
              constraints: serialize_class_constraints(klass),
              is_abstract: doc_node_attribute_value(klass, "isAbstract"),
              definition: doc_node_attribute_value(klass, "documentation"),
              stereotype: doc_node_attribute_value(klass, "stereotype")
            }
          end
        end

        def serialize_model_enums(model)
          model.xpath('./packagedElement[@xmi:type="uml:Enumeration"]').map do |enum|
            attributes = enum
              .xpath('.//ownedLiteral[@xmi:type="uml:EnumerationLiteral"]')
              .map do |value|
                type = value.xpath(".//type").first || {}
                {
                  name: value["name"],
                  type: lookup_entity_name(type["xmi:idref"]) || type["xmi:idref"],
                  definition: lookup_attribute_definition(value),
                }
              end
            {
              xmi_id: enum["xmi:id"],
              xmi_uuid: enum["xmi:uuid"],
              name: enum["name"],
              values: attributes,
              definition: doc_node_attribute_value(enum, "documentation"),
              stereotype: doc_node_attribute_value(enum, "stereotype"),
            }
          end
        end

        def serialize_model_data_types(model)
          model.xpath('./packagedElement[@xmi:type="uml:DataType"]').map do |klass|
            {
              xmi_id: klass["xmi:id"],
              xmi_uuid: klass["xmi:uuid"],
              name: klass["name"],
              attributes: serialize_class_attributes(klass),
              operations: serialize_class_operations(klass),
              associations: serialize_model_associations(klass),
              constraints: serialize_class_constraints(klass),
              is_abstract: doc_node_attribute_value(klass, "isAbstract"),
              definition: doc_node_attribute_value(klass, "documentation"),
              stereotype: doc_node_attribute_value(klass, "stereotype"),
            }
          end
        end

        def serialize_model_diagrams(node)
          main_model.xpath(%(//diagrams/diagram/model[@package="#{node['xmi:id']}"])).map do |diagram_model|
            diagram = diagram_model.parent
            properties = diagram.children.find {|n| n.name == 'properties' }
            {
              xmi_id: diagram["xmi:id"],
              name: properties["name"],
              definition: properties.attributes['documentation']&.value
            }
          end
        end

        def serialize_model_associations(klass)
          xmi_id = klass["xmi:id"]
          main_model.xpath(%(//element[@xmi:idref="#{xmi_id}"]/links/*)).map do |link|
            link_member_name = link.attributes["start"].value == xmi_id ? "end" : "start"
            linke_owner_name = link_member_name == "start" ? "end" : "start"
            member_end, member_end_type, member_end_cardinality, member_end_attribute_name = serialize_member_type(xmi_id, link, link_member_name)
            owner_end, owner_end_cardinality, owner_end_attribute_name = serialize_owned_type(xmi_id, link, linke_owner_name)
            if member_end && ((member_end_type != 'aggregation') || (member_end_type == 'aggregation' && member_end_attribute_name))
              doc_node_name = link_member_name == "start" ? "source" : "target"
              definition_node = main_model.xpath(%(//connector[@xmi:idref="#{link['xmi:id']}"]/#{doc_node_name}/documentation)).first
              definition = definition_node.attributes['value']&.value if definition_node
              {
                xmi_id: link["xmi:id"],
                member_end: member_end,
                member_end_type: member_end_type,
                member_end_cardinality: member_end_cardinality,
                member_end_attribute_name: member_end_attribute_name,
                owner_end: owner_end,
                definition: definition
              }
            end
          end.uniq
        end

        def serialize_class_operations(klass)
          klass.xpath('.//ownedOperation').map do |attribute|
            type = attribute.xpath(".//type").first || {}
            if attribute.attributes["association"].nil?
              {
                # TODO: xmi_id
                # xmi_id: klass['xmi:id'],
                name: attribute["name"],
                definition: lookup_attribute_definition(attribute),
              }
            end
          end.compact
        end

        def serialize_class_constraints(klass)
          class_element_metadata(klass).xpath("./constraints/constraint").map do |constraint|
            {
              xmi_id: constraint["xmi:id"],
              body: constraint["name"],
              definition: constraint["description"]
            }
          end
        end

        def serialize_owned_type(owner_xmi_id, link, linke_owner_name)
          return if link.name == 'NoteLink'
          return generalization_association(owner_xmi_id, link) if link.name == "Generalization"

          xmi_id = link.attributes[linke_owner_name].value
          owner_end = lookup_entity_name(xmi_id) || connector_source_name(xmi_id)

          if link.name == "Association"
            assoc_connector = main_model.xpath(%(//connector[@xmi:idref="#{link['xmi:id']}"]/source)).first
            if assoc_connector
              connector_type = assoc_connector.children.find { |node| node.name == 'type' }
              if connector_type && connector_type.attributes['multiplicity']
                cardinality = connector_type.attributes['multiplicity']&.value&.split('..')
                cardinality.unshift('1') if cardinality.length == 1
                min, max = cardinality
              end
              connector_role = assoc_connector.children.find { |node| node.name == 'role' }
              if connector_role
                owned_attribute_name = connector_role.attributes["name"]&.value
              end
              owned_cardinality = { "min" => LOVER_VALUE_MAPPINGS[min], "max" => max }
            end
          else
            owned_node = main_model.xpath(%(//ownedAttribute[@association]/type[@xmi:idref="#{xmi_id}"])).first
            if owned_node
              assoc = owned_node.parent
              owned_cardinality = { "min" => cardinality_min_value(assoc), "max" => cardinality_max_value(assoc) }
              owned_attribute_name = assoc.attributes["name"]&.value
            end
          end

          [owner_end, owned_cardinality, owned_attribute_name]
        end

        def serialize_member_type(owner_xmi_id, link, link_member_name)
          return if link.name == 'NoteLink'
          return generalization_association(owner_xmi_id, link) if link.name == "Generalization"

          xmi_id = link.attributes[link_member_name].value
          member_end = lookup_entity_name(xmi_id) || connector_source_name(xmi_id)

          if link.name == "Association"
            connector_type = link_member_name == "start" ? "source" : "target"
            assoc_connector = main_model.xpath(%(//connector[@xmi:idref="#{link['xmi:id']}"]/#{connector_type})).first
            if assoc_connector
              connector_type = assoc_connector.children.find { |node| node.name == 'type' }
              if connector_type && connector_type.attributes['multiplicity']
                cardinality = connector_type.attributes['multiplicity']&.value&.split('..')
                cardinality.unshift('1') if cardinality.length == 1
                min, max = cardinality
              end
              connector_role = assoc_connector.children.find { |node| node.name == 'role' }
              if connector_role
                member_end_attribute_name = connector_role.attributes["name"]&.value
              end
              member_end_cardinality = { "min" => LOVER_VALUE_MAPPINGS[min], "max" => max }
            end
          else
            member_end_node = main_model.xpath(%(//ownedAttribute[@association]/type[@xmi:idref="#{xmi_id}"])).first
            if member_end_node
              assoc = member_end_node.parent
              member_end_cardinality = { "min" => cardinality_min_value(assoc), "max" => cardinality_max_value(assoc) }
              member_end_attribute_name = assoc.attributes["name"]&.value
            end
          end

          [member_end, "aggregation", member_end_cardinality, member_end_attribute_name]
        end

        def generalization_association(owner_xmi_id, link)
          if link.attributes["start"].value == owner_xmi_id
            xmi_id = link.attributes["end"].value
            member_end_type = "inheritance"
            member_end = lookup_entity_name(xmi_id) || connector_target_name(xmi_id)
          else
            xmi_id = link.attributes["start"].value
            member_end_type = "generalization"
            member_end = lookup_entity_name(xmi_id) || connector_source_name(xmi_id)
          end

          member_end_node = main_model.xpath(%(//ownedAttribute[@association]/type[@xmi:idref="#{xmi_id}"])).first
          if member_end_node
            assoc = member_end_node.parent
            member_end_cardinality = { "min" => cardinality_min_value(assoc), "max" => cardinality_max_value(assoc) }
          end

          [member_end, member_end_type, member_end_cardinality, nil]
        end

        def class_element_metadata(klass)
          main_model.xpath(%(//element[@xmi:idref="#{klass['xmi:id']}"]))
        end

        def serialize_class_attributes(klass)
          klass.xpath('.//ownedAttribute[@xmi:type="uml:Property"]').map do |attribute|
            type = attribute.xpath(".//type").first || {}
            if attribute.attributes["association"].nil?
              {
                # TODO: xmi_id
                # xmi_id: klass['xmi:id'],
                name: attribute["name"],
                type: lookup_entity_name(type["xmi:idref"]) || type["xmi:idref"],
                is_derived: attribute["isDerived"],
                cardinality: { "min" => cardinality_min_value(attribute), "max" => cardinality_max_value(attribute) },
                definition: lookup_attribute_definition(attribute),
              }
            end
          end.compact
        end

        def cardinality_min_value(node)
          lower_value_node = node.xpath(".//lowerValue").first
          return unless lower_value_node

          lower_value = lower_value_node.attributes["value"]&.value
          LOVER_VALUE_MAPPINGS[lower_value]
        end

        def cardinality_max_value(node)
          upper_value_node = node.xpath(".//upperValue").first
          return unless upper_value_node

          upper_value_node.attributes["value"]&.value
        end

        def doc_node_attribute_value(node, attr_name)
          xmi_id = node["xmi:id"]
          doc_node = main_model.xpath(%(//element[@xmi:idref="#{xmi_id}"]/properties)).first
          return unless doc_node

          doc_node.attributes[attr_name]&.value
        end

        def lookup_attribute_definition(node)
          xmi_id = node["xmi:id"]
          doc_node = main_model.xpath(%(//attribute[@xmi:idref="#{xmi_id}"]/documentation)).first
          return unless doc_node

          doc_node.attributes["value"]&.value
        end

        def lookup_entity_name(xmi_id)
          xmi_cache[xmi_id] ||= model_node_name_by_xmi_id(xmi_id)
          xmi_cache[xmi_id]
        end

        def connector_source_name(xmi_id)
          node = main_model.xpath(%(//source[@xmi:idref="#{xmi_id}"]/model)).first
          return unless node

          node.attributes["name"]&.value
        end

        def connector_target_name(xmi_id)
          node = main_model.xpath(%(//target[@xmi:idref="#{xmi_id}"]/model)).first
          return unless node

          node.attributes["name"]&.value
        end

        def model_node_name_by_xmi_id(xmi_id)
          node = main_model.xpath(%(//*[@xmi:id="#{xmi_id}"])).first
          return unless node

          node.attributes["name"]&.value
        end
      end
    end
  end
end
