#!/bin/sh

bot_path="/opt/etc/telegram4kvas"
config_path="${bot_path}/telegram_bot_config.py"
awg_config_path="${bot_path}/telegram4kvas.conf"
release_url="https://api.github.com/repos/piponomarev/telegram4kvas/releases"

latest_version=$(curl -sH "Accept: application/vnd.github.v3+json" "${release_url}/latest" | grep tag_name | awk -F\" '{print $4}')

PACKAGES="python3-base python3 python3-light libpython3 python3-logging python3-email python3-urllib python3-urllib3 python3-idna python3-requests python3-certifi python3-chardet python3-openssl python3-codecs"

install_packages() {
    freespace=$(df -k /opt | awk 'NR==2 {print $4}')

    if [ "$freespace" -gt 30000 ]; then
        echo "Свободного места достаточно (${freespace} KB), устанавливаю все пакеты сразу..."
        opkg install --nodeps $PACKAGES >/dev/null 2>&1
        return
    fi

    echo "Свободного места мало (${freespace} KB), устанавливаю пакеты по одному..."

    index=0

    for pkg in $PACKAGES; do
        attempts=0

        while true; do
            freespace=$(df -k /opt | awk 'NR==2 {print $4}')
            pkg_size=$(opkg info "$pkg" 2>/dev/null | awk '/^Size:/ {print $2}')

            if [ -z "$pkg_size" ]; then
                echo ""
                echo "Ошибка: Не удалось определить размер пакета $pkg."
                echo "Проверьте интернет-соединение."
                exit 1
            fi

            pkg_size_kb=$((pkg_size / 1024))

            if [ "$freespace" -le "$pkg_size_kb" ]; then
                attempts=$((attempts + 1))

                if [ "$attempts" -ge 3 ]; then
                    echo ""
                    echo "Ошибка: Недостаточно места для установки $pkg."
                    echo "Нужно: ${pkg_size_kb} KB, доступно: ${freespace} KB."
                    exit 1
                fi

                echo ""
                echo "Недостаточно места для $pkg."
                echo "Нужно: ${pkg_size_kb} KB, доступно: ${freespace} KB."
                echo "Ожидание 5 секунд..."

                sleep 5
                continue
            fi

            opkg install --nodeps "$pkg" >/dev/null 2>&1

            index=$((index + 1))

            printf "\rУстановлено пакетов: %s из 14" "$index"

            sleep 1
            break
        done
    done

    echo ""
}

find_awg_interfaces() {
    ip -o link show 2>/dev/null |
        awk -F': ' '{print $2}' |
        cut -d'@' -f1 |
        while read -r iface; do
            case "$iface" in
                nwg*)
                    echo "$iface"
                    ;;
            esac
        done
}

select_awg_interface() {
    interfaces=$(find_awg_interfaces)

    if [ -z "$interfaces" ]; then
        echo ""
        echo "Ошибка: интерфейсы AWG nwg* не найдены."
        echo "Убедитесь, что нужный AmneziaWG-туннель уже запущен."
        exit 1
    fi

    echo ""
    echo "Доступные AWG интерфейсы:"
    echo ""

    count=0

    for iface in $interfaces; do
        count=$((count + 1))
        echo "$count) $iface"
    done

    echo ""

    while true; do
        printf "Выберите интерфейс [1-%s]: " "$count"
        read -r selection

        case "$selection" in
            ''|*[!0-9]*)
                echo "Ошибка: введите номер интерфейса."
                ;;
            *)
                if [ "$selection" -ge 1 ] && [ "$selection" -le "$count" ]; then
                    selected_interface=$(echo "$interfaces" | sed -n "${selection}p")
                    break
                fi

                echo "Ошибка: выберите номер от 1 до $count."
                ;;
        esac
    done

    echo ""
    echo "Выбран AWG интерфейс: $selected_interface"

    printf 'TELEGRAM_AWG_INTERFACE="%s"\n' "$selected_interface" > "$awg_config_path"
    chmod 600 "$awg_config_path"

    echo "Конфигурация AWG сохранена:"
    echo "$awg_config_path"
}

