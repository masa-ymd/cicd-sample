require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # APIモードの設定
    config.api_only = true
    
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # タイムゾーン設定
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local

    # ホスト認証の設定
    allowed_hosts = ENV.fetch('ALLOWED_HOSTS', '').split(',')
    if allowed_hosts.present?
      allowed_hosts.each do |host|
        config.hosts << host if host.present?
      end
    end

    # 開発環境では全てのホストを許可
    config.hosts.clear if Rails.env.development?

    # CORSの設定
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end
  end
end 