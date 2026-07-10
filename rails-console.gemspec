# frozen_string_literal: true

require_relative 'lib/rails-console/version'

Gem::Specification.new do |spec|
  spec.author = 'Washington Botelho'
  spec.bindir = 'bin'
  spec.description = 'A safe, browser-based Rails console you mount on your app.'
  spec.email = 'wbotelhos@gmail.com'
  spec.executables = ['rails_console']
  spec.extra_rdoc_files = Dir['CHANGELOG.md', 'LICENSE', 'README.md']
  spec.files = Dir[
    '{app,bin,config,lib}/**/*',
    'CHANGELOG.md',
    'LICENSE',
    'README.md'
  ].select { |path| File.file?(path) }
  spec.homepage = 'https://github.com/wbotelhos/rails-console'
  spec.license = 'MIT'
  spec.metadata = { 'rubygems_mfa_required' => 'true' }
  spec.name = 'rails-console'
  spec.required_ruby_version = '>= 3.3'
  spec.summary = 'A safe, browser-based Rails console you mount on your app.'
  spec.version = RailsConsole::VERSION

  spec.add_dependency('actioncable')
  spec.add_dependency('actionpack')
  spec.add_dependency('activerecord')
  spec.add_dependency('railties')
end
