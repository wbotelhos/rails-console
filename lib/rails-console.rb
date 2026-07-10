# frozen_string_literal: true

module RailsConsole
end

require 'rails-console/version'
require 'rails-console/config'
require 'rails-console/user'
require 'rails-console/logging'
require 'rails-console/commands'
require 'rails-console/pty_session'
require 'rails-console/broker'

require 'rails-console/engine' if defined?(::Rails::Engine)
