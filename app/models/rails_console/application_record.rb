# frozen_string_literal: true

module RailsConsole
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
