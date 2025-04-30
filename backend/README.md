# Rails API Backend

Rails 7.1のAPIモードで実装されたバックエンドアプリケーションです。

## APIエンドポイント

- `GET /api/health` - ヘルスチェックエンドポイント

## 開発環境のセットアップ

### 前提条件

- Docker
- Docker Compose

### ローカル開発環境の起動

```bash
docker-compose build
docker-compose up
```

データベースの作成と初期設定：

```bash
docker-compose exec backend rails db:create
docker-compose exec backend rails db:migrate
```

## 本番環境

環境変数：

- `DATABASE_HOST` - データベースホスト
- `DATABASE_USERNAME` - データベースユーザー名
- `DATABASE_PASSWORD` - データベースパスワード
- `RAILS_ENV` - 実行環境（production）
- `RAILS_LOG_TO_STDOUT` - 標準出力へのログ出力設定 