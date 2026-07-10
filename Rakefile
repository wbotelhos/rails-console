# frozen_string_literal: true

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

namespace :assets do
  desc 'Build frontend assets with esbuild'
  task :build do
    abort('npm install failed') if !system('npm', 'install', '--silent')
    abort('npm run build failed') if !system('npm', 'run', 'build')
  end
end

desc 'Build the gem package (frontend assets + .gem file)'
task build: 'assets:build' do
  sh('gem', 'build', 'rails-console.gemspec')
end

task default: :spec
