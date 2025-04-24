Rails.application.routes.draw do
  # APIのエンドポイント定義
  namespace :api do
    # ヘルスチェック用のエンドポイント（GET /api/health）
    get 'health', to: 'health#index'
  end
end 