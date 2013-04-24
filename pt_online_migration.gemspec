# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pt_online_migration/version'

Gem::Specification.new do |spec|
  spec.name          = "pt_online_migration"
  spec.version       = PtOnlineMigration::VERSION
  spec.authors        = ['LeadKarma, LLC']
  spec.email          = ['support@leadkarma.com']
  spec.description   = %q{active record migration wrapper for pt-online-schema-change cli command}
  spec.summary       = %q{online schema migrations for mysql}
  spec.homepage      = "http://www.leadkarma.com/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'activerecord'
  spec.add_dependency 'mysql2'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake'
end
