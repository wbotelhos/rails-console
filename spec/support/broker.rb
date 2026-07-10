# frozen_string_literal: true

# Helpers for exercising RailsConsole::Broker against a real Unix socket + PTY.
module BrokerHelpers
  # Polls the socket instead of sleeping a fixed amount, since PTY spawn + broker
  # processing time is not stable across machines/CI runners.
  def read_until(client, timeout: 15)
    deadline = Time.current + timeout
    buffer = +''

    loop do
      begin
        buffer << client.read_nonblock(8192)

        return buffer if yield(buffer)
      rescue IO::WaitReadable
        nil
      end

      raise "timed out waiting for expected output, got: #{buffer.inspect}" if Time.current > deadline

      sleep(0.02)
    end
  end
end

RSpec.configure do |config|
  config.include(BrokerHelpers)
end
