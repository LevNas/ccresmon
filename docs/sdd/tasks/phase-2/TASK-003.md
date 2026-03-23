# TASK-003: bats-core ユニットテストの作成

## 説明

ccresmon.sh の全関数をテストする bats-core テストファイルを作成する。ccresmon.sh を source して関数単位でテストする。

- 対象ファイルパス: `/home/hasato/src/github.com/LevNas/ccresmon/tests/ccresmon.bats`
- 技術: bats-core（Bash Automated Testing System）
- 参照すべき設計:
  - `docs/sdd/design/components/threshold-config.md`（テスト観点セクション）
  - `docs/sdd/design/components/resource-collector.md`（テスト観点セクション）
  - `docs/sdd/design/components/message-formatter.md`（テスト観点セクション）
  - `docs/sdd/design/components/hook-dispatcher.md`（テスト観点セクション）

## 技術的文脈

- bats-core を使用（`brew install bats-core` or `apt install bats`）
- ccresmon.sh を `source` してテスト（sourceガードにより main は実行されない）
- procfs をモック化するため、テスト用の一時ディレクトリを作成し環境変数で切り替え可能にする
- テストカバレッジ目標: 80%以上

## 情報の明確性

| 分類 | 内容 |
|------|------|
| 明示された情報 | 各コンポーネントのテスト観点が設計書に記載済み |
| 不明/要確認の情報 | なし |

## 実装手順（TDD）

1. `tests/` ディレクトリを作成
2. `tests/ccresmon.bats` を作成
3. setup/teardown でテスト環境を準備:
   - ccresmon.sh を source
   - テスト用の /proc モックディレクトリを作成
4. threshold-config テストを作成:
   - 環境変数未設定 → デフォルト値
   - 有効な値（50）→ その値
   - 非数値（"abc"）→ デフォルト値
   - 範囲外（0, 101）→ デフォルト値
   - 境界値（1, 100）→ その値
5. resource-collector テストを作成:
   - get_memory_usage: /proc/meminfo のモックで正常値を返す
   - get_cpu_load: /proc/loadavg + nproc のモックで正常値を返す
   - get_diskio_usage: /proc/diskstats のモックで正常値を返す
6. message-formatter テストを作成:
   - output_block: JSON出力の検証（decision, reason, 現在値, 閾値）
   - output_warn: JSON出力の検証（decision, reason, 現在値, 閾値）
7. hook-dispatcher 統合テストを作成:
   - Agent 入力 → メモリ・CPUチェック実行
   - Bash 入力 → ディスクI/Oチェック実行
   - 不明ツール → 何もせず終了
   - 空入力 → 正常終了（フェイルオープン）
8. `bats tests/ccresmon.bats` で全テスト通過を確認

## 受入基準

- [ ] `tests/ccresmon.bats` が存在する
- [ ] threshold-config テスト: 8件以上（正常系2, 異常系3, 境界値3）
- [ ] resource-collector テスト: 6件以上（正常系3, 異常系2, 境界値1）
- [ ] message-formatter テスト: 7件以上（正常系5, JSON検証2）
- [ ] hook-dispatcher テスト: 5件以上（正常系3, 異常系2）
- [ ] `bats tests/ccresmon.bats` で全テスト通過
- [ ] テスト合計: 26件以上

## 依存関係

TASK-002（ccresmon.sh の全機能が実装済みであること）

## 推定工数

40分（AIエージェント作業時間）

## ステータス

`TODO`
