# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t api .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name api api

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.2.2
FROM ruby:3.2.2-slim

# 必要なパッケージのインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    default-libmysqlclient-dev \
    default-mysql-client \
    git \
    curl \
    libpq-dev \
    libvips \
    nodejs \
    npm \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g yarn

# 作業ディレクトリの設定
WORKDIR /app

# bundlerのバージョンを2.5.8に固定
RUN gem update --system && \
    gem install bundler:2.5.8

# Gemfileのコピーと依存関係のインストール
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local frozen false && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ /usr/local/bundle/ruby/*/cache /usr/local/bundle/ruby/*/bundler/gems/*/.git

# アプリケーションファイルのコピー
COPY . .

# キャッシュを事前コンパイル（起動時間短縮）
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# 環境変数の設定
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

# ヘルスチェック用のコマンド
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# ポート公開
EXPOSE 3000

# エントリーポイントとして起動スクリプトを使用
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# アプリケーション起動
CMD ["rails", "server", "-b", "0.0.0.0"]
