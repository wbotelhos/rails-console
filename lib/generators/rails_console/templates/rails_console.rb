# frozen_string_literal: true

RailsConsole.configure do |config|
  config.audit = true

  config.authorize = ->(user) { user&.devops? }

  config.command = 'bundle exec rails console'

  config.current_user = ->(user) { { id: user&.id, label: user.try(:email) || 'unknown' } }

  config.idle_timeout = 10.minutes
  config.sandbox_command = 'bundle exec rails console --sandbox'
end
