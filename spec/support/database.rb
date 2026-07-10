# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'yaml'

database_yaml = Rails.root.join('spec/support/database.yml')
config = YAML.safe_load(ERB.new(database_yaml.read).result, aliases: true)['test']
database_path = Rails.root.join(config.fetch('database'))

FileUtils.mkdir_p(database_path.dirname)
FileUtils.rm_f(database_path)

ActiveRecord::Base.establish_connection(config)
