# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsConsole::ConsoleChannel do
  let!(:user) { Struct.new(:email, :id).new('devops@example.com', 1) }
  let!(:connection) { Struct.new(:current_user, :env, :identifiers).new(user, {}, []) }
  let!(:channel) { described_class.new(connection, 'test') }

  after do
    RailsConsole.authorize = ->(_user) { false }
  end

  context 'when authorize denies access' do
    before do
      RailsConsole.authorize = ->(_user) { false }

      allow(channel).to receive(:reject)
    end

    it 'rejects the subscription' do
      channel.subscribed

      expect(channel).to have_received(:reject)
    end
  end

  context 'when authorize allows access' do
    before { RailsConsole.authorize = ->(_user) { true } }

    context 'when the broker is unavailable' do
      before do
        allow(RailsConsole::Broker).to receive(:boot).and_return(false)
        allow(channel).to receive(:reject)
        allow(channel).to receive(:transmit)
      end

      it 'rejects the subscription' do
        channel.subscribed

        expect(channel).to have_received(:reject)
      end

      it 'transmits an error message' do
        channel.subscribed

        expect(channel).to have_received(:transmit).with({ error: 'Console is unavailable at the moment.' })
      end
    end

    context 'when the broker is available' do
      let!(:reader_thread) { instance_double(Thread, kill: nil) }
      let!(:socket) { instance_double(UNIXSocket, close: nil) }

      before do
        allow(RailsConsole::Broker).to receive(:boot).and_return(true)
        RailsConsole.current_user = ->(_user) { { id: 1, label: 'devops@example.com' } }
        allow(UNIXSocket).to receive(:new).and_return(socket)
        allow(socket).to receive(:puts)
        allow(Thread).to receive(:new).and_return(reader_thread)
      end

      it 'connects to the broker and starts relaying output' do
        channel.subscribed

        expect(UNIXSocket).to have_received(:new).with(RailsConsole.socket_path.to_s)
        expect(socket).to have_received(:puts)
        expect(Thread).to have_received(:new)
      end
    end
  end

  describe '#receive' do
    let!(:socket) { instance_double(UNIXSocket, write: nil) }

    before { channel.instance_variable_set(:@socket, socket) }

    it 'forwards decoded bytes to the broker socket' do
      channel.receive({ 'bytes' => Base64.strict_encode64("hi\n") })

      expect(socket).to have_received(:write).with("hi\n")
    end
  end
end
