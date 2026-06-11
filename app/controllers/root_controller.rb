# frozen_string_literal: true

class RootController < ActionController::API
  def show
    render json: {
      name: 'Resume Builder API',
      status: 'online',
      docs: '/api-docs',
      health: '/api/v1/status'
    }
  end
end
