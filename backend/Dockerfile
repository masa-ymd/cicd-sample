FROM ruby:3.1.4-slim

# システム依存パッケージのインストール
RUN apt-get update && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    nodejs \
    npm \
    tzdata \
    git \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリの設定
WORKDIR /app

# Gemfileのみをコピーしてインストール
COPY Gemfile Gemfile.lock* ./
RUN gem install bundler && bundle install --jobs 4

# アプリケーションコードのコピー
COPY . .

# データディレクトリの作成と権限設定
RUN mkdir -p /app/db && chmod 777 /app/db

# スタートアップスクリプトの作成
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Ruby logger問題を回避する環境変数設定
ENV THOR_SILENCE_DEPRECATION=1
ENV RUBY_YJIT_ENABLE=1

# ホスト認証用の環境変数（ビルド引数からデフォルト値を設定）
ARG DEFAULT_ALLOWED_HOSTS=localhost,127.0.0.1
ENV ALLOWED_HOSTS=${DEFAULT_ALLOWED_HOSTS}

# コンテナのポート公開設定
EXPOSE 3000

# ENTRYPOINTをスタートアップスクリプトに設定
ENTRYPOINT ["/app/entrypoint.sh"]

# コンテナ起動時のコマンド（Railsサーバー起動）
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"] 