# TASK-005: shellcheck + 最終検証

## 説明

ccresmon.sh に対して shellcheck を実行し、すべての警告を修正する。手動テストで全パスの動作を確認し、パフォーマンス要件を検証する。

- 対象ファイルパス:
  - `/home/hasato/src/github.com/LevNas/ccresmon/ccresmon.sh`
  - `/home/hasato/src/github.com/LevNas/ccresmon/tests/ccresmon.bats`
- 技術: shellcheck, time コマンド
- 参照すべき設計:
  - `docs/sdd/design/index.md`（パフォーマンス考慮事項、外部プロセス起動数テーブル）
  - `docs/sdd/requirements/nfr/performance.md`

## 技術的文脈

- shellcheck: SC2086等の一般的な警告を修正
- パフォーマンス検証: `time` コマンドで100ms以内を確認
- 外部プロセス数: スクリプト内の外部コマンド呼び出し箇所をカウントし5個以下を確認

## 情報の明確性

| 分類 | 内容 |
|------|------|
| 明示された情報 | 品質ゲート基準（shellcheckエラー0件、100ms以内、外部プロセス5個以下） |
| 不明/要確認の情報 | なし |

## 実装手順

1. `shellcheck ccresmon.sh` を実行し、警告をすべて修正
2. パフォーマンス検証:
   ```bash
   time echo '{"tool_name":"Agent"}' | ./ccresmon.sh
   time echo '{"tool_name":"Bash"}' | ./ccresmon.sh
   time echo '{"tool_name":"Read"}' | ./ccresmon.sh
   ```
3. 外部プロセス数のカウント（`grep`, `awk`, `cut`, `nproc`, `date`, `lsblk` 等を確認）
4. エッジケースの手動テスト:
   - 空stdin
   - 不正JSON
   - procfs不在（docker等の制限環境を想定）
5. `bats tests/ccresmon.bats` で全テスト通過を再確認
6. 問題があれば修正

## 受入基準

- [ ] `shellcheck ccresmon.sh` でエラーが0件
- [ ] Agent パスの実行時間が100ms以内
- [ ] Bash パスの実行時間が100ms以内（キャッシュ使用時）
- [ ] 外部プロセス起動数がAgent時5個以下、Bash時3個以下
- [ ] 空stdin で正常終了する
- [ ] 不正JSON で正常終了する
- [ ] `bats tests/ccresmon.bats` で全テスト通過

## 依存関係

TASK-002, TASK-003（実装・テストが完了していること）

## 推定工数

20分（AIエージェント作業時間）

## ステータス

`TODO`
