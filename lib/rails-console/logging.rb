# frozen_string_literal: true

module RailsConsole
  module Logging
    PREFIX = '[RailsConsole]'

    def log(message)
      Rails.logger.info("#{PREFIX} #{message}")
    end

    def log_warn(message)
      Rails.logger.warn("#{PREFIX} #{message}")
    end
  end
end
