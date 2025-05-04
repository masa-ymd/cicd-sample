#!/bin/sh
set -e

echo "Preparing database..."
if [ "$RAILS_ENV" = "production" ]; then
  # 本番環境では最小限のコマンドのみ実行
  bundle exec rails db:migrate
else
  # 開発/テスト環境ではフル準備
  bundle exec rails db:prepare
fi

echo "Starting Rails server..."
exec "$@" 