# frozen_string_literal: true

module RailsConsole
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    desc 'Installs RailsConsole migrations and initializer'

    def create_initializer
      template('rails_console.rb', 'config/initializers/rails_console.rb')
    end

    def create_migrations
      template(
        'db/migrate/create_rails_console_sessions.rb',
        "db/migrate/#{timestamp(0)}_create_rails_console_sessions.rb"
      )

      template(
        'db/migrate/create_rails_console_log_lines.rb',
        "db/migrate/#{timestamp(1)}_create_rails_console_log_lines.rb"
      )
    end

    def link_sprockets_assets
      manifest = 'app/assets/config/manifest.js'

      return if !File.exist?(manifest)

      contents = File.read(manifest)

      return if contents.include?('rails_console.css')

      append_to_file(manifest) do
        <<~JS

          //= link rails_console.css
          //= link rails_console.js
        JS
      end
    end

    private

    def migration_version
      ActiveRecord::Migration.current_version
    rescue StandardError
      '8.1'
    end

    def timestamp(offset)
      Time.current.utc.strftime('%Y%m%d%H%M%S').to_i + offset
    end
  end
end
