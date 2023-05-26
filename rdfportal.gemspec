# frozen_string_literal: true

require_relative 'lib/rdfportal/version'

Gem::Specification.new do |spec|
  spec.name = 'rdfportal'
  spec.version = RDFPortal::VERSION
  spec.authors = ['Daisuke Satoh']
  spec.email = ['dsatoh@kamonohashi.co.jp']

  spec.summary = 'CLI tools for RDF Portal.'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/rdfportal/rdfportal'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '~> 1.2'
end
