# frozen_string_literal: true

module RailsConsole
  class LogLine < ApplicationRecord
    self.table_name = 'rails_console_log_lines'

    enum :direction, { input: 0, output: 1, transition: 2 }

    belongs_to :session, class_name: 'RailsConsole::Session', inverse_of: :log_lines, optional: false

    validates :content, presence: true
  end
end
