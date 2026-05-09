#!/bin/sh
trap '' PIPE

# ─────────────────────────────────────────
# UUID + PASS generation
# ─────────────────────────────────────────
HEX=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32)
UUID=$(echo "$HEX" | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 24)

# ─────────────────────────────────────────
# Suffix generation (8 unique suffixes)
# ─────────────────────────────────────────
gen_suffix() { cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8; }
S1=$(gen_suffix); S2=$(gen_suffix); S3=$(gen_suffix); S4=$(gen_suffix)
S5=$(gen_suffix); S6=$(gen_suffix); S7=$(gen_suffix); S8=$(gen_suffix)

echo "[entrypoint] UUID: $UUID"
echo "[entrypoint] PASS: $PASS"

# ─────────────────────────────────────────
# Setup html dir
# ─────────────────────────────────────────
mkdir -p /var/lib/nginx/html
cp /index.html       /var/lib/nginx/html/index.html
cp /maintenance.html /var/lib/nginx/html/maintenance.html

# ─────────────────────────────────────────
# Inject into xray config
# ─────────────────────────────────────────
sed \
  -e "s/PLACEHOLDER_UUID/$UUID/g" \
  -e "s/PLACEHOLDER_PASS/$PASS/g" \
  -e "s/PLACEHOLDER_S1/$S1/g" \
  -e "s/PLACEHOLDER_S2/$S2/g" \
  -e "s/PLACEHOLDER_S3/$S3/g" \
  -e "s/PLACEHOLDER_S4/$S4/g" \
  -e "s/PLACEHOLDER_S5/$S5/g" \
  -e "s/PLACEHOLDER_S6/$S6/g" \
  -e "s/PLACEHOLDER_S7/$S7/g" \
  -e "s/PLACEHOLDER_S8/$S8/g" \
  /etc/xray/config.json > /tmp/xray-config.json

# ─────────────────────────────────────────
# Write status.json
# ─────────────────────────────────────────
START=$(date +%s)
NEXT=$(( START + 19800 ))

cat > /var/lib/nginx/html/status.json << EOF
{
  "status":       "online",
  "uuid":         "$UUID",
  "password":     "$PASS",
  "suffix": {
    "vless_ws":  "$S1",
    "vless_hu":  "$S2",
    "vmess_ws":  "$S3",
    "vmess_hu":  "$S4",
    "trojan_ws": "$S5",
    "trojan_hu": "$S6",
    "ss_ws":     "$S7",
    "ss_hu":     "$S8"
  },
  "created":      $START,
  "next_refresh": $NEXT,
  "duration":     "unli",
  "refresh_secs": 19800
}
EOF

echo "[entrypoint] Files: $(ls /var/lib/nginx/html/)"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
