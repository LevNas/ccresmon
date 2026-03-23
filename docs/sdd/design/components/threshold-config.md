# threshold-config（閾値設定管理）

## 概要

**目的**: 環境変数からリソース監視の閾値を読み取り、バリデーション後に使用可能な値として提供する。

**責務**:
- 環境変数からの閾値読み取り
- 値のバリデーション（数値チェック、範囲チェック）
- 不正値時のデフォルト値フォールバック

## インターフェース

### 公開関数

#### `get_threshold(env_var_name, default_value): integer`

**説明**: 指定された環境変数から閾値を読み取り、整数（%）で返す。不正値の場合はデフォルト値を返す。

**パラメータ**:
| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| env_var_name | string | Yes | 環境変数名 |
| default_value | integer | Yes | デフォルト値（1〜100） |

**戻り値**: integer - 閾値（1〜100の範囲）

**実装方法**:
```bash
get_threshold() {
  local env_var_name="$1"
  local default_value="$2"
  local value

  value="${!env_var_name:-}"

  # 未設定の場合
  if [ -z "$value" ]; then
    echo "$default_value"
    return
  fi

  # 数値チェック（整数のみ許可）
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$default_value"
    return
  fi

  # 範囲チェック（1〜100）
  if [ "$value" -lt 1 ] || [ "$value" -gt 100 ]; then
    echo "$default_value"
    return
  fi

  echo "$value"
}
```

### 定数定義

```bash
# デフォルト閾値
readonly DEFAULT_MEM_THRESHOLD=85
readonly DEFAULT_CPU_THRESHOLD=80
readonly DEFAULT_DISKIO_THRESHOLD=70

# 環境変数名
readonly ENV_MEM_THRESHOLD="CCRESMON_MEM_THRESHOLD"
readonly ENV_CPU_THRESHOLD="CCRESMON_CPU_THRESHOLD"
readonly ENV_DISKIO_THRESHOLD="CCRESMON_DISKIO_THRESHOLD"
```

### 使用例

```bash
mem_threshold=$(get_threshold "$ENV_MEM_THRESHOLD" "$DEFAULT_MEM_THRESHOLD")
cpu_threshold=$(get_threshold "$ENV_CPU_THRESHOLD" "$DEFAULT_CPU_THRESHOLD")
diskio_threshold=$(get_threshold "$ENV_DISKIO_THRESHOLD" "$DEFAULT_DISKIO_THRESHOLD")
```

## 依存関係

### 依存するコンポーネント
- なし（環境変数のみ参照）

### 依存されるコンポーネント
- [hook-dispatcher](hook-dispatcher.md) @hook-dispatcher.md: 閾値の提供先

## エラー処理

| エラー種別 | 発生条件 | 対処方法 |
|-----------|---------|---------|
| 環境変数未設定 | 変数が存在しない | デフォルト値を使用 |
| 非数値 | "abc", "85.5" 等 | デフォルト値にフォールバック |
| 範囲外 | 0, 101, -1 等 | デフォルト値にフォールバック |

## テスト観点

- [ ] 正常系: 環境変数に有効な値（50）が設定されている場合、その値が返される
- [ ] 正常系: 環境変数が未設定の場合、デフォルト値が返される
- [ ] 異常系: 非数値（"abc"）の場合、デフォルト値が返される
- [ ] 異常系: 小数（"85.5"）の場合、デフォルト値が返される
- [ ] 異常系: 負数（"-1"）の場合、デフォルト値が返される
- [ ] 境界値: 値が1の場合、1が返される
- [ ] 境界値: 値が100の場合、100が返される
- [ ] 境界値: 値が0の場合、デフォルト値が返される
- [ ] 境界値: 値が101の場合、デフォルト値が返される

## 関連要件

- [REQ-003-001〜005](../../requirements/stories/US-003.md) @../../requirements/stories/US-003.md: 環境変数による閾値カスタマイズ
