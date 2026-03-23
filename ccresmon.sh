#!/usr/bin/env bash
set -euo pipefail

# フェイルオープン: エラー時は許可扱いで終了 (DEC-003)
trap 'exit 0' ERR

# ==============================================================================
# 定数定義
# ==============================================================================

# デフォルト閾値
readonly DEFAULT_MEM_THRESHOLD=85
readonly DEFAULT_CPU_THRESHOLD=80
readonly DEFAULT_DISKIO_THRESHOLD=70

# 環境変数名
readonly ENV_MEM_THRESHOLD="CCRESMON_MEM_THRESHOLD"
readonly ENV_CPU_THRESHOLD="CCRESMON_CPU_THRESHOLD"
readonly ENV_DISKIO_THRESHOLD="CCRESMON_DISKIO_THRESHOLD"

# ディスクI/Oキャッシュファイル (DEC-002)
DISKIO_CACHE_FILE="/tmp/ccresmon_diskstats_$(id -u)"
readonly DISKIO_CACHE_FILE
readonly DISKIO_CACHE_MAX_AGE=60  # 秒

# ==============================================================================
# threshold-config: 閾値設定管理
# ==============================================================================

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

# ==============================================================================
# resource-collector: リソース情報収集
# ==============================================================================

get_memory_usage() {
  local mem_total mem_available
  mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}') 2>/dev/null || { echo 0; return; }
  mem_available=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}') 2>/dev/null || { echo 0; return; }

  if [ -z "$mem_total" ] || [ "$mem_total" -eq 0 ]; then
    echo 0
    return
  fi

  echo $(( (mem_total - mem_available) * 100 / mem_total ))
}

get_cpu_load() {
  local load_avg nproc_count
  load_avg=$(cut -d' ' -f1 /proc/loadavg) 2>/dev/null || { echo 0; return; }
  nproc_count=$(nproc 2>/dev/null) || nproc_count=1

  awk "BEGIN { printf \"%d\", ($load_avg / $nproc_count) * 100 }"
}

get_diskio_usage() {
  # ルートデバイス名を取得
  local dev
  dev=$(lsblk -dno NAME,MOUNTPOINT 2>/dev/null | awk '$2=="/" {print $1; exit}')
  [ -z "$dev" ] && dev="sda"

  # 現在のio_ticksとタイムスタンプを取得
  local current_io current_ts
  current_io=$(awk -v d="$dev" '$3==d {print $13}' /proc/diskstats 2>/dev/null) || { echo 0; return; }
  [ -z "$current_io" ] && { echo 0; return; }
  current_ts=$(date +%s)

  # キャッシュファイルの読み取り (DEC-002)
  if [ -f "$DISKIO_CACHE_FILE" ]; then
    local prev_ts prev_io
    read -r prev_ts prev_io < "$DISKIO_CACHE_FILE" 2>/dev/null || { echo 0; return; }

    if [ -n "$prev_ts" ] && [ -n "$prev_io" ] && \
       [[ "$prev_ts" =~ ^[0-9]+$ ]] && [[ "$prev_io" =~ ^[0-9]+$ ]]; then
      local age=$(( current_ts - prev_ts ))

      # キャッシュが有効範囲内（1秒以上60秒以内）
      if [ "$age" -ge 1 ] && [ "$age" -le "$DISKIO_CACHE_MAX_AGE" ]; then
        local diff=$(( current_io - prev_io ))
        local interval_ms=$(( age * 1000 ))
        # io_ticksはミリ秒単位、interval_msもミリ秒単位
        local usage=$(( diff * 100 / interval_ms ))
        # 100%を超える場合はキャップ
        [ "$usage" -gt 100 ] && usage=100
        [ "$usage" -lt 0 ] && usage=0

        # キャッシュを更新してから結果を返す
        printf '%s %s' "$current_ts" "$current_io" > "$DISKIO_CACHE_FILE" 2>/dev/null
        echo "$usage"
        return
      fi
    fi
  fi

  # キャッシュがない or 無効 → キャッシュを作成してスキップ（フェイルオープン）
  printf '%s %s' "$current_ts" "$current_io" > "$DISKIO_CACHE_FILE" 2>/dev/null
  echo 0
}

# ==============================================================================
# message-formatter: メッセージフォーマッター
# ==============================================================================

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

# ==============================================================================
# hook-dispatcher: メインロジック
# ==============================================================================

check_agent_resources() {
  local mem_threshold cpu_threshold mem_usage cpu_load

  mem_threshold=$(get_threshold "$ENV_MEM_THRESHOLD" "$DEFAULT_MEM_THRESHOLD")
  cpu_threshold=$(get_threshold "$ENV_CPU_THRESHOLD" "$DEFAULT_CPU_THRESHOLD")

  mem_usage=$(get_memory_usage)
  if [ "$mem_usage" -gt "$mem_threshold" ]; then
    output_block "memory" "$mem_usage" "$mem_threshold"
    exit 0
  fi

  cpu_load=$(get_cpu_load)
  if [ "$cpu_load" -gt "$cpu_threshold" ]; then
    output_block "cpu" "$cpu_load" "$cpu_threshold"
    exit 0
  fi
}

check_bash_resources() {
  local diskio_threshold diskio_usage

  diskio_threshold=$(get_threshold "$ENV_DISKIO_THRESHOLD" "$DEFAULT_DISKIO_THRESHOLD")
  diskio_usage=$(get_diskio_usage)

  if [ "$diskio_usage" -gt "$diskio_threshold" ]; then
    output_warn "diskio" "$diskio_usage" "$diskio_threshold"
  fi
}

main() {
  local input tool_name

  read -r input 2>/dev/null || exit 0

  # tool_nameの抽出（軽量実装、jq不使用）
  tool_name=$(echo "$input" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"') || exit 0

  case "$tool_name" in
    Agent) check_agent_resources ;;
    Bash)  check_bash_resources ;;
    *)     ;; # その他は何もせず終了
  esac
}

# source時はmainを実行しない（テスト用）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
