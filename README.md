# ccresmon

Claude Code のリソース監視フック。Agent 起動時にメモリ・CPU をチェックしてブロック、Bash 実行時にディスク I/O をチェックして警告を表示します。

## インストール

### 1. リポジトリをクローン

```bash
git clone https://github.com/LevNas/ccresmon.git
chmod +x ccresmon/ccresmon.sh
```

### 2. Claude Code の settings.json にフック設定を追加

`~/.claude/settings.json`（グローバル）またはプロジェクトの `.claude/settings.json` に以下を追加:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent|Bash",
        "hook": "/path/to/ccresmon/ccresmon.sh"
      }
    ]
  }
}
```

> `/path/to/ccresmon/ccresmon.sh` を実際のパスに置き換えてください。

### 3. (オプション) 環境変数で閾値をカスタマイズ

シェルの設定ファイル（`~/.bashrc`, `~/.zshrc` 等）に追加:

```bash
export CCRESMON_MEM_THRESHOLD=90    # メモリ使用率の閾値（デフォルト: 85%）
export CCRESMON_CPU_THRESHOLD=85    # CPU負荷の閾値（デフォルト: 80%）
export CCRESMON_DISKIO_THRESHOLD=75 # ディスクI/O使用率の閾値（デフォルト: 70%）
```

## 設定リファレンス

### 環境変数

| 変数名 | 説明 | デフォルト値 | 範囲 |
|--------|------|-------------|------|
| `CCRESMON_MEM_THRESHOLD` | メモリ使用率の閾値 (%) | 85 | 1-100 |
| `CCRESMON_CPU_THRESHOLD` | CPU負荷の閾値 (%) | 80 | 1-100 |
| `CCRESMON_DISKIO_THRESHOLD` | ディスクI/O使用率の閾値 (%) | 70 | 1-100 |

不正な値（非数値、範囲外）を設定した場合は自動的にデフォルト値が使用されます。

## 動作

### Agent 起動時（ブロック）

メモリ使用率とCPU負荷を順にチェックし、いずれかが閾値を超過した場合に Agent の起動をブロックします。

```
[ccresmon] メモリ使用率が閾値を超過しています (現在: 92%, 閾値: 85%)。しばらく待機してから再試行してください。
```

### Bash 実行時（警告）

ディスクI/O使用率をチェックし、閾値を超過した場合に警告を表示します。Bash の実行自体はブロックしません。

```
[ccresmon] ディスクI/O負荷が高い状態です (現在: 78%, 閾値: 70%)。処理速度が低下する可能性があります。
```

### その他のツール

Agent, Bash 以外のツール（Read, Write, Glob 等）では何もせず、実行を許可します。

## エラー時の動作

ccresmon はフェイルオープン設計を採用しています。スクリプト自体のエラー（procfs 読み取り失敗、不正な入力等）が発生した場合、ツール実行を許可します。監視スクリプトの不具合で Claude Code の動作を妨げることはありません。

## アンインストール

`settings.json` から ccresmon のフック設定を削除するだけで無効化できます。

```json
{
  "hooks": {
    "PreToolUse": []
  }
}
```

## 対象環境

- Linux
- WSL2 (Windows Subsystem for Linux 2)

procfs (`/proc/meminfo`, `/proc/loadavg`, `/proc/diskstats`) が利用可能な環境で動作します。外部パッケージのインストールは不要です。

## テスト

[bats-core](https://github.com/bats-core/bats-core) を使用:

```bash
bats tests/ccresmon.bats
```

## ライセンス

MIT
