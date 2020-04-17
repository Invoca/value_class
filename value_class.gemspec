lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'value_class/version'

Gem::Specification.new do |spec|
  spec.name          = "value_class"
  spec.version       = ValueClass::VERSION
  spec.authors       = ["Bob Smith"]
  spec.email         = ["bob@invoca.com"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://gem.fury.io/invoca"
  end

  spec.summary       = %q{ValueClass a lightweight way to define configuration DSLs.}
  spec.description   = %q{ValueClass provides an interface to declare simple classes that can be progressively constructed but that are imutable afterwards.}
  spec.homepage      = "https://github.com/invoca/value_class"
  spec.license       = ""

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'attr_comparable'
end
