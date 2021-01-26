require "nokogiri"
require "lutaml/xmi/model"

module Lutaml
  module Express
    module Parsers
      # Class for parsing .xmi schema files into Lutaml::XMI::Model::Document
      class XMI
        ATTRIBUTE_MAPPINGS = {
          "uml:LiteralInteger" => "1",
          "uml:LiteralUnlimitedNatural" => "*"
        }
        # @param [String] io - file object with path to .xmi file
        #        [Hash] options - options for parsing
        #
        # @return [Lutaml::XMI::Model::Document]
        def self.parse(io, options = {})
          Lutaml::XMI::Model::Document.new(Nokogiri::XML(io.read))
        end

        private

        def serialize_to_hash(xmi_doc)
          {
            packages: serialize_packages(xmi_doc)
          }
        end

        def serialize_packages(xmi_doc)
          xmi_doc.xpath('//packagedElement[xmi:type="uml:Package"]').each do |package|
            {
              id: package['xmi:id'],
              name: package['name'],
              classes: serialize_package_classes(package)
            }
          end
        end

        def serialize_package_classes(package)
          package.xpath('//packagedElement[xmi:type="uml:Class"]').each do |klass|
            {
              id: klass['xmi:id'],
              name: klass['name'],
              attributes: serialize_class_attributes(klass)
            }
          end
        end

        def serialize_class_attributes(klass)
          klass.xpath('//ownedAttribute[xmi:type="uml:Property"]').each do |attribute|
            type = attribute.xpath('//type').first
            lowerValue = attribute.xpath('//lowerValue').first
            upperValue = attribute.xpath('//upperValue').first
            {
              id: klass['xmi:id'],
              name: klass['name'],
              type: type['xmi:idref'],
              lowerValue: ATTRIBUTE_MAPPINGS[lowerValue["xmi:type"]],
              upperValue: ATTRIBUTE_MAPPINGS[upperValue["xmi:type"]]
            }
          end
        end
      end
    end
  end
end