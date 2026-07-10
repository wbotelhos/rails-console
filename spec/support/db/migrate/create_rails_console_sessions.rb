# frozen_string_literal: true

class CreateRailsConsoleSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :rails_console_sessions do |t|
      t.integer :user_id
      t.string :user_label
      t.string :ip_address
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.datetime :unsafe_at

      t.timestamps
    end
  end
end
