FROM node:18-alpine

WORKDIR /app

# 依存関係をインストール
COPY package*.json ./
RUN npm install

# アプリケーションのソースをコピー
COPY . .

# ビルド時引数
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

# 開発用ポート
EXPOSE 3000

# デフォルトコマンド（開発は npm run dev、本番は npm start が使われることを想定）
CMD ["npm", "run", "dev"] 