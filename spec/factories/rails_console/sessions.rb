# frozen_string_literal: true

FactoryBot.define do
  factory :rails_console_session, class: 'RailsConsole::Session' do
    ip_address { '127.0.0.1' }
    started_at { Time.current }
    user_id { 1 }
    user_label { 'user@example.com' }
  end
end
