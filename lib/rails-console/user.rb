# frozen_string_literal: true

module RailsConsole
  def self.authorized?(context)
    config.authorize.call(user_from(context))
  end

  def self.user_from(context)
    return context.current_user if context.respond_to?(:current_user)

    context.env['warden']&.user
  end
end
