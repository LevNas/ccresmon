# TASK-001: ccresmon.sh コア関数の実装

## 説明

ccresmon.sh のコア関数（threshold-config, resource-collector, message-formatter）を実装する。これらは hook-dispatcher から呼ばれる独立した関数群であり、単一ファイル内に定義する。

- 対象ファイルパス: `/home/hasato/src/github.com/LevNas/ccresmon/ccresmon.sh`
- 技術: bash シェルスクリプト
- 参照すべき設計:
  - `docs/sdd/design/components/threshold-config.md`
  - `docs/sdd/design/components/resource-collector.md`
  - `docs/sdd/design/components/message-formatter.md`
  - `docs/sdd/design/decisions/DEC-002.md`（ディスクI/Oキャッシュ方式）
  - `docs/sdd/design/decisions/DEC-003.md`（フェイルオープン設計）

## 技術的文脈

- bashスクリプト。外部依存なし（標準Linuxコマンドのみ）
- procfs直接読み取り: `/proc/meminfo`, `/proc/loadavg`, `/proc/diskstats`
- 外部プロセス起動数を最小化（Agent時5個以下、Bash時3個以下）
- エラー時はフェイルオープン（0を返す or デフォルト値を使用）

## 情報の明確性

| 分類 | 内容 |
|------|------|
| 明示された情報 | 全コンポーネントの関数シグネチャ・実装方法・エラー処理（設計書に記載済み） |
| 不明/要確認の情報 | なし |

## 実装手順

1. `ccresmon.sh` を作成し、shebang (`#!/usr/bin/env bash`) と `set -euo pipefail` を記述
2. `trap 'exit 0' ERR` でフェイルオープンのグローバルエラーハンドラを設定
3. 定数定義（デフォルト閾値、環境変数名）を記述
4. `get_threshold()` 関数を実装（環境変数読み取り + バリデーション）
5. `get_memory_usage()` 関数を実装（/proc/meminfo から取得）
6. `get_cpu_load()` 関数を実装（/proc/loadavg + nproc から算出）
7. `get_diskio_usage()` 関数を実装（/proc/diskstats + /tmp キャッシュ方式）
8. `output_block()` 関数を実装（ブロックJSON出力）
9. `output_warn()` 関数を実装（警告JSON出力）
10. shellcheck で警告を確認し修正

## 受入基準

- [ ] `ccresmon.sh` が存在し、実行権限がある（`chmod +x`）
- [ ] `get_threshold()` が環境変数から閾値を正しく読み取る
- [ ] `get_threshold()` が不正値時にデフォルト値を返す
- [ ] `get_memory_usage()` が /proc/meminfo からメモリ使用率を整数で返す
- [ ] `get_cpu_load()` が /proc/loadavg とnprocからCPU負荷を整数で返す
- [ ] `get_diskio_usage()` が /proc/diskstats からI/O使用率を整数で返す（キャッシュ方式）
- [ ] `output_block()` が有効なJSON（decision: block）を出力する
- [ ] `output_warn()` が有効なJSON（decision: allow）を出力する
- [ ] メッセージに `[ccresmon]` プレフィックス、現在値、閾値が含まれる
- [ ] `shellcheck ccresmon.sh` でエラーが0件

## 依存関係

なし

## 推定工数

30分（AIエージェント作業時間）

## ステータス

`TODO`
