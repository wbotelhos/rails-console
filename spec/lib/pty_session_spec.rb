# frozen_string_literal: true

RSpec.describe RailsConsole::PtySession do
  describe '.spawn_env' do
    it 'disables the pager and sets a terminal type' do
      expect(described_class.spawn_env).to eq(
        'PAGER' => 'cat',
        'TERM' => 'xterm-256color'
      )
    end
  end

  describe '#alive?' do
    it 'is true while the process is running and false after it exits' do
      pty_session = described_class.new(command: 'sleep 0.2')

      expect(pty_session.alive?).to be(true)

      Process.waitpid(pty_session.pid)

      expect(pty_session.alive?).to be(false)
    end
  end

  describe '#kill!' do
    it 'terminates the process' do
      pty_session = described_class.new(command: 'sleep 5')

      pty_session.kill!

      expect(pty_session.alive?).to be(false)
    end
  end

  describe '#read_nonblock' do
    it 'returns the bytes written by the process' do
      pty_session = described_class.new(command: 'echo hello')

      sleep(0.1)

      expect(pty_session.read_nonblock).to include('hello')
    end
  end

  describe '#write' do
    it 'sends bytes to the process stdin' do
      pty_session = described_class.new(command: 'cat')

      pty_session.write("hi\n")

      sleep(0.1)

      expect(pty_session.read_nonblock).to include('hi')

      pty_session.kill!
    end
  end
end
