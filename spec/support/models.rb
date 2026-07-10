# frozen_string_literal: true

Dir[RailsConsole::Engine.root.join('app/models/**/*.rb')].each { |file| require file }
