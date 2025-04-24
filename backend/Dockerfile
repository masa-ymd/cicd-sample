FROM ruby:3.2.2-alpine

# システム依存パッケージのインストール
# - build-base: コンパイルツール群
# - postgresql-dev: PostgreSQLクライアント開発ライブラリ
# - nodejs, npm: JavaScript実行環境
# - tzdata: タイムゾーンデータ
# - git: バージョン管理ツール
RUN apk add --no-cache build-base postgresql-dev nodejs npm tzdata git

# 作業ディレクトリの設定
WORKDIR /app

# Gemのインストール
# - Gemfileとlockをコピー
# - Bundlerをインストールし依存関係を解決
COPY Gemfile Gemfile.lock* ./
RUN gem install bundler && bundle install --jobs 4

# アプリケーションコードのコピー
COPY . .

# コンテナのポート公開設定
EXPOSE 3000

# コンテナ起動時のコマンド（Railsサーバー起動）
# -b オプションで全てのインターフェースからのアクセスを許可
CMD ["rails", "server", "-b", "0.0.0.0"] 