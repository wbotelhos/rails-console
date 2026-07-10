# frozen_string_literal: true

require 'logger'
require 'pathname'

module Rails
  def self.logger
    @logger ||= Logger.new(IO::NULL)
  end

  def self.root
    @root ||= Pathname.new(File.expand_path('../..', __dir__))
  end
end
