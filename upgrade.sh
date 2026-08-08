#!/bin/sh

BOT_PATH="/opt/etc/telegram4kvas"
BOT_FILE="${BOT_PATH}/telegram_bot.py"
CONFIG_FILE="${BOT_PATH}/telegram_bot_config.py"
AWG_CONFIG="${BOT_PATH}/telegram4kvas.conf"
INIT_FILE="/opt/etc/init.d/S98telegram4kvas"
TMP_DIR="/opt/tmp/telegram4kvas-upgrade"
RELEASE_URL="https://api.github.com/repos/piponomarev/telegram4kvas/releases/latest"

echo "telegram4kvas: starting update"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "telegram4kvas: configuration file not found:"
    echo "$CONFIG_FILE"
    exit 1
fi

if [ ! -f "$AWG_CONFIG" ]; then
    echo "telegram4kvas: AWG configuration file not found:"
    echo "$AWG_CONFIG"
    echo "Update aborted."
    exit 1
fi

. "$AWG_CONFIG"

if [ -z "$TELEGRAM_AWG_INTERFACE" ]; then
    echo "telegram4kvas: AWG interface is not configured."
    echo "Update aborted."
    exit 1
fi

if ! ip link show "$TELEGRAM_AWG_INTERFACE" >/dev/null 2>&1; then
    echo "telegram4kvas: configured AWG interface not found:"
    echo "$TELEGRAM_AWG_INTERFACE"
    echo "Update aborted."
    exit 1
fi

echo "telegram4kvas: using AWG interface $TELEGRAM_AWG_INTERFACE"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "telegram4kvas: downloading latest release"

release_json=$(curl -fsSL \
    -H "Accept: application/vnd.github.v3+json" \
    "$RELEASE_URL")

if [ $? -ne 0 ] || [ -z "$release_json" ]; then
    echo "telegram4kvas: failed to get latest release information."
    rm -rf "$TMP_DIR"
    exit 1
fi

latest_version=$(echo "$release_json" |
    grep '"tag_name"' |
    head -n 1 |
    awk -F'"' '{print $4}')

package_url=$(echo "$release_json" |
    sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p' |
    head -n 1)

if [ -z "$latest_version" ]; then
    echo "telegram4kvas: failed to determine latest version."
    rm -rf "$TMP_DIR"
    exit 1
fi

if [ -z "$package_url" ]; then
    echo "telegram4kvas: release does not contain a downloadable package."
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "telegram4kvas: latest version: $latest_version"

echo "telegram4kvas: downloading package"

curl -fsSL -o "$TMP_DIR/package" "$package_url"

if [ $? -ne 0 ] || [ ! -s "$TMP_DIR/package" ]; then
    echo "telegram4kvas: failed to download release package."
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "telegram4kvas: stopping bot"

/opt/etc/init.d/S98telegram4kvas stop

echo "telegram4kvas: updating bot files"

rm -rf "$TMP_DIR/package-extracted"
mkdir -p "$TMP_DIR/package-extracted"

tar -xf "$TMP_DIR/package" -C "$TMP_DIR/package-extracted" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "telegram4kvas: failed to extract release package."
    rm -rf "$TMP_DIR"
    /opt/etc/init.d/S98telegram4kvas start
    exit 1
fi

RELEASE_ROOT=$(find "$TMP_DIR/package-extracted" -type f -name "telegram_bot.py" -exec dirname {} \; | head -n 1)

if [ -z "$RELEASE_ROOT" ]; then
    echo "telegram4kvas: telegram_bot.py not found in release package."
    rm -rf "$TMP_DIR"
    /opt/etc/init.d/S98telegram4kvas start
    exit 1
fi

if [ -f "$RELEASE_ROOT/telegram_bot.py" ]; then
    cp "$RELEASE_ROOT/telegram_bot.py" "$BOT_FILE"
fi

if [ -d "$RELEASE_ROOT/telebot" ]; then
    rm -rf "${BOT_PATH}/telebot"
    cp -R "$RELEASE_ROOT/telebot" "${BOT_PATH}/telebot"
fi

if [ -f "$RELEASE_ROOT/S98telegram4kvas" ]; then
    cp "$RELEASE_ROOT/S98telegram4kvas" "$INIT_FILE"
    chmod +x "$INIT_FILE"
fi

echo "telegram4kvas: preserving configuration"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "telegram4kvas: ERROR: telegram_bot_config.py disappeared."
    rm -rf "$TMP_DIR"
    exit 1
fi

if [ ! -f "$AWG_CONFIG" ]; then
    echo "telegram4kvas: ERROR: telegram4kvas.conf disappeared."
    rm -rf "$TMP_DIR"
    exit 1
fi

if ! grep -q "^reconnection_timeout" "$CONFIG_FILE"; then
    echo "reconnection_timeout = 60" >> "$CONFIG_FILE"
fi

if ! grep -q "^reconnection_attempts" "$CONFIG_FILE"; then
    echo "reconnection_attempts = 5" >> "$CONFIG_FILE"
fi

sed -i '/^version = /d' "$CONFIG_FILE"
echo "version = '$latest_version'" >> "$CONFIG_FILE"

echo "telegram4kvas: installed version $latest_version"
echo "telegram4kvas: AWG interface $TELEGRAM_AWG_INTERFACE"

rm -rf "$TMP_DIR"

logger -s -t telegram4kvas "Бот обновлен до $latest_version"

echo "telegram4kvas: restarting bot"

/opt/etc/init.d/S98telegram4kvas restart

if [ $? -ne 0 ]; then
    echo "telegram4kvas: bot restart failed."
    exit 1
fi

echo "telegram4kvas: update completed successfully"
