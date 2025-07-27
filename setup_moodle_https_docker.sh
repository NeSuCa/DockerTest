#!/bin/bash

# 1. 必要パッケージのインストール
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl unzip openssl git docker.io docker-compose

# 2. 作業ディレクトリの作成
sudo mkdir -p /opt/moodle-docker/nginx/ssl /opt/moodle-docker/moodle
cd /opt/moodle-docker

# 3. Moodle最新版のダウンロードと展開
wget https://download.moodle.org/latest.zip -O moodle.zip
unzip moodle.zip -d moodle-tmp
sudo mv moodle-tmp/moodle/* ./moodle/
sudo rm -rf moodle.zip moodle-tmp

# 4. SSL証明書の作成（自己署名）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/server.key \
  -out nginx/ssl/server.crt \
  -subj "/CN=localhost"

# 5. docker-compose.yml 作成
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.9'

services:
  mariadb:
    image: mariadb:10.6
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: moodlepass
      MYSQL_DATABASE: moodle
      MYSQL_USER: moodleuser
      MYSQL_PASSWORD: moodlepass
    volumes:
      - mariadb_data:/var/lib/mysql

  moodle:
    image: moodlehq/moodle-php-apache:8.3
    restart: unless-stopped
    environment:
      MOODLE_DBTYPE: mariadb
      MOODLE_DBHOST: mariadb
      MOODLE_DBNAME: moodle
      MOODLE_DBUSER: moodleuser
      MOODLE_DBPASS: moodlepass
    volumes:
      - ./moodle:/var/www/html
    depends_on:
      - mariadb

  nginx:
    image: nginx:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - moodle

volumes:
  mariadb_data:
EOF

# 6. Nginxリバースプロキシ設定
sudo tee nginx/default.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name localhost;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass http://moodle:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

# 7. Moodleデータディレクトリ作成（moodledata）
sudo mkdir -p /opt/moodle-docker/moodledata
sudo chown -R 33:33 /opt/moodle-docker/moodledata  # www-data uid/gid
echo "moodledata will be configured manually through browser setup."

# 8. Docker起動
sudo docker compose up -d

# 9. 完了メッセージ
echo "✅ Moodle + Docker + HTTPS セットアップ完了！"
echo "🔗 ブラウザで https://localhost にアクセスして、Moodle初期設定を完了してください。"
