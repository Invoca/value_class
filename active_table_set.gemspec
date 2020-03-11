lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_table_set/version'

Gem::Specification.new do |spec|
  spec.name          = "active_table_set"
  spec.version       = ActiveTableSet::VERSION
  spec.authors       = ["Victor Borda"]
  spec.email         = ["victor@invoca.com"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "http://invoca.net"
  end

  spec.summary       = %q{ActiveTableSet provides multi-database support through table-set based pool management and access rights enforcement.}
  spec.description   = %q{ActiveTableSet provides multi-database support through table-set based pool management and access rights enforcement.}
  spec.homepage      = "https://github.com/invoca/active-table-set"
  spec.license       = ""

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'attr_comparable'
  spec.add_dependency 'exception_handling'
  spec.add_dependency 'process_settings'
  spec.add_dependency 'rails', '~> 4.2'
end
