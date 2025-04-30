Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # 開発環境では全てのオリジンを許可
    # 本番環境では特定のドメインのみを許可するように変更することを推奨
    origins '*'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end 