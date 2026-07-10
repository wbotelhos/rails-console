# frozen_string_literal: true

module RailsConsole
  class Engine < ::Rails::Engine
    isolate_namespace RailsConsole

    # Pagers hang inside the web console PTY, so disable them on whichever REPL the host app uses.
    console do
      IRB.conf[:USE_PAGER] = false if defined?(IRB)

      begin
        require 'pry'

        Pry.config.pager = false
      rescue LoadError
        nil
      end
    end

    initializer 'rails_console.assets' do |app|
      next if !app.config.respond_to?(:assets)

      app.config.assets.precompile += %w[rails_console.css rails_console.js]
    end
  end
end
