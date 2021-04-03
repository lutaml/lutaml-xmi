require "nokogiri"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"

module Lutaml
  module XMI
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class XML
        ATTRIBUTE_MAPPINGS = {
          "uml:LiteralInteger" => "1",
          "uml:LiteralUnlimitedNatural" => "*"
        }
        attr_reader :main_model, :xmi_cache

        # @param [String] io - file object with path to .xmi file
        #        [Hash] options - options for parsing
        #
        # @return [Lutaml::XMI::Model::Document]
        def self.parse(io, options = {})
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
          main_model = xmi_doc.xpath('//uml:Model[@xmi:type="uml:Model"]').first
          {
            name: main_model["name"],
            packages: serialize_model_packages(main_model)
          }
        end

        def serialize_model_packages(main_model)
          main_model.xpath('./packagedElement[@xmi:type="uml:Package"]').map do |package|
            {
              name: package["name"],
              packages: serialize_model_packages(package),
              classes: serialize_model_classes(package),
              enums: serialize_model_enums(package)
            }
          end
        end

        def serialize_model_classes(model)
          model.xpath('./packagedElement[@xmi:type="uml:Class"]').map do |klass|
            {
              xmi_id: klass['xmi:id'],
              xmi_uuid: klass['xmi:uuid'],
              name: klass['name'],
              is_abstract: klass['is_abstract'],
              attributes: serialize_class_attributes(klass),
              associations: serialize_model_associations(klass),
              definition: lookup_klass_definition(klass)
            }
          end
        end

        def serialize_model_enums(model)
          model.xpath('./packagedElement[@xmi:type="uml:Enumeration"]').map do |enum|
            attributes = enum
                          .xpath('.//ownedLiteral[@xmi:type="uml:EnumerationLiteral"]')
                          .map do |attribute|
                            {
                              # TODO: xmi_id
                              # xmi_id: enum['xmi:id'],
                              type: attribute['name'],
                            }
                          end
            {
              xmi_id: enum['xmi:id'],
              xmi_uuid: enum['xmi:uuid'],
              name: enum['name'],
              attributes: attributes,
              definition: lookup_klass_definition(enum)
            }
          end
        end

        def serialize_model_associations(klass)
          return unless klass.attributes['name']

          klass.xpath('.//ownedAttribute/type').map do |assoc|
            if assoc.attributes && assoc.attributes['idref']
              id_ref = assoc.attributes['idref'].value
              member_end = lookup_entity_name(id_ref)
            end
            if member_end
              {
                xmi_id: assoc['xmi:id'],
                xmi_uuid: assoc['xmi:uuid'],
                name: assoc['name'],
                member_end: member_end
              }
            end
          end.compact
        end

        def serialize_class_attributes(klass)
          klass.xpath('.//ownedAttribute[@xmi:type="uml:Property"]').map do |attribute|
            type = attribute.xpath('.//type').first || {}
            lowerValue = attribute.xpath('.//lowerValue').first || {}
            upperValue = attribute.xpath('.//upperValue').first || {}
            {
              # TODO: xmi_id
              # xmi_id: klass['xmi:id'],
              name: attribute['name'],
              type: lookup_entity_name(type['xmi:idref']) || type['xmi:idref'],
              cardinality: [ATTRIBUTE_MAPPINGS[lowerValue["xmi:type"]], ATTRIBUTE_MAPPINGS[upperValue["xmi:type"]]].compact,
              definition: lookup_attribute_definition(attribute)
            }
          end
        end

        def lookup_klass_definition(node)
          xmi_id = node['xmi:id']
          doc_node = main_model.xpath(%Q(//element[@xmi:idref="#{xmi_id}"]/properties)).first
          return unless doc_node

          doc_node.attributes['documentation']&.value
        end

        def lookup_attribute_definition(node)
          xmi_id = node['xmi:id']
          doc_node = main_model.xpath(%Q(//attribute[@xmi:idref="#{xmi_id}"]/documentation)).first
          return unless doc_node

          doc_node.attributes['value']&.value
        end

        def lookup_entity_name(xmi_id)
          xmi_cache[xmi_id] ||= model_node_name_by_xmi_id(xmi_id)
          xmi_cache[xmi_id]
        end

        def model_node_name_by_xmi_id(xmi_id)
          node = main_model.xpath(%Q(//*[@xmi:id="#{xmi_id}"])).first
          return unless node

          node.attributes['name']&.value
        end
      end
    end
  end
end