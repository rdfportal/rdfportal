# frozen_string_literal: true

require_relative 'lib/rdf/portal/version'

Gem::Specification.new do |spec|
  spec.name = 'rdf-portal'
  spec.version = Rdf::Portal::VERSION
  spec.authors = ['Daisuke Satoh']
  spec.email = ['dsatoh@kamonohashi.co.jp']

  spec.summary = 'CLI tools to update RDF Portal.'
  spec.description = 'CLI tools to update RDF Portal.'
  spec.homepage = 'https://github.com/dbcls/rdf-portal'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/dbcls/rdf-portal'
  spec.metadata['changelog_uri'] = 'https://github.com/dbcls/rdf-portal'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
end
