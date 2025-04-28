FROM node:18-alpine AS build

# ビルド環境の設定
WORKDIR /app

# 依存関係のインストール（キャッシュ効率化のため、package.jsonを先にコピー）
COPY package*.json ./
RUN npm install

# アプリケーションコードのコピーとビルド
COPY . .
RUN npm run build

# 本番環境用のコンテナ設定
FROM nginx:alpine
# ビルドしたファイルをnginxのHTMLディレクトリにコピー
COPY --from=build /app/build /usr/share/nginx/html
# Nginx設定ファイルのコピー
COPY nginx.conf /etc/nginx/conf.d/default.conf

# ポート公開設定
EXPOSE 80

# コンテナ起動コマンド
CMD ["nginx", "-g", "daemon off;"] 