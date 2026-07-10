# frozen_string_literal: true

require 'pty'

module RailsConsole
  class PtySession
    READ_SIZE = 8192

    attr_reader :pid

    delegate :write, to: :@input

    def initialize(command: nil, sandbox: true)
      command ||= sandbox ? RailsConsole.sandbox_command : RailsConsole.command

      @output, @input, @pid = PTY.spawn(self.class.spawn_env, command)
    end

    # Pagers hang inside the web terminal, so force a pass-through one.
    def self.spawn_env
      {
        'PAGER' => 'cat',
        'TERM' => 'xterm-256color',
      }
    end

    def alive?
      Process.waitpid(pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      false
    end

    def kill!
      Process.kill('TERM', pid)
      Process.waitpid(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    def read_nonblock(size = READ_SIZE)
      @output.read_nonblock(size)
    rescue IO::WaitReadable, EOFError
      nil
    end
  end
end
