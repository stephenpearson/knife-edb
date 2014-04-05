# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife-edb/version'

Gem::Specification.new do |spec|
  spec.name          = "knife-edb"
  spec.version       = Knife::Edb::VERSION
  spec.authors       = ["Stephen Pearson"]
  spec.email         = ["stephen@hp.com"]
  spec.description   = %q{An encrypted data bag key manager for Chef}
  spec.summary       = %q{Manages EDB keys using Chef's client RSA PKI}
  spec.homepage      = "http://www.hpcloud.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.1"
  spec.add_development_dependency "rake"
end
