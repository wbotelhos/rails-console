# frozen_string_literal: true

require 'common_helper'

RSpec.describe RailsConsole::LogLine do
  it { expect(build(:rails_console_log_line).valid?).to be(true) }

  it { is_expected.to belong_to(:session).class_name('RailsConsole::Session') }
  it { is_expected.to define_enum_for(:direction).with_values(input: 0, output: 1, transition: 2) }

  it { is_expected.to validate_presence_of(:content) }
end
