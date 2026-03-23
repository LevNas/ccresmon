# resource-collector（リソース情報収集）

## 概要

**目的**: ホストPCのリソース使用状況（メモリ、CPU、ディスクI/O）を取得する。Linuxのprocfsと標準コマンドのみを使用し、軽量に動作する。

**責務**:
- メモリ使用率の取得
- CPU負荷（ロードアベレージ / コア数）の取得
- ディスクI/O使用率の取得

## インターフェース

### 公開関数

#### `get_memory_usage(): integer`

**説明**: 現在のメモリ使用率を整数（%）で返す

**実装方法**:
```bash
get_memory_usage() {
  # /proc/meminfo から直接取得（freeコマンドを起動せずprocfsを直接読む）
  local mem_total mem_available
  mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
  mem_available=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
  echo $(( (mem_total - mem_available) * 100 / mem_total ))
}
```

**データソース**: `/proc/meminfo`（`MemTotal`, `MemAvailable`）

**補足**: `free` コマンドの代わりに `/proc/meminfo` を直接読む。これにより外部プロセス起動を1つ減らせる（NFR-PERF-003）。`MemAvailable` はLinux 3.14以降で利用可能であり、WSL2を含む対象環境すべてで利用できる。

---

#### `get_cpu_load(): integer`

**説明**: 現在のCPU負荷を整数（%）で返す。1分間ロードアベレージをCPUコア数で除した値 × 100。

**実装方法**:
```bash
get_cpu_load() {
  local load_avg nproc_count
  load_avg=$(cut -d' ' -f1 /proc/loadavg)
  nproc_count=$(nproc)
  # bash は小数演算できないため awk を使用
  awk "BEGIN { printf \"%d\", ($load_avg / $nproc_count) * 100 }"
}
```

**データソース**: `/proc/loadavg`（1分間ロードアベレージ）, `nproc`（CPUコア数）

---

#### `get_diskio_usage(): integer`

**説明**: ディスクI/O使用率を整数（%）で返す。

**実装方法**:
```bash
get_diskio_usage() {
  # /proc/diskstats からルートデバイスのI/O時間を2回サンプリング
  local dev io1 io2 interval_ms=100
  dev=$(lsblk -dno NAME,MOUNTPOINT 2>/dev/null | awk '$2=="/" {print $1; exit}')
  [ -z "$dev" ] && dev="sda"

  io1=$(awk -v d="$dev" '$3==d {print $13}' /proc/diskstats)
  sleep 0.1
  io2=$(awk -v d="$dev" '$3==d {print $13}' /proc/diskstats)

  # io_ticks はミリ秒単位。100msサンプル間の差分を%に変換
  local diff=$(( io2 - io1 ))
  echo $(( diff * 100 / interval_ms ))
}
```

**データソース**: `/proc/diskstats`（フィールド13: io_ticks, ミリ秒）

**補足**: 2回サンプリングの間隔は100ms（`sleep 0.1`）。NFR-PERF-001の100ms制限に対し、ディスクI/OチェックはBash実行時のみ（Agent起動時には実行しない）ため、トータルで制限内に収まる設計。ただしサンプリング時間を含めると100msを超える可能性がある点はDEC-001で議論。

## 依存関係

### 依存するコンポーネント
- なし（Linuxカーネルのprocfsのみ使用）

### 依存されるコンポーネント
- [hook-dispatcher](hook-dispatcher.md) @hook-dispatcher.md: リソース情報の取得元

## クロスプラットフォーム考慮

| 関数 | Linux/WSL2 | Windows (PowerShell) |
|------|-----------|---------------------|
| `get_memory_usage` | `/proc/meminfo` | `Get-CimInstance Win32_OperatingSystem` |
| `get_cpu_load` | `/proc/loadavg` + `nproc` | `Get-CimInstance Win32_Processor` |
| `get_diskio_usage` | `/proc/diskstats` | `Get-Counter '\PhysicalDisk(_Total)\% Disk Time'` |

Windows対応はスコープ外（要件定義で明示）だが、将来のWindows対応時にはPowerShellスクリプト `ccresmon.ps1` を別途作成し、resource-collector部分のみ差し替える設計とする。

## エラー処理

| エラー種別 | 発生条件 | 対処方法 |
|-----------|---------|---------|
| /proc/meminfo 読み取り失敗 | procfsマウント不備 | 0を返す（チェックスキップ） |
| /proc/loadavg 読み取り失敗 | procfsマウント不備 | 0を返す（チェックスキップ） |
| /proc/diskstats 読み取り失敗 | procfsマウント不備 | 0を返す（チェックスキップ） |
| nproc コマンド不在 | 最小構成環境 | デフォルト1コアとみなす |
| lsblk コマンド不在 | 最小構成環境 | デフォルト"sda"を使用 |

## テスト観点

- [ ] 正常系: メモリ使用率が0〜100の範囲で返される
- [ ] 正常系: CPU負荷が0以上の整数で返される
- [ ] 正常系: ディスクI/O使用率が0〜100の範囲で返される
- [ ] 異常系: /proc/meminfo不在時に0が返される
- [ ] 異常系: /proc/loadavg不在時に0が返される
- [ ] 異常系: nproc不在時にデフォルト1コアで計算される
- [ ] 境界値: メモリが100%の場合
- [ ] 境界値: ロードアベレージが0の場合

## 関連要件

- [REQ-001-001](../../requirements/stories/US-001.md) @../../requirements/stories/US-001.md: メモリ使用率取得
- [REQ-001-002](../../requirements/stories/US-001.md) @../../requirements/stories/US-001.md: CPU負荷取得
- [REQ-002-001](../../requirements/stories/US-002.md) @../../requirements/stories/US-002.md: ディスクI/O負荷取得
- [NFR-CMP-002](../../requirements/nfr/compatibility.md) @../../requirements/nfr/compatibility.md: 外部依存なし
- [NFR-CMP-003](../../requirements/nfr/compatibility.md) @../../requirements/nfr/compatibility.md: procfsの利用
