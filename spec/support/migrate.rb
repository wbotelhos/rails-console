# frozen_string_literal: true

Dir[File.expand_path('db/migrate/*.rb', __dir__)].each { |file| require file }

CreateRailsConsoleSessions.new.change
CreateRailsConsoleLogLines.new.change
