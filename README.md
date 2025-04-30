# CICDサンプルプロジェクト

このプロジェクトは、GitHub ActionsとTerraformを使用したフロントエンドReactアプリケーションとバックエンドRails APIサービスのためのCICD環境を示しています。

## プロジェクト構造

```
cicd-sample/
├── frontend/           # Reactアプリケーション
├── backend/            # Rails API
├── infrastructure/     # Terraform設定
└── .github/            # GitHub Actionsワークフロー
```

## 前提条件

- 適切な権限を持つAWSアカウント
- GitHubリポジトリ
- Terraform CLI
- Docker
- Node.jsとnpm
- RubyとRails

## アーキテクチャの特徴

- **フロントエンド**: S3にホスティングされたReactアプリケーションをCloudFrontで配信
- **バックエンド**: ECS Fargateで実行されるRails APIをALBとCloudFrontで配信
  - バックエンドAPIはALBで公開され、CloudFront経由でもアクセス可能（キャッシュ設定あり）
- **環境変数による設定**:
  - ホスト認証設定はALLOWED_HOSTS環境変数で柔軟に制御可能

## 初期セットアップ

1. **AWS設定**
   - 適切な権限を持つAWS IAMユーザーを作成
   - AWS CLIを認証情報で設定
   - バックエンドイメージ用のECRリポジトリを作成
   - Terraformの状態用のS3バケットを作成

2. **GitHubリポジトリ設定**
   - フロントエンドとバックエンド用のGitHubリポジトリを作成
   - ブランチ保護ルールを設定:
     - `develop`ブランチはfeatureブランチからのPRのみを受け付けるよう保護
     - `production`ブランチはdevelopブランチからのPRのみを受け付けるよう保護
     - マージ前にプルリクエストのレビューを要求
     - ワークフローの承認を要求

3. **GitHub Secrets**
   - 以下のシークレットをGitHubリポジトリに追加:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AWS_REGION`
     - `ECR_REPOSITORY`
     - `ALLOWED_HOSTS` (各環境ごとに許可するホスト名をカンマ区切りで指定)
     - `TF_API_TOKEN` (Terraform Cloudを使用する場合)

4. **初期デプロイ**
   - Terraformを実行して初期インフラストラクチャを作成
   - フロントエンドとバックエンドアプリケーションの初期バージョンをデプロイ

## ワークフロー

1. 機能ブランチ（`feature/xxx`）で機能を開発
2. `develop`ブランチへのプルリクエストを作成
3. 承認とマージ後、GitHub Actionsは以下を実行:
   - アプリケーションのビルドとテスト
   - バックエンド用のDockerイメージのビルド
   - `<git-hash>-dev`タグでECRにプッシュ
   - ECSタスク定義の更新
   - 開発環境へのデプロイ
4. 本番リリースの場合:
   - `develop`から`production`へのプルリクエストを作成
   - プロンプトが表示されたらセマンティックバージョンを提供
   - 承認とマージ後、GitHub Actionsはバージョンタグを付けて本番環境にデプロイ

## 詳細セットアップ手順

### 1. AWS環境設定

#### 1.1 IAMユーザー作成
1. AWSマネジメントコンソールにログイン
2. IAMサービスに移動
3. 「ユーザー」→「ユーザーを作成」をクリック
4. ユーザー名を入力（例：`cicd-automation`）
5. アクセスキーの作成（プログラムによるアクセス）を選択
6. 次のポリシー（またはこれらを含むカスタムポリシー）をアタッチ：
   - ECRへのアクセス権限：
     - 管理コンソールで表示されるECR関連ポリシーから選択（例：`ECRTemplateServiceRolePolicy`）
     - またはより広範な権限として`AmazonEC2ContainerRegistryFullAccess`
   - `AmazonECS_FullAccess`
   - `AmazonS3FullAccess`
   - `CloudFrontFullAccess`
   - `AmazonVPCFullAccess`
   - `IAMFullAccess`
   - `CloudWatchLogsFullAccess`

   または、より簡単な方法として：
   - `AdministratorAccess`（CI/CDパイプライン用のサービスアカウントとして使用する場合）
7. 作成後、アクセスキーIDとシークレットアクセスキーをダウンロード（この情報は一度しか表示されないので注意）

#### 1.2 AWS CLI設定
```bash
# AWS CLIのインストール（まだの場合）
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 認証情報の設定
aws configure
# プロンプトでアクセスキーID、シークレットアクセスキー、リージョン（us-east-1など）を入力
```

#### 1.3 ECRリポジトリの作成
```bash
# 開発環境用
aws ecr create-repository \
    --repository-name cicd-sample-backend-dev \
    --image-scanning-configuration scanOnPush=true \
    --region ap-northeast-1

