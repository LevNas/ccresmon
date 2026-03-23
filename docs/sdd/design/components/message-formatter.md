# message-formatter（メッセージフォーマッター）

## 概要

**目的**: ブロック・警告時のJSON出力メッセージを生成する。メッセージには原因、現在値、閾値を含め、ユーザーが状況を判断できるようにする。

**責務**:
- ブロックJSON（decision: block）の生成
- 警告JSON（decision: allow + reason）の生成
- メッセージテンプレートの管理

## インターフェース

### 公開関数

#### `output_block(resource_type, current_value, threshold): void`

**説明**: ブロック用のJSONをstdoutに出力する。

**パラメータ**:
| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| resource_type | string | Yes | "memory" or "cpu" |
| current_value | integer | Yes | 現在のリソース使用率（%） |
| threshold | integer | Yes | 閾値（%） |

**出力例**:
```json
{"decision":"block","reason":"[ccresmon] メモリ使用率が閾値を超過しています (現在: 92%, 閾値: 85%)。しばらく待機してから再試行してください。"}
```

---

#### `output_warn(resource_type, current_value, threshold): void`

**説明**: 警告用のJSONをstdoutに出力する。

**パラメータ**:
| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| resource_type | string | Yes | "diskio" |
| current_value | integer | Yes | 現在のリソース使用率（%） |
| threshold | integer | Yes | 閾値（%） |

**出力例**:
```json
{"decision":"allow","reason":"[ccresmon] ディスクI/O負荷が高い状態です (現在: 78%, 閾値: 70%)。処理速度が低下する可能性があります。"}
```

### 実装方法

```bash
output_block() {
  local resource_type="$1" current="$2" threshold="$3"
  local label
  case "$resource_type" in
    memory) label="メモリ使用率" ;;
    cpu)    label="CPU負荷" ;;
  esac
  printf '{"decision":"block","reason":"[ccresmon] %sが閾値を超過しています (現在: %d%%, 閾値: %d%%)。しばらく待機してから再試行してください。"}\n' \
    "$label" "$current" "$threshold"
}

output_warn() {
  local resource_type="$1" current="$2" threshold="$3"
  local label
  case "$resource_type" in
    diskio) label="ディスクI/O負荷が高い状態です" ;;
  esac
  printf '{"decision":"allow","reason":"[ccresmon] %s (現在: %d%%, 閾値: %d%%)。処理速度が低下する可能性があります。"}\n' \
    "$label" "$current" "$threshold"
}
```

**補足**: `echo` ではなく `printf` を使用する。`echo` は環境によって `-n` や `-e` の挙動が異なるため、移植性の高い `printf` を採用する。

## 依存関係

### 依存するコンポーネント
- なし

### 依存されるコンポーネント
- [hook-dispatcher](hook-dispatcher.md) @hook-dispatcher.md: メッセージ出力の呼び出し元

## テスト観点

- [ ] 正常系: メモリブロックメッセージに"メモリ使用率"、現在値、閾値が含まれる
- [ ] 正常系: CPUブロックメッセージに"CPU負荷"、現在値、閾値が含まれる
- [ ] 正常系: ディスクI/O警告メッセージに現在値、閾値が含まれる
- [ ] 正常系: ブロックメッセージに「待機してから再試行」が含まれる
- [ ] 正常系: 出力が有効なJSONである
- [ ] 正常系: ブロック時のdecisionが"block"である
- [ ] 正常系: 警告時のdecisionが"allow"である

## 関連要件

- [REQ-001-003](../../requirements/stories/US-001.md) @../../requirements/stories/US-001.md: メモリ超過時のブロックメッセージ
- [REQ-001-004](../../requirements/stories/US-001.md) @../../requirements/stories/US-001.md: CPU超過時のブロックメッセージ
- [REQ-001-006](../../requirements/stories/US-001.md) @../../requirements/stories/US-001.md: 待機提案メッセージ
- [REQ-002-002](../../requirements/stories/US-002.md) @../../requirements/stories/US-002.md: ディスクI/O警告メッセージ
- [REQ-002-004](../../requirements/stories/US-002.md) @../../requirements/stories/US-002.md: 現在値と閾値の明示
- [NFR-USA-002](../../requirements/nfr/usability.md) @../../requirements/nfr/usability.md: メッセージの明瞭性
