# frozen_string_literal: true

require 'action_cable/engine'
require 'action_controller/railtie'
require 'action_view/railtie'

unless defined?(TestApp::Application)
  module TestApp
    class Application < Rails::Application
      config.action_cable.cable = { adapter: 'async' }
      config.action_cable.disable_request_forgery_protection = true
      config.consider_all_requests_local = true
      config.eager_load = false
      config.hosts = nil
      config.load_defaults 8.1
      config.paths['config/database'] = [Rails.root.join('spec/support/database.yml')]
      config.paths['config/routes.rb'] = [Rails.root.join('spec/support/routes.rb')]
      config.root = Rails.root
      config.secret_key_base = 'test' * 8
    end
  end

  TestApp::Application.initialize!

  Rails.application = TestApp::Application
  Rails.logger = ActiveSupport::Logger.new($stdout)

  ActionCable.server.config.cable = { adapter: 'async' }
  ActionCable.server.config.disable_request_forgery_protection = true
end
