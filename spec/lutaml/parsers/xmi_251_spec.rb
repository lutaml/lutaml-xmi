require "spec_helper"

RSpec.describe Lutaml::XMI::Parsers::XML do
  describe '.parse' do
    subject(:parse) { described_class.parse(file) }

    context 'when simple xmi schema' do
      let(:file) { File.new(fixtures_path('ea-xmi-2.5.1.xmi')) }
      let(:expected_class_names) do
        %w[
          BibliographicItem
          Block
          ClassificationType
          Permission
          Recommendation
          Requirement
          RequirementSubpart
          RequirementType
        ]
      end
      let(:expected_class_xmi_ids) do
        %w[
          EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA
          EAID_10AD8D60_9972_475a_AB7E_FA40212D5297
          EAID_30B0131C_804F_4f67_8B6F_35DF5ABD8E78
          EAID_82354CDC_EACB_402f_8C2B_FD627B7416E7
          EAID_AD7320C2_FEE6_4352_8D56_F2C8562B6153
          EAID_2AC20C81_1E83_400d_B098_BAB784395E06
          EAID_035D8176_5E9E_42c8_B447_64411AE96F57
          EAID_C1155D80_E68B_46d5_ADE5_F5639486163D
        ]
      end
      let(:expected_enum_names) { ["ObligationType"] }
      let(:expected_enum_xmi_ids) { ["EAID_E497ABDA_05EF_416a_A461_03535864970D"] }
      let(:expected_attributes_names) do
        %w[
          classification
          description
          filename
          id
          import
          inherit
          keep-lines-together
          keep-with-next
          label
          measurement-target
          model
          number
          obligation
          references
          specification
          subject
          subrequirement
          subsequence
          title
          type
          unnumbered
          verification
        ]
      end
      let(:expected_attributes_types) do
        %w[
          EAJava_ClassificationType_0..___
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_String_
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..___
          EAJava_boolean_0..1__
          EAJava_boolean_0..1__
          EAJava_String_0..1__
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_String_0..1__
          EAJava_ObligationType_1..___
          EAJava_BibliographicItem_0..1__
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_FormattedString_0..1__
          EAJava_String_0..1__
          EAJava_boolean_0..1__
          EAJava_RequirementSubpart_0..___
        ]
      end
      let(:expected_association_names) do
        %w[
          RequirementType
        ]
      end
      let(:first_package) { parse.packages.first }

      it "parses xml file into Lutaml::Uml::Node::Document object" do
        expect(parse).to(be_instance_of(::Lutaml::Uml::Document))
      end

      it "correctly parses package tree" do
        expect(parse.packages.map(&:name))
          .to(eq(['requirement type class diagram']))
        expect(first_package.packages.map(&:name))
          .to(eq(
            [
              "BibliographicItem",
              nil,
              "Block",
              nil,
              "ClassificationType",
              nil,
              "ObligationType",
              nil,
              "Permission",
              "Recommendation",
              "Requirement",
              "RequirementSubpart",
              nil,
              "RequirementType",
            ]
          ))
      end

      it "correctly parses package classes" do
        expect(first_package.classes.map(&:name)).to(eq(expected_class_names))
        expect(first_package.classes.map(&:xmi_id))
          .to(eq(expected_class_xmi_ids))
      end

      it "correctly parses entities of enums type" do
        expect(first_package.enums.map(&:name)).to(eq(expected_enum_names))
        expect(first_package.enums.map(&:xmi_id)).to(eq(expected_enum_xmi_ids))
      end

      it "correctly parses entities and attributes for class" do
        klass = first_package.classes.find do |entity|
          entity.name == 'RequirementType'
        end

        expect(klass.attributes.map(&:name)).to(eq(expected_attributes_names))
        expect(klass.attributes.map(&:type)).to(eq(expected_attributes_types))
      end

      it "correctly parses associations for class" do
        klass = first_package.classes.find do |entity|
          entity.name == 'Block'
        end

        expect(klass.associations.map(&:member_end).compact)
          .to(eq(expected_association_names))
      end

      it "correctly parses diagrams for package" do
        root_package = parse.packages.first
        expect(root_package.diagrams.length).to(eq(1))
        expect(root_package.diagrams.map(&:name))
          .to(eq(['Starter Class Diagram']))
        expect(root_package.diagrams.map(&:definition))
          .to(eq(['aada']))
      end
    end
  end
end
