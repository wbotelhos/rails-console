# frozen_string_literal: true

require 'base64'
require 'socket'

module RailsConsole
  class ConsoleChannel < ActionCable::Channel::Base
    # Keystrokes from the browser: decode and forward them to the broker.
    def receive(data)
      bytes = Base64.strict_decode64(data.fetch('bytes'))

      @socket&.write(bytes)
    rescue ArgumentError, Errno::EPIPE, IOError
      nil
    end

    # Connects an authorized user to the broker and starts streaming its output back.
    def subscribed
      return reject if !RailsConsole.authorized?(connection)

      return reject_unavailable if !RailsConsole::Broker.boot

      @socket = connect_to_broker
      @reader_thread = Thread.new { relay_broker_output }
    rescue Errno::ECONNREFUSED, Errno::ENOENT
      reject_unavailable
    end

    # Closes the broker connection when the browser leaves.
    def unsubscribed
      @reader_thread&.kill
      @socket&.close
    rescue IOError
      nil
    end

    private

    # Opens the broker socket and sends who is connecting.
    def connect_to_broker
      socket = UNIXSocket.new(RailsConsole.socket_path.to_s)
      identity = RailsConsole.config.current_user.call(RailsConsole.user_from(connection))
      ip_address = Rack::Request.new(connection.env).ip
      label = identity[:label] || identity['label']
      user_id = identity[:id] || identity['id']

      socket.puts(JSON.generate(ip_address:, label:, user_id:))

      socket
    end

    # Tells the browser the console could not be reached and drops the subscription.
    def reject_unavailable
      transmit({ error: 'Console is unavailable at the moment.' })

      reject
    end

    # Streams broker output to the browser, encoded so binary bytes survive JSON.
    def relay_broker_output
      loop do
        bytes = @socket.readpartial(RailsConsole::PtySession::READ_SIZE)

        transmit({ bytes: Base64.strict_encode64(bytes) })
      end
    rescue IOError
      nil
    end
  end
end
