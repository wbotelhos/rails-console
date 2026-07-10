# frozen_string_literal: true

RSpec.describe RailsConsole::Broker do
  let!(:broker_threads) { [] }
  let!(:brokers) { [] }
  let!(:fake_ptys) { [] }
  let!(:socket_path) { Rails.root.join("tmp/sockets/rails_console_test_#{SecureRandom.hex(4)}.sock") }
  let!(:user_id) { 1 }
  let!(:user_label) { 'user@example.com' }

  before do
    RailsConsole::LogLine.delete_all
    RailsConsole::Session.delete_all

    allow(RailsConsole::PtySession).to receive(:new) do |**args|
      FakePtySession.new(**args).tap { |item| fake_ptys << item }
    end
  end

  after do
    brokers.each(&:shutdown)

    broker_threads.each do |thread|
      thread.join(1)

      thread.kill if thread.alive?
    end

    FileUtils.rm_f(socket_path)
  end

  def run_broker(**)
    broker = described_class.new(socket_path:, **)

    brokers << broker
    broker_threads << Thread.new { broker.run }

    sleep(0.2)

    broker
  end

  def start_message(label: user_label, uid: user_id)
    JSON.generate(ip_address: '127.0.0.1', label:, user_id: uid)
  end

  describe '#run' do
    it 'creates a Session and relays PTY output to the connected client' do
      run_broker

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.1)

      fake_ptys.first.emit('hello')

      output = read_until(client) { |buffer| buffer.include?('hello') }

      expect(output).to include('hello')

      session = RailsConsole::Session.last

      expect(session.user_id).to eq(user_id)
      expect(session.user_label).to eq(user_label)
    end

    it 'rejects a second client while a session is active' do
      run_broker

      first_client = UNIXSocket.new(socket_path.to_s)
      first_client.puts(start_message)

      sleep(0.2)

      second_client = UNIXSocket.new(socket_path.to_s)
      second_client.puts(start_message(label: 'other@example.com', uid: 2))

      response = read_until(second_client) { |buffer| buffer.include?('Session in use') }

      expect(response).to include("Session in use by #{user_label}")
    end

    it 'reattaches the same user to the live session without starting a new one' do
      run_broker

      first_client = UNIXSocket.new(socket_path.to_s)
      first_client.puts(start_message)

      sleep(0.2)

      second_client = UNIXSocket.new(socket_path.to_s)
      second_client.puts(start_message)

      sleep(0.2)

      expect(RailsConsole::Session.count).to eq(1)
    end

    it 'wakes the pty on reattach so a reconnecting client is not left with a blank screen' do
      run_broker

      first_client = UNIXSocket.new(socket_path.to_s)
      first_client.puts(start_message)

      sleep(0.2)

      second_client = UNIXSocket.new(socket_path.to_s)
      second_client.puts(start_message)

      sleep(0.2)

      expect(fake_ptys.first.writes).to include(described_class::REDRAW)
    end

    it 'switches to unsafe mode and stops the sandboxed process when the marker is received' do
      marker = described_class::UNSAFE_MARKER

      run_broker

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.1)

      sandboxed_pty = fake_ptys.first
      sandboxed_pty.emit("before#{marker}")

      output = read_until(client) { |buffer| buffer.include?('before') }

      expect(output).not_to include(marker)
      expect(output).to include('before')

      sleep(0.1)

      expect(sandboxed_pty.alive?).to eq(false)
      expect(fake_ptys.last).not_to eq(sandboxed_pty)

      fake_ptys.last.emit('after')

      output = read_until(client) { |buffer| buffer.include?('after') }

      expect(output).to include('after')

      expect(RailsConsole::Session.last.unsafe_at).not_to be(nil)
    end

    it 'switches back to safe mode when the safe marker is received' do
      run_broker

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.1)

      unsafe_pty = fake_ptys.first
      unsafe_pty.emit(described_class::UNSAFE_MARKER)

      read_until(client) { |buffer| buffer.include?(described_class::RELOAD_MARKER) }

      sleep(0.1)

      fake_ptys.last.emit(described_class::SAFE_MARKER)

      sleep(0.1)

      expect(fake_ptys.size).to eq(3)
      expect(fake_ptys.last).to be_sandbox
    end

    it 'records each mode transition as a log line' do
      run_broker

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.1)

      fake_ptys.first.emit(described_class::UNSAFE_MARKER)

      read_until(client) { |buffer| buffer.include?(described_class::RELOAD_MARKER) }

      sleep(0.1)

      transition = RailsConsole::LogLine.transition.last

      expect(transition.content).to eq('Switched to UNSAFE mode')
    end

    it 'sends the reload marker when switching to unsafe mode' do
      marker = described_class::UNSAFE_MARKER

      run_broker

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.1)

      fake_ptys.first.emit(marker)

      output = read_until(client) { |buffer| buffer.include?(described_class::RELOAD_MARKER) }

      expect(output).to include(described_class::RELOAD_MARKER)
    end

    it 'does not start a second broker when one is already listening' do
      run_broker

      second_broker = described_class.new(socket_path:)

      brokers << second_broker
      second_broker.run

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.2)

      expect(RailsConsole::Session.count).to eq(1)
    end

    it 'ends the session after the idle timeout once the last client leaves' do
      original_idle_timeout = RailsConsole.idle_timeout

      RailsConsole.idle_timeout = 0.2

      run_broker

      client = UNIXSocket.new(socket_path.to_s)
      client.puts(start_message)

      sleep(0.2)

      client.close

      sleep(0.6)

      expect(RailsConsole::Session.last.ended_at).not_to be(nil)
    ensure
      RailsConsole.idle_timeout = original_idle_timeout
    end
  end

  describe '.running?' do
    it 'is false when no broker is listening' do
      expect(described_class.running?(socket_path:)).to be(false)
    end

    it 'is true when a broker is listening' do
      run_broker

      expect(described_class.running?(socket_path:)).to be(true)
    end
  end

  describe '.boot' do
    it 'returns true immediately when a broker is already running' do
      run_broker

      allow(Process).to receive(:spawn)

      expect(described_class.boot(socket_path:)).to be(true)

      expect(Process).not_to have_received(:spawn)
    end
  end
end
