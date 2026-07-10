# frozen_string_literal: true

class CreateRailsConsoleLogLines < ActiveRecord::Migration[<%= migration_version %>]
  def change
    create_table :rails_console_log_lines do |t|
      t.integer :direction, null: false, default: 0
      t.text :content, null: false

      t.references :session, foreign_key: { to_table: :rails_console_sessions }, null: false

      t.timestamps
    end
  end
end
