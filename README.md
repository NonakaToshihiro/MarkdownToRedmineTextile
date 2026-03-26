# MarkdownToRedmineTextile

生成 AI が出力する Markdown を Redmine の textile 形式に変換する VSCode のタスクです。

Windows 環境を前提に書いていますが、macOS でも同じように設定することで動作するはずです。

## 方針

- このタスクはユーザー設定ではなく、ワークスペース設定として使ってください。
- `C:/Users/...` のようなマシン依存パスは使わず、ワークスペース基準でフィルターを解決します。
- VS Code の Settings Sync で同期されるユーザー `tasks.json` には、このタスクを置かないでください。

## 設定手順

1. Node.js をインストールします。

1. Pandoc をインストールします。

    ```cmd
    winget install pandoc
    ```

1. pandoc-filter をインストールします。

    ```cmd
    npm install -g pandoc-filter
    ```

1. VSCode でプロジェクトのフォルダーを開きます。

1. ワークスペース内の [.vscode/tasks.json](.vscode/tasks.json) を使います。
    - すでに [.vscode/tasks.json](.vscode/tasks.json) があるため、新規生成は不要です。
    - タスクは `${workspaceFolder}/convert-to-redmine.ps1` を経由して実行されます。
    - Lua フィルターは `${workspaceFolder}/forRedmineTextile.lua` を使って解決されるため、自宅と会社でリポジトリの配置先が違っても同じ設定のまま使えます。

1. ユーザー設定の `tasks.json` に同名タスクが残っている場合は削除します。
    - このタスクをユーザー設定に置くと、Settings Sync により別マシンの絶対パス設定と競合します。

## 実行手順

1. 変換したい Markdown ファイルを VSCode で開きます。

1. `Ctrl + Shift + B` でビルドタスクを実行します。

1. 元の Markdown ファイルと同じパスに拡張子 `.textile` のファイルが生成されます。

1. Markdown 以外のファイルを開いたまま実行すると、変換せずにエラー終了します。
    - たとえば `tasks.json` を開いたまま実行すると、JSON を Pandoc に渡してしまうため失敗します。