# 本番環境用
aws ecr create-repository \
    --repository-name cicd-sample-backend-prod \
    --image-scanning-configuration scanOnPush=true \
    --region ap-northeast-1
```

#### 1.4 Terraform状態管理用S3バケット作成
```bash
aws s3api create-bucket \
    --bucket cicd-sample-terraform-state \
    --region us-east-1

# バージョニングを有効化
aws s3api put-bucket-versioning \
    --bucket cicd-sample-terraform-state \
    --versioning-configuration Status=Enabled
```

> **注意**: Terraform状態管理用のS3バケットはus-east-1リージョンにありますが、実際にデプロイされるリソース（ECR、ECS、CloudFrontなど）は`ap-northeast-1`（東京リージョン）にデプロイされます。Terraformコードは既にこの設定になっています。

### 2. GitHubリポジトリ設定

#### 2.1 リポジトリ作成
1. GitHubにログイン
2. 「New repository」をクリック
3. リポジトリ名を入力（例：`cicd-sample`）
4. 「Create repository」をクリック

#### 2.2 ローカルリポジトリの設定
```bash
# リポジトリをクローン
git clone https://github.com/yourusername/cicd-sample.git
cd cicd-sample

# 作成したコードファイルをコピーまたはダウンロード

# 初期コミット
git add .
git commit -m "Initial commit"
git push origin main

# ブランチ構造の作成
git checkout -b develop
git push origin develop

git checkout -b feature/initial-setup
git push origin feature/initial-setup

# productionブランチの作成
git checkout develop
git checkout -b production
git push origin production
```

#### 2.3 ブランチ保護ルールの設定
1. GitHubリポジトリページで「Settings」→「Branches」に移動
2. 「Branch protection rules」→「Add rule」をクリック
3. developブランチの保護設定:
   - Branch name pattern: `develop`
   - チェックする項目:
     - ✓ Require pull request reviews before merging
     - ✓ Require approvals (1名以上)
     - ✓ Restrict who can push to matching branches
     - ✓ Do not allow bypassing the above settings
   - 「Create」をクリック
4. productionブランチの保護設定も同様に設定

#### 2.4 ワークフロー承認要件の設定
1. GitHubリポジトリページで「Settings」→「Environments」に移動
2. 「New environment」をクリック
3. 「development」と入力して「Configure environment」をクリック
4. 「Required reviewers」をチェックし、レビュアーを追加
5. 同様に「production」環境も作成

### 3. GitHub Secrets設定

1. GitHubリポジトリページで「Settings」→「Secrets and variables」→「Actions」に移動
2. 「New repository secret」をクリックし、以下のシークレットを追加:

```
AWS_ACCESS_KEY_ID: [IAMユーザーのアクセスキーID]
AWS_SECRET_ACCESS_KEY: [IAMユーザーのシークレットアクセスキー]
AWS_REGION: ap-northeast-1
ECR_REPOSITORY_DEV: cicd-sample-backend-dev
ECR_REPOSITORY_PROD: cicd-sample-backend-prod
```

3. 各環境（development, production）用のシークレットを追加:

```
# Environments > development の設定で追加
API_URL: http://[開発環境ALBのDNS名] （デプロイ後に設定）
FRONTEND_URL: https://[開発環境CloudFrontのドメイン名] （デプロイ後に設定）
ALLOWED_HOSTS: localhost,127.0.0.1,cicd-sample-alb-dev-*.ap-northeast-1.elb.amazonaws.com,*.cloudfront.net
```

```
# Environments > production の設定で追加
API_URL: http://[本番環境ALBのDNS名] （デプロイ後に設定）
FRONTEND_URL: https://[本番環境CloudFrontのドメイン名] （デプロイ後に設定）
ALLOWED_HOSTS: api.example.com,cicd-sample-alb-prod-*.ap-northeast-1.elb.amazonaws.com,*.cloudfront.net
```

> **注意**: GitHub Actionsのワークフローファイルも修正して、開発環境と本番環境で適切なECRリポジトリ名を参照するようにする必要があります。

### 4. インフラの初期デプロイ

#### 4.1 Terraformのインストールと初期化
```bash
# Terraformのインストール（まだの場合）
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# 開発環境のインフラ構築
cd infrastructure/environments/dev
terraform init
terraform plan
terraform apply -auto-approve
```

#### 4.2 環境変数の設定
Terraformの実行結果から出力される値を使用して、GitHub Secretsを更新:
1. `frontend_url`の値を`FRONTEND_URL`シークレットに設定
2. `backend_url`の値を`API_URL`シークレットに設定
3. `api_cloudfront_endpoint`の値を確認し、必要に応じてALLOWED_HOSTSに追加

#### 4.3 初期アプリケーションのビルドとデプロイ

##### フロントエンド初期デプロイ
```bash
cd frontend
npm install
npm run build
aws s3 sync build/ s3://cicd-sample-frontend-dev/ --delete
```

> 注意：フロントエンドアプリケーション用のS3バケットには、Terraformによってバージョニングが有効化されています。これにより、デプロイしたReactアプリケーションの各バージョンが保存され、障害時に以前のバージョンに簡単に戻すことができます。バージョンの確認や復元はAWSコンソールのS3バケット管理画面から行えます。

##### バックエンド初期デプロイ
```bash
# 環境変数を設定（GitHub Secretsの変数と同じ値を使用）
export ECR_REPOSITORY_DEV=cicd-sample-backend-dev
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-northeast-1

