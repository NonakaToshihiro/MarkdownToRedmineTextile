# MarkdownToRedmineTextile

生成 AI が出力する Markdown を Redmine の textile 形式に変換する VSCode のタスクです。

Windows 環境を前提に書いていますが、macOS でも同じように設定することで動作するはずです。

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

1. 「**ターミナル**」 > 「**タスクの構成...**」 を選択し、「**テンプレートから tasks.json を生成**」 > 「**Others**」 を選択します。

1. 生成された `.vscode/tasks.json` の内容を本リポジトリ内の `task.json` の内容で置き換えます。
    - あわせて、`args` の最後のパラメーターを `forRedmineTextile.lua` が存在するパスに書き換えます。

## 実行手順

1. 変換したい Markdown ファイルを VSCode で開きます。

1. `Ctrl + Shift + B` でビルドタスクを実行します。

1. 元の Markdown ファイルと同じパスに拡張子 `.textile` のファイルが生成されます。
