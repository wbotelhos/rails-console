# frozen_string_literal: true

# A controllable stand-in for RailsConsole::PtySession, so broker specs can drive exact
# output/timing deterministically instead of depending on a real PTY.spawn process — which
# is what made these specs flaky/slow in CI (real process scheduling, real OS pipes).
class FakePtySession
  attr_reader :pid, :writes

  def initialize(command: nil, sandbox: true)
    @alive = true
    @command = command
    @output = Queue.new
    @pid = object_id
    @sandbox = sandbox
    @writes = []
  end

  def alive?
    @alive
  end

  def kill!
    @alive = false
  end

  # Test helper: makes the next read_nonblock call(s) return this output.
  def emit(bytes)
    @output << bytes
  end

  def read_nonblock(_size = nil)
    @output.pop(true)
  rescue ThreadError
    nil
  end

  def sandbox?
    @sandbox
  end

  def write(bytes)
    @writes << bytes
  end
end