# ローカルでDockerイメージをビルド
cd backend
docker build --build-arg DEFAULT_ALLOWED_HOSTS=localhost,127.0.0.1,cicd-sample-alb-dev-*.ap-northeast-1.elb.amazonaws.com,*.cloudfront.net -t $ECR_REPOSITORY_DEV:initial .

# ECRにプッシュ
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker tag $ECR_REPOSITORY_DEV:initial $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_DEV:initial
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_DEV:initial

# タスク定義の更新（実際のECSサービス名に合わせて調整）
aws ecs describe-task-definition --task-definition cicd-sample-task-dev --query "taskDefinition" --output json > task-definition.json

# タスク定義にALLOWED_HOSTS環境変数を追加
jq '.containerDefinitions[0].environment += [{"name": "ALLOWED_HOSTS", "value": "localhost,127.0.0.1,cicd-sample-alb-dev-*.ap-northeast-1.elb.amazonaws.com,*.cloudfront.net"}]' task-definition.json > new-task-definition.json

# 新しいタスク定義を登録
aws ecs register-task-definition --cli-input-json file://new-task-definition.json

# サービスを更新
aws ecs update-service --cluster cicd-sample-cluster-dev --service cicd-sample-service-dev --force-new-deployment --region $AWS_REGION
```

### 5. CI/CDパイプラインのテスト

1. feature/xxxブランチからdevelopブランチへのPRを作成
2. PRがマージされたら、GitHub Actionsがトリガーされることを確認
3. フロントエンドとバックエンドのビルド、テスト、デプロイが自動的に実行されることを確認
4. アプリケーションが正常に動作することを確認（フロントエンドからバックエンドAPIを呼び出せるか）

### 6. 主要な更新内容

1. **バックエンドAPIのCloudFront配信**: ALBのエンドポイントをCloudFront経由でアクセスできるようになり、キャッシュや地理的分散配信が可能になりました。

2. **フロントエンドのCSP設定削除**: 以前は必要だったContent Security Policy（CSP）設定が不要になり、より柔軟なコンテンツ配信が可能になりました。

3. **環境変数によるホスト認証設定**: Railsのホスト認証設定が環境変数`ALLOWED_HOSTS`で管理できるようになり、環境ごとの設定が容易になりました。
   - Docker構築時: `--build-arg DEFAULT_ALLOWED_HOSTS=ホスト名1,ホスト名2,...`
   - コンテナ実行時: `-e ALLOWED_HOSTS=ホスト名1,ホスト名2,...`
   - 開発環境では自動的に全てのホストが許可されます（`Rails.env.development?`の場合）

### 7. ローカル環境での実行

#### フロントエンド
```bash
cd frontend
npm install
npm start
```

#### バックエンド
```bash
# Dockerを使用してローカルで実行
cd backend
docker build -t cicd-sample-backend:local .
docker run -p 3000:3000 -e RAILS_ENV=development -e ALLOWED_HOSTS=localhost,127.0.0.1 cicd-sample-backend:local
```

または、Docker Composeを使用する場合:
```bash
# docker-compose.ymlファイルがある場所で
docker-compose up
``` 