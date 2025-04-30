module Api
  class HealthController < ApplicationController
    def index
      render json: { status: 'ok', message: 'API is running' }
    end
  end
end 