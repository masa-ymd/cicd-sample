module Api
  class HealthController < ApplicationController
    def index
      render json: { status: 'ok', message: 'API is running! deployed by terraform!' }
    end
  end
end 