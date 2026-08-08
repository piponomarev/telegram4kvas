# telegram4kvas
Telegram bot for [KVAS](https://github.com/qzeleza/kvas) by [qzeleza](https://github.com/qzeleza)

Telegram-бот для управления KVAS на роутерах Keenetic с использованием AmneziaWG.

Проект предназначен для запуска Telegram-бота непосредственно на роутере с Entware и установленным KVAS.

Возможности

* управление KVAS через Telegram;
* авторизация пользователей по Telegram User ID;
* работа через AmneziaWG;
* выбор активного AWG-интерфейса nwg*;
* автоматическое сохранение выбранного AWG-интерфейса;
* автоматический запуск бота после перезагрузки роутера;
* автоматическое переподключение при временной недоступности интернета;
* установка через GitHub;
* установка конкретной версии из GitHub Release;
* проверка версии установленного бота;
* обновление через GitHub Releases.

Требования

Перед установкой должны быть выполнены следующие условия:

* роутер Keenetic;
* установлен Entware;
* установлен и настроен KVAS;
* установлен и запущен AmneziaWG;
* существует хотя бы один интерфейс nwg*;
* роутер имеет доступ в интернет.

Проверить наличие AWG-интерфейсов можно командой:

ip link show

Например:

nwg3

Установка

Установочный скрипт находится в этом репозитории.

Для установки выполните:

curl -OLf https://raw.githubusercontent.com/piponomarev/telegram4kvas/main/script/install.sh && sh install.sh -install

Установщик:

1. проверит свободное место;
2. проверит наличие KVAS;
3. обновит список пакетов Entware;
4. установит необходимые Python-зависимости;
5. определит последний опубликованный GitHub Release;
6. скачает архив Release;
7. установит файлы telegram4kvas;
8. запросит API-токен Telegram-бота;
9. запросит Telegram User ID администратора;
10. предложит выбрать AWG-интерфейс;
11. сохранит конфигурацию;
12. запустит бота.

Создание Telegram-бота

Для создания бота используйте @BotFather.

В Telegram отправьте:

/newbot

Следуйте инструкциям BotFather.

В конце вы получите API-токен вида:

123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Этот токен потребуется во время установки.

Telegram User ID

Установщик также запросит Telegram User ID администратора.

Именно этот пользователь получает права администратора в боте.

Конфигурация

Основной конфигурационный файл:

/opt/etc/telegram4kvas/telegram_bot_config.py

В нём хранятся, в частности:

token = 'TELEGRAM_BOT_TOKEN'
userid = [123456789]
version = 'v1.3'

Также конфигурация выбранного AWG-интерфейса находится здесь:

/opt/etc/telegram4kvas/telegram4kvas.conf

Пример:

TELEGRAM_AWG_INTERFACE="nwg3"

AWG-интерфейс

При установке скрипт автоматически ищет интерфейсы:

nwg*

Например:

nwg0
nwg1
nwg3

После этого установщик предложит выбрать нужный интерфейс.

Выбранный интерфейс сохраняется в:

/opt/etc/telegram4kvas/telegram4kvas.conf

Если необходимо изменить интерфейс:

/opt/etc/init.d/S98telegram4kvas interface

После выбора нового интерфейса бот необходимо перезапустить:

/opt/etc/init.d/S98telegram4kvas restart

Запуск

Запуск:

/opt/etc/init.d/S98telegram4kvas start

Остановка:

/opt/etc/init.d/S98telegram4kvas stop

Перезапуск:

/opt/etc/init.d/S98telegram4kvas restart

Проверка состояния:

/opt/etc/init.d/S98telegram4kvas status

Автоматический запуск

Бот запускается через:

/opt/etc/init.d/S98telegram4kvas

Скрипт используется Entware для управления сервисом.

После перезагрузки роутера telegram4kvas запускается автоматически.

Переподключение

Если интернет на роутере появляется не сразу после загрузки, бот может несколько раз пытаться подключиться к Telegram.

Параметры находятся в:

/opt/etc/telegram4kvas/telegram_bot_config.py

Основные параметры:

reconnection_timeout
reconnection_attempts

reconnection_timeout определяет задержку между попытками подключения.

reconnection_attempts определяет количество попыток подключения.

Обновление

Обновления распространяются через GitHub Releases:

https://github.com/piponomarev/telegram4kvas/releases

Установленный релиз сохраняется в конфигурации:

version = 'v1.3'

Для обновления используется:

/opt/upgrade.sh

Механизм проверки версии и обновления развивается отдельно от установочного скрипта. Если установленная версия совпадает с последним Release, обновление не требуется.

Удаление

Для удаления telegram4kvas используйте установочный скрипт из этого репозитория:

curl -OLf https://raw.githubusercontent.com/piponomarev/telegram4kvas/main/script/install.sh && sh install.sh -remove

Скрипт удаляет:

* telegram4kvas;
* конфигурацию бота;
* init-скрипт;
* updater;
* зависимости, установленные telegram4kvas.

Перед удалением рекомендуется сохранить файл конфигурации, если планируется повторная установка.

Проверка файлов

Основные файлы проекта:

telegram4kvas/
├── README.md
├── telegram_bot.py
├── telegram_bot_config.py
├── telebot/
├── S98telegram4kvas
├── upgrade.sh
└── script/
    └── install.sh

Назначение файлов

Файл	Назначение
telegram_bot.py	основной код Telegram-бота
telegram_bot_config.py	конфигурация
telebot/	зависимости Telegram Bot API
S98telegram4kvas	управление сервисом
script/install.sh	установка и удаление
upgrade.sh	обновление
README.md	документация

Пути на роутере

После установки:

/opt/etc/telegram4kvas/
├── telegram_bot.py
├── telegram_bot_config.py
├── telegram4kvas.conf
└── telebot/
/opt/etc/init.d/
└── S98telegram4kvas
/opt/
└── upgrade.sh

Проверка работы

Проверить состояние:

/opt/etc/init.d/S98telegram4kvas status

Проверить процесс:

ps w | grep telegram4kvas

Проверить AWG:

ip link show | grep nwg

Репозиторий

Исходный код проекта:

https://github.com/piponomarev/telegram4kvas

Релизы:

https://github.com/piponomarev/telegram4kvas/releases

Основа проекта

Проект основан на telegram4kvas для KVAS от qzeleza.

KVAS:

https://github.com/qzeleza/kvas
