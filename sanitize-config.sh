#!/usr/bin/env bash
set -euo pipefail
CFG=".config"
BACKUP=".config.orig"
KEEP_PATTERNS=(
  "^CONFIG_TARGET_"
  "^CONFIG_TARGET_DEVICE_"
  "^CONFIG_TARGET_.*_DEVICE_"
  "^CONFIG_TARGET_ROOTFS"
  "^CONFIG_KERNEL_"
  "^CONFIG_KMOD_"
  "^CONFIG_USB_"
  "^CONFIG_PACKAGE_kmod"
  "^CONFIG_NETFILTER_"
  "^CONFIG_BRIDGE_"
  "^CONFIG_NF_"
  "^CONFIG_SOMAXCONN"
  "^CONFIG_PACKAGE_base-files"
  "^CONFIG_BUILD_"
  "^CONFIG_VERSION"
)

# Packages we *must* enable
REQUIRED_PACKAGES=(
  "CONFIG_PACKAGE_nikki=y"
  "CONFIG_PACKAGE_luci-app-nikki=y"
  "CONFIG_PACKAGE_luci-i18n-nikki-zh-cn=y"
)

DOCKER_PACKAGES=(
  "CONFIG_PACKAGE_docker=y"
  "CONFIG_PACKAGE_dockerd=y"
  "CONFIG_PACKAGE_docker-compose=y"
)

if [ -f "$CFG" ]; then
  cp -a "$CFG" "$BACKUP"
else
  echo "No ${CFG} found in $(pwd) — aborting" >&2
  exit 1
fi

TMPCFG="${CFG}.tmp"
: > "$TMPCFG"

while IFS= read -r line; do
  keep=false
  for pat in "${KEEP_PATTERNS[@]}"; do
    if echo "$line" | grep -qiE "$pat"; then
      keep=true
      break
    fi
  done
  if $keep; then
    echo "$line" >> "$TMPCFG"
  fi
done < "$BACKUP"

grep -E '^CONFIG_BUILD|^CONFIG_TARGET' "$BACKUP" >> "$TMPCFG" || true

echo "" >> "$TMPCFG"
echo "# --- sanitized: keep nikki + docker packages ---" >> "$TMPCFG"

for p in "${REQUIRED_PACKAGES[@]}"; do
  grep -qF "$p" "$TMPCFG" || echo "$p" >> "$TMPCFG"
done

for p in "${DOCKER_PACKAGES[@]}"; do
  grep -qF "$p" "$TMPCFG" || echo "$p" >> "$TMPCFG"
done

grep -qE '^CONFIG_BUILD_MANIFEST' "$TMPCFG" || echo "CONFIG_BUILD_MANIFEST=y" >> "$TMPCFG"

mv "$TMPCFG" "$CFG"

echo "Sanitization done. Backed up original to $BACKUP"
echo "New .config head:"
head -n 200 "$CFG" || true
