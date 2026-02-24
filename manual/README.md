# نصب دستی (یک سرویس — ایران یا خارج)

برای وقتی که می‌خواهید فقط **یک** سرویس را با یک `config.yml` و یک `failover.sh` روی سرور ایران یا سرور خارج راه بیندازید، بدون استفاده از اسکریپت نصب خودکار.

---

## سرور ایران

```bash
mkdir wch && cd wch
```

```bash
cat << EOF > config.yml
# Monitor and profile-swap config
# Service to restart after editing the config file
service_name: "backhaul-iran80.service"   # replace با اسم سرویس خودت

# Path to the config file where profile values are swapped (bip <-> tcp)
filename: "/root/backhaul-core/iran80.toml"   # replace با مسیر toml خودت

# IP to ping continuously; when ping fails, profile swap + service restart is triggered
ping_ip: "10.10.10.2"   # replace با IP طرف مقابل تانل

# Role: "primary" or "secondary". Both do the same swap+restart so both sides stay bip/tcp in sync.
role: "primary"

# Seconds to wait after a swap before allowing another swap. Reduces flip-flop.
cooldown_seconds: 600
EOF
```

```bash
cat << 'EOF' > failover.sh
#!/usr/bin/env bash
# Ping monitor: on ping failure, swap profile (bip<->tcp) in config and restart service.
# Intended to run continuously (e.g. under systemd, screen, or nohup).

set -e

CONFIG_FILE="${1:-config.yml}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config file not found: $CONFIG_FILE" >&2
  echo "Usage: $0 [path/to/config.yml]" >&2
  exit 1
fi

get_yml() {
  local key="$1"
  grep -E "^\s*${key}\s*:" "$CONFIG_FILE" | sed -E "s/^[^:]+:[[:space:]]*[\"\']?([^\"']*)[\"']?.*/\1/" | head -1
}

SERVICE_NAME=$(get_yml "service_name")
FILENAME=$(get_yml "filename")
PING_IP=$(get_yml "ping_ip")
ROLE=$(get_yml "role")
COOLDOWN_SECONDS=$(get_yml "cooldown_seconds")

for v in SERVICE_NAME FILENAME PING_IP; do
  eval "val=\$$v"
  if [[ -z "$val" ]]; then
    echo "Error: $v is empty in $CONFIG_FILE." >&2
    exit 1
  fi
done

ROLE="${ROLE:-primary}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-600}"
LAST_SWAP_TIME=0

echo "Config: service=$SERVICE_NAME, file=$FILENAME, ping target=$PING_IP, role=$ROLE, cooldown=${COOLDOWN_SECONDS}s"
echo "Starting ping monitor (stop with Ctrl+C)."
echo "---"

do_swap_and_restart() {
  local now
  now=$(date +%s)
  if (( now - LAST_SWAP_TIME < COOLDOWN_SECONDS )); then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ping failed. Cooldown active ($(( COOLDOWN_SECONDS - (now - LAST_SWAP_TIME) ))s left), skipping swap."
    return 0
  fi
  LAST_SWAP_TIME=$now
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ping failed. Swapping profile and restarting..."
  if [[ ! -f "$FILENAME" ]]; then
    echo "Error: file not found: $FILENAME" >&2
    return 1
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' -e 's/profile = "bip"/profile = "__TMP__"/' \
               -e 's/profile = "tcp"/profile = "bip"/' \
               -e 's/profile = "__TMP__"/profile = "tcp"/' "$FILENAME"
  else
    sed -i.bak -e 's/profile = "bip"/profile = "__TMP__"/' \
               -e 's/profile = "tcp"/profile = "bip"/' \
               -e 's/profile = "__TMP__"/profile = "tcp"/' "$FILENAME"
  fi
  echo "File updated. Restarting service: $SERVICE_NAME"
  if command -v systemctl &>/dev/null; then
    sudo systemctl restart "$SERVICE_NAME" || true
  elif command -v service &>/dev/null; then
    sudo service "$SERVICE_NAME" restart || true
  else
    echo "Warning: systemctl/service not found; restart the service manually." >&2
  fi
  echo "Resuming ping monitor..."
}

while true; do
  if ping -c 4 -W 3 "$PING_IP" &>/dev/null; then
    echo -n "."
  else
    echo ""
    do_swap_and_restart
  fi
  sleep 5
done
EOF
```

```bash
chmod +x failover.sh
```

اجرا در پس‌زمینه:

```bash
nohup ./failover.sh > failover.log 2>&1 &
```

---

## سرور خارج

```bash
mkdir wch && cd wch
```

```bash
cat << EOF > config.yml
# Monitor and profile-swap config
service_name: "backhaul-kharej80.service"   # replace با اسم سرویس خودت

# Path to the config file where profile values are swapped (bip <-> tcp)
filename: "/root/backhaul-core/kharej80.toml"   # replace با مسیر toml خودت

# IP to ping continuously; when ping fails, profile swap + service restart is triggered
ping_ip: "10.10.10.1"   # replace با IP طرف مقابل تانل

role: "primary"

cooldown_seconds: 600
EOF
```

فایل `failover.sh` را عیناً مثل بخش سرور ایران بساز (همان بلوک `cat << 'EOF' > failover.sh` تا `EOF`).

سپس:

```bash
chmod +x failover.sh
nohup ./failover.sh > failover.log 2>&1 &
```

---

## خلاصه

| محل      | سرویس مثال              | فایل toml مثال              | IP پینگ   |
|----------|--------------------------|-----------------------------|-----------|
| ایران    | backhaul-iran80.service  | /root/backhaul-core/iran80.toml  | 10.10.10.2 |
| خارج     | backhaul-kharej80.service | /root/backhaul-core/kharej80.toml | 10.10.10.1 |

مقادیر `# replace` را با مقادیر واقعی همان سرور عوض کنید.
