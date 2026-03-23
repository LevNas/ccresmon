#!/usr/bin/env bats

# ccresmon.sh テスト
# bats-core を使用: https://github.com/bats-core/bats-core

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  source "$SCRIPT_DIR/ccresmon.sh"

  # テスト用環境変数をクリア
  unset CCRESMON_MEM_THRESHOLD
  unset CCRESMON_CPU_THRESHOLD
  unset CCRESMON_DISKIO_THRESHOLD
}

# ==============================================================================
# threshold-config テスト (8件)
# ==============================================================================

@test "get_threshold: 環境変数未設定時にデフォルト値を返す" {
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 85 ]
}

@test "get_threshold: 有効な値が設定されている場合、その値を返す" {
  export CCRESMON_MEM_THRESHOLD=50
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 50 ]
}

@test "get_threshold: 非数値(abc)の場合、デフォルト値を返す" {
  export CCRESMON_MEM_THRESHOLD="abc"
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 85 ]
}

@test "get_threshold: 小数(85.5)の場合、デフォルト値を返す" {
  export CCRESMON_MEM_THRESHOLD="85.5"
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 85 ]
}

@test "get_threshold: 負数(-1)の場合、デフォルト値を返す" {
  export CCRESMON_MEM_THRESHOLD="-1"
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 85 ]
}

@test "get_threshold: 境界値1の場合、1を返す" {
  export CCRESMON_MEM_THRESHOLD=1
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 1 ]
}

@test "get_threshold: 境界値100の場合、100を返す" {
  export CCRESMON_MEM_THRESHOLD=100
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 100 ]
}

@test "get_threshold: 境界値0の場合、デフォルト値を返す" {
  export CCRESMON_MEM_THRESHOLD=0
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 85 ]
}

@test "get_threshold: 境界値101の場合、デフォルト値を返す" {
  export CCRESMON_MEM_THRESHOLD=101
  result=$(get_threshold "CCRESMON_MEM_THRESHOLD" 85)
  [ "$result" -eq 85 ]
}

# ==============================================================================
# resource-collector テスト (7件)
# ==============================================================================

@test "get_memory_usage: 0〜100の範囲で整数を返す" {
  result=$(get_memory_usage)
  [[ "$result" =~ ^[0-9]+$ ]]
  [ "$result" -ge 0 ]
  [ "$result" -le 100 ]
}

@test "get_memory_usage: 返り値が整数である" {
  result=$(get_memory_usage)
  [[ "$result" =~ ^[0-9]+$ ]]
}

@test "get_cpu_load: 0以上の整数を返す" {
  result=$(get_cpu_load)
  [[ "$result" =~ ^[0-9]+$ ]]
  [ "$result" -ge 0 ]
}

@test "get_cpu_load: 返り値が整数である" {
  result=$(get_cpu_load)
  [[ "$result" =~ ^[0-9]+$ ]]
}

@test "get_diskio_usage: 0〜100の範囲で整数を返す" {
  result=$(get_diskio_usage)
  [[ "$result" =~ ^[0-9]+$ ]]
  [ "$result" -ge 0 ]
  [ "$result" -le 100 ]
}

@test "get_diskio_usage: 初回キャッシュなし時は0を返す(フェイルオープン)" {
  # キャッシュファイルが存在しない状態をシミュレート
  local cache="/tmp/ccresmon_diskstats_$(id -u)"
  [ -f "$cache" ] && mv "$cache" "$cache.bak"
  result=$(get_diskio_usage)
  [ -f "$cache.bak" ] && mv "$cache.bak" "$cache"
  [ "$result" -eq 0 ]
}

@test "get_diskio_usage: 返り値が整数である" {
  result=$(get_diskio_usage)
  [[ "$result" =~ ^[0-9]+$ ]]
}

# ==============================================================================
# message-formatter テスト (7件)
# ==============================================================================

@test "output_block: メモリブロック時にdecision=blockを出力する" {
  result=$(output_block "memory" 92 85)
  echo "$result" | grep -q '"decision":"block"'
}

@test "output_block: メモリブロックメッセージに'メモリ使用率'が含まれる" {
  result=$(output_block "memory" 92 85)
  echo "$result" | grep -q 'メモリ使用率'
}

@test "output_block: メモリブロックメッセージに現在値と閾値が含まれる" {
  result=$(output_block "memory" 92 85)
  echo "$result" | grep -q '92%'
  echo "$result" | grep -q '85%'
}

@test "output_block: CPUブロックメッセージに'CPU負荷'が含まれる" {
  result=$(output_block "cpu" 95 80)
  echo "$result" | grep -q 'CPU負荷'
}

@test "output_block: ブロックメッセージに'待機してから再試行'が含まれる" {
  result=$(output_block "memory" 92 85)
  echo "$result" | grep -q '待機してから再試行'
}

@test "output_warn: ディスクI/O警告時にdecision=allowを出力する" {
  result=$(output_warn "diskio" 78 70)
  echo "$result" | grep -q '"decision":"allow"'
}

@test "output_warn: ディスクI/O警告メッセージに現在値と閾値が含まれる" {
  result=$(output_warn "diskio" 78 70)
  echo "$result" | grep -q '78%'
  echo "$result" | grep -q '70%'
}

@test "output_block: 出力が有効なJSON形式である" {
  result=$(output_block "memory" 92 85)
  # JSONの基本構造を検証
  echo "$result" | grep -q '^{"decision":"block","reason":".*"}$'
}

@test "output_warn: 出力が有効なJSON形式である" {
  result=$(output_warn "diskio" 78 70)
  echo "$result" | grep -q '^{"decision":"allow","reason":".*"}$'
}

# ==============================================================================
# hook-dispatcher テスト (6件)
# ==============================================================================

@test "main: Agent入力時に正常終了する" {
  run bash -c 'echo "{\"tool_name\":\"Agent\"}" | bash '"$SCRIPT_DIR"'/ccresmon.sh'
  [ "$status" -eq 0 ]
}

@test "main: Bash入力時に正常終了する" {
  run bash -c 'echo "{\"tool_name\":\"Bash\"}" | bash '"$SCRIPT_DIR"'/ccresmon.sh'
  [ "$status" -eq 0 ]
}

@test "main: その他のツール(Read)は何も出力せず正常終了する" {
  run bash -c 'echo "{\"tool_name\":\"Read\"}" | bash '"$SCRIPT_DIR"'/ccresmon.sh'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "main: 空入力で正常終了する(フェイルオープン)" {
  run bash -c 'echo "" | bash '"$SCRIPT_DIR"'/ccresmon.sh'
  [ "$status" -eq 0 ]
}

@test "main: 不正なJSON入力で正常終了する(フェイルオープン)" {
  run bash -c 'echo "invalid" | bash '"$SCRIPT_DIR"'/ccresmon.sh'
  [ "$status" -eq 0 ]
}

@test "main: Agent閾値超過時にblock JSONを出力する" {
  run bash -c 'export CCRESMON_MEM_THRESHOLD=1 && echo "{\"tool_name\":\"Agent\"}" | bash '"$SCRIPT_DIR"'/ccresmon.sh'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"decision":"block"'
}
