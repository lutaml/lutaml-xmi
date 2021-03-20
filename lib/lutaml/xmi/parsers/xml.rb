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
        attr_reader :main_model

        # @param [String] io - file object with path to .xmi file
        #        [Hash] options - options for parsing
        #
        # @return [Lutaml::XMI::Model::Document]
        def self.parse(io, options = {})
          new.parse(Nokogiri::XML(io.read))
        end

        def parse(xmi_doc)
          @main_model = xmi_doc
          ::Lutaml::Uml::Document
            .new(serialize_to_hash(xmi_doc))
        end

        private

        def serialize_to_hash(xmi_doc)
          main_model = xmi_doc.xpath('//uml:Model[@xmi:type="uml:Model"]').first
          {
            name: main_model["name"],
            classes: serialize_model_classes(main_model),
            enums: serialize_model_enums(main_model)
            # associations: serialize_model_associations(main_model)
          }
        end

        def serialize_model_classes(model)
          model.xpath('.//packagedElement[@xmi:type="uml:Class"]').map do |klass|
            {
              xmi_id: klass['xmi:id'],
              xmi_uuid: klass['xmi:uuid'],
              name: klass['name'],
              attributes: serialize_class_attributes(klass),
              associations: serialize_model_associations(klass)
            }
          end
        end

        def serialize_model_enums(model)
          model.xpath('.//packagedElement[@xmi:type="uml:Enumeration"]').map do |enum|
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
              attributes: attributes
            }
          end
        end

        def serialize_model_associations(klass)
          return unless klass.attributes['name']

          klass.xpath('.//ownedAttribute/type').map do |assoc|
            if assoc.attributes && assoc.attributes['idref']
              id_ref = assoc.attributes['idref'].value
              linked_class = main_model.xpath(%Q(//packagedElement[@xmi:type="uml:Class" and @xmi:id="#{id_ref}"])).first
              member_end = linked_class.attributes['name'].value if linked_class
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
              type: type['xmi:idref'],
              cardinality: [ATTRIBUTE_MAPPINGS[lowerValue["xmi:type"]], ATTRIBUTE_MAPPINGS[upperValue["xmi:type"]]].compact
            }
          end
        end
      end
    end
  end
end