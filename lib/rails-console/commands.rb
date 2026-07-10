# frozen_string_literal: true

def safe!
  $stdout.puts(RailsConsole::Broker::SAFE_MARKER)
  $stdout.flush
end

def unsafe!
  $stdout.puts(RailsConsole::Broker::UNSAFE_MARKER)
  $stdout.flush
end