if [ "$1" = "-remove" ]; then
    if [ -x /opt/etc/init.d/S98telegram4kvas ]; then
        /opt/etc/init.d/S98telegram4kvas stop
    fi

    rm -f /opt/etc/init.d/S98telegram4kvas

    opkg remove --force-removal-of-dependent-packages python3* >/dev/null 2>&1

    rm -rf "${bot_path}"

    echo "Бот, конфигурация и зависимости удалены."
    exit 0
fi

if [ "$1" = "-install" ]; then

    freespace=$(df -k | grep opt | awk '/[0-9]%/{print $(NF-2)}')
    freespaceh=$(df -kh | grep opt | awk '/[0-9]%/{print $(NF-2)}')

    if [ "$freespace" -le 10000 ]; then
        echo "У вас доступно ${freespaceh}, а для установки необходимо минимум 10M."
        exit 1
    fi

    echo "Обновление списка пакетов..."
    opkg update >/dev/null 2>&1

    if opkg list-installed | grep -q kvas; then
        echo "КВАС установлен, продолжаем..."
    else
        echo "Сначала установите КВАС. Прерывание установки."
        exit 1
    fi

    install_packages

    mkdir -p "${bot_path}"

    echo ""
    echo "Скачивание архива с GitHub..."

    curl -Lo /opt/tmp/main.zip \
        https://github.com/piponomarev/telegram4kvas/archive/refs/heads/main.zip \
        >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "Ошибка скачивания telegram4kvas."
        exit 1
    fi

    echo "Распаковка архива..."

    unzip -q /opt/tmp/main.zip -d /opt/tmp

    if [ $? -ne 0 ]; then
        echo "Ошибка распаковки архива."
        exit 1
    fi

    echo "Копирование файлов..."

    cp /opt/tmp/telegram4kvas-main/telegram_bot_config.py "${bot_path}"
    cp /opt/tmp/telegram4kvas-main/telegram_bot.py "${bot_path}"
    cp -r /opt/tmp/telegram4kvas-main/telebot "${bot_path}"
    cp /opt/tmp/telegram4kvas-main/S98telegram4kvas /opt/etc/init.d/S98telegram4kvas

    chmod +x /opt/etc/init.d/S98telegram4kvas

    echo ""
    echo "Введите API ключ, полученный от BotFather:"
    read -r api

    if [ -z "$api" ]; then
        echo "Ошибка: API ключ не может быть пустым."
        exit 1
    fi

    sed -i "s|^token = .*|token = '${api}'|" "${config_path}"

    echo ""
    echo "Введите Telegram User ID администратора:"
    read -r userid

    case "$userid" in
        ''|*[!0-9]*)
            echo "Ошибка: User ID должен содержать только цифры."
            exit 1
            ;;
    esac

    sed -i "s|^userid = .*|userid = [${userid}]|" "${config_path}"

    echo ""
    echo "Telegram User ID сохранён: ${userid}"

    sed -i '/^version = /d' "${config_path}"
    echo "version = '${latest_version}'" >> "${config_path}"

    select_awg_interface

    echo ""
    echo "Проверка выбранного AWG интерфейса..."

    if ! ip link show "$selected_interface" >/dev/null 2>&1; then
        echo "Ошибка: интерфейс ${selected_interface} недоступен."
        exit 1
    fi

    echo ""
    echo "Запуск telegram4kvas..."

    /opt/etc/init.d/S98telegram4kvas start

    if [ $? -ne 0 ]; then
        echo ""
        echo "Ошибка запуска telegram4kvas."
        exit 1
    fi

    echo ""
    echo "Очистка временных файлов..."

    rm -rf /opt/tmp/main.zip
    rm -rf /opt/tmp/telegram4kvas-main

    echo ""
    echo "========================================"
    echo "Установка завершена!"
    echo "========================================"
    echo ""
    echo "AWG интерфейс: ${selected_interface}"
    echo "Telegram User ID: ${userid}"
    echo ""
    echo "Проверка:"
    echo "/opt/etc/init.d/S98telegram4kvas status"
    echo ""
    echo "Смена AWG интерфейса:"
    echo "/opt/etc/init.d/S98telegram4kvas interface"
    echo ""

    exit 0
fi

if [ "$1" = "-help" ] || [ -z "$1" ]; then
    echo "Использование: $0 [опция]"
    echo ""
    echo "Опции:"
    echo "  -install  Установить бота"
    echo "  -remove   Удалить бота и все зависимости"
    echo "  -help     Показать эту справку"
    exit 0
fi
