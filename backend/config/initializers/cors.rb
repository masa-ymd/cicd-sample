# Cross-Origin Resource Sharing (CORS) 設定
# クロスオリジンリクエストを許可するための設定
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # アクセスを許可するオリジン（環境変数から取得、設定がなければ全てのオリジンを許可）
    origins ENV['CORS_ORIGINS'] || '*'
    
    # 全てのリソースへのアクセスとメソッドを許可
    resource '*',
      # 全てのヘッダーを許可
      headers: :any,
      # 許可するHTTPメソッド
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end 