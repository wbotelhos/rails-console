# frozen_string_literal: true

require 'common_helper'

RSpec.describe RailsConsole::Session do
  it { expect(build(:rails_console_session).valid?).to be(true) }

  it { is_expected.to have_many(:log_lines).class_name('RailsConsole::LogLine').dependent(:destroy) }

  it { is_expected.to validate_presence_of(:started_at) }

  describe '#user' do
    let!(:session) { create(:rails_console_session, user_id: 42) }

    context 'when user class is not set' do
      before { RailsConsole.user_class = nil }

      it { expect(session.user).to be(nil) }
    end

    context 'when user class is set' do
      before do
        stub_const(
          'RailsConsoleSpecUser',
          Class.new do
            def self.find_by(id:)
              Struct.new(:id).new(id)
            end
          end
        )

        RailsConsole.user_class = 'RailsConsoleSpecUser'
      end

      after { RailsConsole.user_class = 'User' }

      it 'returns the user for the session user id' do
        expect(session.user.id).to eq(42)
      end
    end
  end
end
