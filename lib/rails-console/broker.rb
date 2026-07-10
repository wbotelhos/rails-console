# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'socket'

module RailsConsole
  # Owns the single PTY console session per container. Puma workers reach it over a local
  # Unix socket, so any worker can serve the browser's WebSocket and hit the same session.
  class Broker
    include Logging

    # Ctrl-L: tells the console to redraw its prompt so a just-attached client sees it.
    REDRAW = "\f"

    # Sent to clients when the session is replaced (safe!/unsafe!), so the frontend resets the
    # screen and shows the booting spinner again. NUL-delimited so it never collides with real
    # terminal output.
    RELOAD_MARKER = "\x00CONSOLE_RELOAD\x00"

    # The console prints this to ask for sandbox (safe) mode. NUL bytes never appear in terminal
    # output, so it can't be triggered by accident.
    SAFE_MARKER = "\x00CONSOLE_SAFE_REQUEST\x00"

    # Seconds to wait for a freshly spawned broker to start listening.
    SPAWN_TIMEOUT = 15

    # The console prints this to ask for write (unsafe) mode. NUL bytes never appear in terminal
    # output, so it can't be triggered by accident.
    UNSAFE_MARKER = "\x00CONSOLE_UNSAFE_REQUEST\x00"

    attr_reader :console_session, :owner_label

    def self.boot(socket_path: nil) # rubocop:disable Naming/PredicateMethod
      socket_path ||= RailsConsole.socket_path

      return true if running?(socket_path:)

      broker_bin = Gem.bin_path('rails-console', 'rails_console')

      Process.spawn('bundle', 'exec', broker_bin, chdir: Rails.root.to_s)

      SPAWN_TIMEOUT.times do
        return true if running?(socket_path:)

        sleep(1)
      end

      false
    end

    def self.running?(socket_path: nil)
      socket_path ||= RailsConsole.socket_path

      UNIXSocket.new(socket_path.to_s).close

      true
    rescue Errno::ENOENT, Errno::ECONNREFUSED
      false
    end

    def initialize(safe_command: nil, socket_path: nil, unsafe_command: nil)
      @clients = []
      @console_session = nil
      @idle_timer = nil
      @mutex = Mutex.new
      @owner_label = nil
      @pty_session = nil
      @safe_command = safe_command
      @server = nil
      @shutting_down = false
      @socket_path = socket_path || RailsConsole.socket_path
      @unsafe_command = unsafe_command
    end

    def run
      return log("Already listening on #{@socket_path}, aborting.") if already_running?

      prepare_socket_path

      @server = UNIXServer.new(@socket_path)

      log("Listening on #{@socket_path}")

      loop { Thread.new(@server.accept) { |client| handle_client(client) } }
    rescue IOError
      nil
    ensure
      @server&.close
    end

    def shutdown
      @shutting_down = true

      @mutex.synchronize do
        @idle_timer&.kill
        @idle_timer = nil

        @clients.each do |item|
          item.close
        rescue IOError
          nil
        end

        @clients.clear

        @pty_session&.kill!
      end

      @server&.close
      @server = nil
    end

    private

    def already_running?
      self.class.running?(socket_path: @socket_path)
    end

    def attach_client(client)
      @mutex.synchronize do
        @idle_timer&.kill
        @idle_timer = nil

        @clients << client
      end
    end

    def broadcast(bytes)
      @mutex.synchronize do
        @clients.each { |item| item.write(bytes) }
      rescue IOError, Errno::EPIPE
        nil
      end
    end

    def claim(label)
      @mutex.synchronize do
        if !@pty_session&.alive?
          @owner_label = label

          :start
        elsif owner_label == label
          :attach
        else
          :reject
        end
      end
    end

    def detach_client(client)
      @mutex.synchronize do
        @clients.delete(client)

        schedule_idle_shutdown if @clients.empty?
      end

      client.close
    rescue IOError
      nil
    end

    def end_session
      @mutex.synchronize do
        next if @clients.any?

        log("Ending idle session for #{owner_label}")

        @pty_session&.kill!
        console_session&.update(ended_at: Time.current)

        @console_session = nil
        @owner_label = nil
      end
    end

    def handle_client(client)
      start_message = read_start_message(client)

      return if start_message.nil?

      action = claim(start_message.fetch('label'))

      return reject_client(client) if action == :reject

      if action == :start
        start_session(
          ip_address: start_message['ip_address'],
          user_id: start_message.fetch('user_id'),
          user_label: start_message.fetch('label')
        )
      end

      attach_client(client)

      # Only redraw when joining a console that's already up; on :start the boot output
      # itself fills the screen, and a Ctrl-L would just be echoed as "^L" mid-boot.
      wake_pty if action == :attach

      relay_client_input(client)
    ensure
      detach_client(client)
    end

    def idle_timeout
      RailsConsole.idle_timeout
    end

    def prepare_socket_path
      FileUtils.mkdir_p(File.dirname(@socket_path))
      FileUtils.rm_f(@socket_path)
    end

    def read_loop(pty_session)
      loop do
        break if !pty_session.equal?(@pty_session)
        break if !pty_session.alive?

        bytes = pty_session.read_nonblock

        next sleep(0.02) if bytes.nil?

        requested = requested_mode(bytes)

        relay_pty_output(bytes.gsub(SAFE_MARKER, '').gsub(UNSAFE_MARKER, ''))

        next if requested.nil?

        switch_mode(sandbox: requested == :safe)

        break
      end
    end

    def read_start_message(client)
      line = client.gets&.chomp

      return if line.nil?

      JSON.parse(line)
    rescue IOError, JSON::ParserError
      nil
    end

    def record_log_line(content:, direction:)
      return if !RailsConsole.audit
      return if console_session.nil?
      return if content.blank?

      RailsConsole::LogLine.create(content:, direction:, session: console_session)
    end

    def reject_client(client)
      client.write("Session in use by #{owner_label}, please try again later.\n")
      client.close
    end

    def relay_client_input(client)
      loop do
        bytes = client.readpartial(RailsConsole::PtySession::READ_SIZE)

        @pty_session&.write(bytes)

        record_log_line(content: bytes, direction: :input)
      end
    rescue IOError, Errno::ECONNRESET
      nil
    end

    def relay_pty_output(bytes)
      broadcast(bytes)
      record_log_line(content: bytes, direction: :output)
    end

    # Which mode the console asked to switch to, or nil when the output has no marker.
    def requested_mode(bytes)
      return :safe if bytes.include?(SAFE_MARKER)
      return :unsafe if bytes.include?(UNSAFE_MARKER)

      nil
    end

    def schedule_idle_shutdown
      return if @shutting_down
      return if @idle_timer&.alive?

      @idle_timer = Thread.new do
        sleep(idle_timeout)

        end_session unless @shutting_down
      end
    rescue ThreadError
      nil
    end

    def start_session(ip_address:, user_id:, user_label:)
      @console_session = RailsConsole::Session.create!(
        ip_address:,
        started_at: Time.current,
        user_id:,
        user_label:
      )
      @pty_session = RailsConsole::PtySession.new(command: @safe_command, sandbox: true)

      log("Session started for #{owner_label}, pid=#{@pty_session.pid}, sandbox=true")

      Thread.new { read_loop(@pty_session) }
    end

    def switch_mode(sandbox:)
      mode = sandbox ? 'SAFE' : 'UNSAFE'
      command = sandbox ? @safe_command : @unsafe_command

      log_warn("Switching to #{mode} mode for #{owner_label}")

      console_session.update(unsafe_at: Time.current) if !sandbox
      record_log_line(content: "Switched to #{mode} mode", direction: :transition)

      broadcast(RELOAD_MARKER)

      old_session = @pty_session
      @pty_session = RailsConsole::PtySession.new(command:, sandbox:)

      old_session.kill!

      log_warn("Session is now #{mode}, pid=#{@pty_session.pid}")

      Thread.new { read_loop(@pty_session) }
    end

    # Nudges the console to redraw so a just-attached client isn't left staring at a blank screen.
    def wake_pty
      @pty_session&.write(REDRAW)
    end
  end
end
