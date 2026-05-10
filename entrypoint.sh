#!/bin/sh
trap '' PIPE

DURATION_RAW=${DURATION:-"unli"}
MAX_CONN=${MAX_CONN:-100}
MAINT_SECS=3600

# ─────────────────────────────────────────
# Parse duration
# ─────────────────────────────────────────
parse_seconds() {
  case $1 in
    *h) echo $(( ${1%h} * 3600 )) ;;
    *d) echo $(( ${1%d} * 86400 )) ;;
    *m) echo $(( ${1%m} * 2592000 )) ;;
    *)  echo 0 ;;
  esac
}

DURATION_SECS=$(parse_seconds "$DURATION_RAW")

if [ "$DURATION_SECS" -gt 0 ] && [ "$DURATION_SECS" -le 604800 ]; then
  REFRESH_SECS=21600
else
  REFRESH_SECS=19800
fi

# ─────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────
gen_uuid() {
  HEX=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32)
  echo "$HEX" | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
}
gen_pass()   { cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 24; }
gen_suffix() { cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8; }

write_status() {
cat > /var/lib/nginx/html/status.json << EOF
{
  "status":       "$1",
  "uuid":         "$2",
  "password":     "$3",
  "suffix": {
    "vless_ws":  "$4",
    "vmess_ws":  "$5",
    "trojan_ws": "$6",
    "ss_ws":     "$7"
  },
  "created":      $START_EPOCH,
  "next_refresh": $8,
  "duration":     "$DURATION_RAW",
  "refresh_secs": $REFRESH_SECS
}
EOF
}

# ─────────────────────────────────────────
# Setup
# ─────────────────────────────────────────
sed -i "s/MAX_CONN_HERE/$MAX_CONN/g" /etc/nginx/nginx.conf

mkdir -p /var/lib/nginx/html
cp /index.html       /var/lib/nginx/html/index.html
cp /maintenance.html /var/lib/nginx/html/maintenance.html

START_EPOCH=$(date +%s)

# ─────────────────────────────────────────
# Generate initial credentials
# ─────────────────────────────────────────
UUID=$(gen_uuid)
PASS=$(gen_pass)
S1=$(gen_suffix); S2=$(gen_suffix)
S3=$(gen_suffix); S4=$(gen_suffix)

sed \
  -e "s/PLACEHOLDER_UUID/$UUID/g" \
  -e "s/PLACEHOLDER_PASS/$PASS/g" \
  -e "s/PLACEHOLDER_S1/$S1/g" \
  -e "s/PLACEHOLDER_S2/$S2/g" \
  -e "s/PLACEHOLDER_S3/$S3/g" \
  -e "s/PLACEHOLDER_S4/$S4/g" \
  /etc/xray/config.json > /tmp/xray-config.json

NEXT=$(( START_EPOCH + REFRESH_SECS ))
write_status "online" "$UUID" "$PASS" "$S1" "$S2" "$S3" "$S4" "$NEXT"

# ─────────────────────────────────────────
# Start supervisord (nginx + xray)
# ─────────────────────────────────────────
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
sleep 2

echo "[entrypoint] Started — UUID: $UUID"

# ─────────────────────────────────────────
# Refresh loop
# ─────────────────────────────────────────
CYCLE=1
while true; do
  sleep $REFRESH_SECS

  # Check duration expiry
  if [ "$DURATION_SECS" -gt 0 ]; then
    ELAPSED=$(( $(date +%s) - START_EPOCH ))
    if [ "$ELAPSED" -ge "$DURATION_SECS" ]; then
      cat > /var/lib/nginx/html/status.json << EOF
{"status":"expired","created":$START_EPOCH,"duration":"$DURATION_RAW"}
EOF
      pkill xray 2>/dev/null || true
      wait
      exit 0
    fi
  fi

  # ── Maintenance window ──────────────────
  MAINT_END=$(( $(date +%s) + MAINT_SECS ))
  cat > /var/lib/nginx/html/status.json << EOF
{"status":"maintenance","created":$START_EPOCH,"next_refresh":$MAINT_END,"duration":"$DURATION_RAW"}
EOF
  pkill -SIGTERM xray 2>/dev/null || true
  sleep $MAINT_SECS

  # ── Generate new credentials ────────────
  CYCLE=$(( CYCLE + 1 ))
  UUID=$(gen_uuid)
  PASS=$(gen_pass)
  S1=$(gen_suffix); S2=$(gen_suffix)
  S3=$(gen_suffix); S4=$(gen_suffix)

  sed \
    -e "s/PLACEHOLDER_UUID/$UUID/g" \
    -e "s/PLACEHOLDER_PASS/$PASS/g" \
    -e "s/PLACEHOLDER_S1/$S1/g" \
    -e "s/PLACEHOLDER_S2/$S2/g" \
    -e "s/PLACEHOLDER_S3/$S3/g" \
    -e "s/PLACEHOLDER_S4/$S4/g" \
    /etc/xray/config.json > /tmp/xray-config.json

  NEXT=$(( $(date +%s) + REFRESH_SECS ))
  write_status "online" "$UUID" "$PASS" "$S1" "$S2" "$S3" "$S4" "$NEXT"

  trap '' PIPE
  xray run -c /tmp/xray-config.json &

done
