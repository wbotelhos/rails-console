# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RailsConsole::ConsolesController' do
  after do
    RailsConsole.authorize = ->(_user) { false }
  end

  context 'when authorize allows access' do
    before { RailsConsole.authorize = ->(_user) { true } }

    it 'returns the console page' do
      get('/console')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-rails-console')
    end
  end

  context 'when authorize denies access' do
    before { RailsConsole.authorize = ->(_user) { false } }

    it 'returns forbidden' do
      get('/console')

      expect(response).to have_http_status(:forbidden)
    end
  end
end
