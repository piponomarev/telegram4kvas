#!/bin/sh

bot_path="/opt/etc/telegram4kvas/telegram_bot.py"
config_path="/opt/etc/telegram4kvas/telegram_bot_config.py"
init_path="/opt/etc/init.d/S98telegram4kvas"

release_url=https://api.github.com/repos/piponomarev/telegram4kvas/releases
latest_version=$(curl -sH "Accept: application/vnd.github.v3+json" ${release_url}/latest | grep tag_name | awk -F\" '{print $4}')
package_url=$(curl -sH "Accept: application/vnd.github.v3+json" ${release_url}/latest | sed -n 's/.*browser_download_url\": "\(.*\)\"/\1/p;' | tr -d ' ' | sed '/^$/d')

/opt/etc/init.d/S98telegram4kvas stop

rm $bot_path

curl -JLo $bot_path $package_url

curl -fsSL -o $init_path https://raw.githubusercontent.com/piponomarev/telegram4kvas/main/S98telegram4kvas
chmod +x $init_path

if ! grep -q "reconnection_timeout" $config_path; then
  echo "reconnection_timeout = 60" >> $config_path
fi

if ! grep -q "reconnection_attempts" $config_path; then
  echo "reconnection_attempts = 5" >> $config_path
fi

sed -i '/version/d' $config_path
echo "version = '$latest_version'" >> $config_path

logger -s -t telegram4kvas 'Бот обновлен'

/opt/etc/init.d/S98telegram4kvas restart
