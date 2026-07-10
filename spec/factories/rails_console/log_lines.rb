# frozen_string_literal: true

FactoryBot.define do
  factory :rails_console_log_line, class: 'RailsConsole::LogLine' do
    session factory: %i[rails_console_session]
    content { 'hello' }
    direction { :output }
  end
end
