# TASK-002: ccresmon.sh メインロジック（hook-dispatcher）の実装

## 説明

ccresmon.sh のメインロジック（hook-dispatcher）を実装する。stdinからJSONを読み取り、tool_nameに応じてTASK-001で実装したコア関数を呼び出し、結果をstdoutにJSON出力する。

- 対象ファイルパス: `/home/hasato/src/github.com/LevNas/ccresmon/ccresmon.sh`（TASK-001で作成済みのファイルに追記）
- 技術: bash シェルスクリプト
- 参照すべき設計:
  - `docs/sdd/design/components/hook-dispatcher.md`

## 技術的文脈

- stdinからのJSON読み取りは `grep` + `tr` で軽量に実装（jq不使用）
- tool_name が "Agent" の場合: メモリ + CPU チェック → 閾値超過時ブロック
- tool_name が "Bash" の場合: ディスクI/O チェック → 閾値超過時警告（ブロックしない）
- tool_name がその他の場合: 何もせず終了
- スクリプト末尾に `main` 関数呼び出しを配置（sourceでテスト可能にするためガード付き）

## 情報の明確性

| 分類 | 内容 |
|------|------|
| 明示された情報 | JSON入力フォーマット、tool_name判定ロジック、出力フォーマット（設計書に記載済み） |
| 不明/要確認の情報 | なし |

## 実装手順

1. `main()` 関数を実装:
   - stdinからJSON入力を `read -r` で読み取り
   - `tool_name` を `grep -o` + `tr -d` で抽出
   - case文でAgent/Bash/その他に分岐
2. `check_agent_resources()` 関数を実装:
   - `get_threshold` でメモリ・CPU閾値を取得
   - `get_memory_usage` でメモリ使用率を取得
   - メモリ閾値超過時に `output_block "memory"` を呼んで exit
   - `get_cpu_load` でCPU負荷を取得
   - CPU閾値超過時に `output_block "cpu"` を呼んで exit
3. `check_bash_resources()` 関数を実装:
   - `get_threshold` でディスクI/O閾値を取得
   - `get_diskio_usage` でI/O使用率を取得
   - 閾値超過時に `output_warn "diskio"` を呼ぶ（exitしない）
4. sourceガードを追加:
   ```bash
   # source時はmainを実行しない（テスト用）
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
     main
   fi
   ```
5. 手動テスト: `echo '{"tool_name":"Agent"}' | ./ccresmon.sh`

## 受入基準

- [ ] `echo '{"tool_name":"Agent"}' | ./ccresmon.sh` でメモリ・CPUチェックが実行される
- [ ] `echo '{"tool_name":"Bash"}' | ./ccresmon.sh` でディスクI/Oチェックが実行される
- [ ] `echo '{"tool_name":"Read"}' | ./ccresmon.sh` で何も出力されず正常終了する
- [ ] `echo '' | ./ccresmon.sh` で正常終了する（フェイルオープン）
- [ ] `echo 'invalid' | ./ccresmon.sh` で正常終了する（フェイルオープン）
- [ ] Agentブロック時のJSON出力が `{"decision":"block","reason":"..."}` 形式である
- [ ] Bash警告時のJSON出力が `{"decision":"allow","reason":"..."}` 形式である
- [ ] source時にmainが実行されない（テスト用ガード）
- [ ] `shellcheck ccresmon.sh` でエラーが0件

## 依存関係

TASK-001（コア関数が実装済みであること）

## 推定工数

20分（AIエージェント作業時間）

## ステータス

`TODO`
