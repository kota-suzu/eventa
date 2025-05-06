# よくある問題と解決策

## Ruby デフォルトgemとの競合

### 問題: `error_highlight`などのデフォルトgemとの競合

Ruby 3.2で発生する一般的な問題は、Rubyにバンドルされている「デフォルトgem」とGemfileで指定しているバージョンの競合です。特に`error_highlight`ではこの問題が顕著に表れ、CIが以下のようなエラーで失敗します：

```
bundler: failed to load command: rspec
You have already activated error_highlight 0.5.1, but your Gemfile requires error_highlight 0.7.0.
Since error_highlight is a default gem, you can either remove your dependency on it or
try updating to a newer version of bundler that supports error_highlight as a default gem.
```

### 解決策

#### 1. Gemfileでの条件付き指定

以下のようにRubyバージョンに応じた条件付き指定をします：

```ruby
# Ruby 3.3以上の場合のみerror_highlightを明示的に指定
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3.0')
  gem "error_highlight", ">= 0.6.0", platforms: [:ruby]
end
```

#### 2. bundlerの設定を適切に調整

`.bundle/config`ファイルを作成し、一貫した設定を確保します：

```yaml
---
BUNDLE_PATH: "vendor/bundle"
BUNDLE_DEPLOYMENT: "false"
BUNDLE_WITHOUT: "production"
BUNDLE_JOBS: "4"
BUNDLE_RETRY: "3"
BUNDLE_CLEAN: "true"
```

#### 3. CIワークフローで明示的なbundler設定

GitHub Actionsなどのワークフローでは、以下のステップを追加します：

```yaml
- name: Configure bundler
  run: |
    gem update --system
    bundle config set --local without 'production'
    bundle install --jobs 4 --retry 3
  working-directory: ./api
```

## その他のよくある問題

> このドキュメントは随時更新されます。他によくある問題があれば追加してください。 