# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require 'support/coverage'

require 'active_record/railtie'
require 'pry-byebug'
require 'support/rails_root'
require 'rails-console'

require 'support/common'
require 'support/database'
require 'support/database_cleaner'
require 'support/factory_bot'
require 'support/migrate'
require 'support/models'
require 'support/shoulda'
require 'support/rails_app'
