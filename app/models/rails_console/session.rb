# frozen_string_literal: true

module RailsConsole
  class Session < ApplicationRecord
    self.table_name = 'rails_console_sessions'

    has_many :log_lines, class_name: 'RailsConsole::LogLine', dependent: :destroy, inverse_of: :session

    validates :started_at, presence: true

    def user
      return if RailsConsole.user_class.blank?

      model = RailsConsole.user_class.safe_constantize

      return if model.nil?

      model.find_by(id: user_id)
    end
  end
end
