module Api
  class HealthController < ApplicationController
    # ヘルスチェック用のエンドポイント
    # @return [JSON] アプリケーションの状態情報
    def index
      # アプリケーションの状態を返すJSONレスポンス
      # APP_VERSION環境変数を使用してデプロイされたバージョンを表示（環境変数がない場合は'development'）
      render json: { message: 'API is healthy', status: 'ok', version: ENV['APP_VERSION'] || 'development' }
    end
  end
end 