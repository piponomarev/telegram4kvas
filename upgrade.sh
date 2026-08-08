#!/bin/sh

BOT_PATH="/opt/etc/telegram4kvas"
CONFIG_FILE="${BOT_PATH}/telegram_bot_config.py"
AWG_CONFIG="${BOT_PATH}/telegram4kvas.conf"
INIT_FILE="/opt/etc/init.d/S98telegram4kvas"

REPO="piponomarev/telegram4kvas"
RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"

TMP_DIR="/opt/tmp/telegram4kvas-upgrade"
BACKUP_DIR="${TMP_DIR}/backup"


get_installed_version() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "telegram4kvas: конфигурационный файл не найден:"
        echo "$CONFIG_FILE"
        return 1
    fi

    installed_version=$(sed -n \
        "s/^version[[:space:]]*=[[:space:]]*['\"]\\([^'\"]*\\)['\"].*/\\1/p" \
        "$CONFIG_FILE" |
        head -n 1)

    if [ -z "$installed_version" ]; then
        installed_version="unknown"
    fi

    return 0
}


get_latest_release() {
    echo "telegram4kvas: получение информации о последнем Release..."

    release_json=$(curl -fsSL \
        -H "Accept: application/vnd.github.v3+json" \
        "$RELEASE_URL")

    if [ $? -ne 0 ] || [ -z "$release_json" ]; then
        echo "telegram4kvas: ошибка получения информации о GitHub Release."
        return 1
    fi

    latest_version=$(echo "$release_json" |
        sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        head -n 1)

    zipball_url=$(echo "$release_json" |
        sed -n 's/.*"zipball_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        head -n 1)

    if [ -z "$latest_version" ]; then
        echo "telegram4kvas: не удалось определить последнюю версию."
        return 1
    fi

    if [ -z "$zipball_url" ]; then
        echo "telegram4kvas: GitHub не вернул ссылку на архив."
        return 1
    fi

    return 0
}


check_awg() {
    if [ ! -f "$AWG_CONFIG" ]; then
        echo "telegram4kvas: конфигурация AWG не найдена:"
        echo "$AWG_CONFIG"
        return 1
    fi

    . "$AWG_CONFIG"

    if [ -z "$TELEGRAM_AWG_INTERFACE" ]; then
        echo "telegram4kvas: AWG-интерфейс не настроен."
        return 1
    fi

    if ! ip link show "$TELEGRAM_AWG_INTERFACE" >/dev/null 2>&1; then
        echo "telegram4kvas: AWG-интерфейс не найден:"
        echo "$TELEGRAM_AWG_INTERFACE"
        return 1
    fi

    return 0
}


check_update() {
    get_installed_version || return 1
    get_latest_release || return 1

    echo ""
    echo "telegram4kvas: установленная версия: $installed_version"
    echo "telegram4kvas: последняя версия:     $latest_version"
    echo ""

    if [ "$installed_version" = "$latest_version" ]; then
        echo "telegram4kvas: установлена последняя версия."
        echo "telegram4kvas: обновление не требуется."
        return 2
    fi

    if [ "$installed_version" = "unknown" ]; then
        echo "telegram4kvas: текущая версия не определена."
    else
        echo "telegram4kvas: доступно обновление:"
        echo "$installed_version -> $latest_version"
    fi

    return 0
}


cleanup() {
    rm -rf "$TMP_DIR"
}


create_backup() {
    echo "telegram4kvas: создание резервной копии..."

    rm -rf "$TMP_DIR"
    mkdir -p "$BACKUP_DIR"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: не удалось создать временный каталог."
        return 1
    fi

    if [ -d "$BOT_PATH" ]; then
        cp -R "$BOT_PATH" "$BACKUP_DIR/telegram4kvas"

        if [ $? -ne 0 ]; then
            echo "telegram4kvas: не удалось сохранить каталог бота."
            cleanup
            return 1
        fi
    fi

    if [ -f "$INIT_FILE" ]; then
        cp "$INIT_FILE" "$BACKUP_DIR/S98telegram4kvas"

        if [ $? -ne 0 ]; then
            echo "telegram4kvas: не удалось сохранить init-скрипт."
            cleanup
            return 1
        fi
    fi

    if [ -f "/opt/upgrade.sh" ]; then
        cp "/opt/upgrade.sh" "$BACKUP_DIR/upgrade.sh"

        if [ $? -ne 0 ]; then
            echo "telegram4kvas: не удалось сохранить updater."
            cleanup
            return 1
        fi
    fi

    return 0
}


rollback() {
    echo ""
    echo "telegram4kvas: выполняется откат..."

    if [ -d "$BACKUP_DIR/telegram4kvas" ]; then
        rm -rf "$BOT_PATH"
        cp -R "$BACKUP_DIR/telegram4kvas" "$BOT_PATH"
    fi

    if [ -f "$BACKUP_DIR/S98telegram4kvas" ]; then
        cp "$BACKUP_DIR/S98telegram4kvas" "$INIT_FILE"
        chmod +x "$INIT_FILE"
    fi

    if [ -f "$BACKUP_DIR/upgrade.sh" ]; then
        cp "$BACKUP_DIR/upgrade.sh" "/opt/upgrade.sh"
        chmod +x "/opt/upgrade.sh"
    fi

    echo "telegram4kvas: старая версия восстановлена."

    cleanup

    if [ -x "$INIT_FILE" ]; then
        "$INIT_FILE" start >/dev/null 2>&1
    fi
}


download_release() {
    echo ""
    echo "telegram4kvas: скачивание Release $latest_version..."

    mkdir -p "$TMP_DIR/release"

    curl -fsSL -L \
        -o "$TMP_DIR/release.zip" \
        "$zipball_url"

    if [ $? -ne 0 ] || [ ! -s "$TMP_DIR/release.zip" ]; then
        echo "telegram4kvas: ошибка скачивания Release."
        return 1
    fi

    echo "telegram4kvas: распаковка Release..."

    unzip -q \
        "$TMP_DIR/release.zip" \
        -d "$TMP_DIR/release"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: ошибка распаковки Release."
        return 1
    fi

    RELEASE_ROOT=$(find "$TMP_DIR/release" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d |
        head -n 1)

    if [ -z "$RELEASE_ROOT" ]; then
        echo "telegram4kvas: каталог Release не найден."
        return 1
    fi

    return 0
}


validate_release() {
    echo "telegram4kvas: проверка файлов Release..."

    required_files="
telegram_bot.py
telegram_bot_config.py
S98telegram4kvas
upgrade.sh
"

    for file in $required_files; do
        if [ ! -f "$RELEASE_ROOT/$file" ]; then
            echo "telegram4kvas: отсутствует файл:"
            echo "$file"
            return 1
        fi
    done

    if [ ! -d "$RELEASE_ROOT/telebot" ]; then
        echo "telegram4kvas: отсутствует каталог:"
        echo "telebot"
        return 1
    fi

    return 0
}


install_release() {
    echo ""
    echo "telegram4kvas: остановка бота..."

    "$INIT_FILE" stop >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: предупреждение — бот уже был остановлен."
    fi

    echo "telegram4kvas: установка новой версии..."

    cp "$RELEASE_ROOT/telegram_bot.py" \
        "$BOT_PATH/telegram_bot.py"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: ошибка установки telegram_bot.py."
        return 1
    fi

    rm -rf "$BOT_PATH/telebot"

    cp -R "$RELEASE_ROOT/telebot" \
        "$BOT_PATH/telebot"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: ошибка установки telebot."
        return 1
    fi

    cp "$RELEASE_ROOT/S98telegram4kvas" \
        "$INIT_FILE"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: ошибка установки S98telegram4kvas."
        return 1
    fi

    chmod +x "$INIT_FILE"

    return 0
}


update_version() {
    echo "telegram4kvas: запись версии $latest_version..."

    sed -i '/^version[[:space:]]*=/d' "$CONFIG_FILE"

    echo "version = '$latest_version'" >> "$CONFIG_FILE"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: ошибка записи версии."
        return 1
    fi

    return 0
}


start_bot() {
    echo ""
    echo "telegram4kvas: запуск бота..."

    "$INIT_FILE" start

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: ошибка запуска бота."
        return 1
    fi

    return 0
}


perform_update() {
    if ! check_awg; then
        return 1
    fi

    echo ""
    echo "telegram4kvas: AWG интерфейс: $TELEGRAM_AWG_INTERFACE"

    if ! create_backup; then
        return 1
    fi

    if ! download_release; then
        cleanup
        return 1
    fi

    if ! validate_release; then
        cleanup
        return 1
    fi

    if ! install_release; then
        rollback
        return 1
    fi

    if ! update_version; then
        rollback
        return 1
    fi

    if ! start_bot; then
        rollback
        return 1
    fi

    echo ""
    echo "telegram4kvas: проверка запущенного бота..."

    sleep 2

    if ! pgrep -f "telegram_bot.py" >/dev/null 2>&1; then
        echo "telegram4kvas: бот не запустился."
        rollback
        return 1
    fi

    echo "telegram4kvas: бот успешно запущен."

    echo ""
    echo "telegram4kvas: установка нового updater..."

    cp "$RELEASE_ROOT/upgrade.sh" "/opt/upgrade.sh"

    if [ $? -ne 0 ]; then
        echo "telegram4kvas: не удалось обновить updater."
        echo "telegram4kvas: текущая версия бота продолжает работать."
        cleanup
        return 1
    fi

    chmod +x "/opt/upgrade.sh"

    cleanup

    logger -s -t telegram4kvas \
        "telegram4kvas обновлен до $latest_version"

    echo ""
    echo "========================================"
    echo "Обновление завершено успешно!"
    echo "========================================"
    echo ""
    echo "Версия:       $latest_version"
    echo "AWG интерфейс: $TELEGRAM_AWG_INTERFACE"
    echo ""

    return 0
}


case "$1" in

    --check)
        check_update
        result=$?

        if [ "$result" -eq 2 ]; then
            exit 0
        fi

        exit "$result"
        ;;

    "")
        echo ""
        echo "========================================"
        echo "telegram4kvas — проверка обновлений"
        echo "========================================"
        echo ""

        check_update
        result=$?

        if [ "$result" -eq 2 ]; then
            exit 0
        fi

        if [ "$result" -ne 0 ]; then
            exit 1
        fi

        perform_update
        exit $?
        ;;

    *)
        echo "Использование:"
        echo ""
        echo "  /opt/upgrade.sh"
        echo "      Проверить и установить обновление."
        echo ""
        echo "  /opt/upgrade.sh --check"
        echo "      Только проверить наличие обновления."
        echo ""

        exit 1
        ;;
esac
