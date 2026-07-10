# frozen_string_literal: true

module RailsConsole
  class ConsolesController < ActionController::Base
    layout 'rails_console/application'

    before_action :authorize!

    def show; end

    private

    def authorize!
      return if RailsConsole.authorized?(request)

      head(403)
    end
  end
end
