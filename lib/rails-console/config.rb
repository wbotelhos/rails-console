# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'

module RailsConsole
  class << self
    attr_accessor :audit,
      :authorize,
      :command,
      :current_user,
      :idle_timeout,
      :sandbox_command,
      :user_class

    attr_writer :socket_path

    def config
      self
    end

    def configure
      yield(self)
    end

    def default_socket_path
      Rails.root.join('tmp/sockets/rails_console.sock')
    end

    def socket_path
      @socket_path || default_socket_path
    end
  end

  self.audit = true
  self.authorize = ->(_user) { false }
  self.command = 'bundle exec rails console'
  self.current_user = ->(user) { { id: user&.id, label: user.try(:email) || 'unknown' } }
  self.idle_timeout = 10.minutes
  self.sandbox_command = 'bundle exec rails console --sandbox'
  self.user_class = 'User'
end
