# frozen_string_literal: true

require 'common_helper'

RSpec.describe RailsConsole do
  describe '.authorized?' do
    after { described_class.authorize = ->(_user) { false } }

    context 'when user is not present' do
      let!(:context) { Struct.new(:env).new({}) }

      it { expect(described_class.authorized?(context)).to be(false) }
    end

    context 'when user is present and authorize allows access' do
      before { described_class.authorize = ->(_user) { true } }

      let!(:context) { Struct.new(:current_user).new(Struct.new(:id).new(1)) }

      it { expect(described_class.authorized?(context)).to be(true) }
    end
  end

  describe '.user_from' do
    let!(:user) { Struct.new(:email, :id).new('devops@example.com', 1) }

    context 'when context has warden user in env' do
      let!(:context) { Struct.new(:env).new({ 'warden' => Struct.new(:user).new(user) }) }

      it { expect(described_class.user_from(context)).to eq(user) }
    end

    context 'when context responds to current_user' do
      let!(:context) { Struct.new(:current_user).new(user) }

      it { expect(described_class.user_from(context)).to eq(user) }
    end

    context 'when user is not available' do
      let!(:context) { Struct.new(:env).new({}) }

      it { expect(described_class.user_from(context)).to be(nil) }
    end
  end
end
