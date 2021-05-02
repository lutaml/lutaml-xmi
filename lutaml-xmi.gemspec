# frozen_string_literal: true

require_relative "lib/lutaml/xmi/version"

Gem::Specification.new do |spec|
  spec.name          = "lutaml-xmi"
  spec.version       = Lutaml::XMI::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com'"]

  spec.summary       = "XML Metadata Interchange (XMI) Specification parser in Ruby, tools for accessing EXPRESS data models."
  spec.description   = "XML Metadata Interchange (XMI) Specification parser in Ruby, tools for accessing EXPRESS data models."
  spec.homepage      = "https://github.com/lutaml/lutaml-xmi"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/lutaml-xmi/releases"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {spec}/*`.split("\n")

  spec.bindir        = "exe"
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "hashie", "~> 4.1.0"
  spec.add_runtime_dependency "thor", "~> 1.0"
  spec.add_runtime_dependency "lutaml-uml"
  spec.add_runtime_dependency "nokogiri", "~> 1.10"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "pry", "~> 0.12.2"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 0.54.0"
end
