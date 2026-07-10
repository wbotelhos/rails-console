# frozen_string_literal: true

TestApp::Application.routes.draw do
  mount RailsConsole::Engine, at: '/console'
end
