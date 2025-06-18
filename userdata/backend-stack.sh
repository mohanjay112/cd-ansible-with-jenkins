#!/bin/bash
set -ex

DATABASE_PASS='admin123'

# Update system and install basic tools
dnf update -y
dnf install -y epel-release
dnf install -y wget git unzip curl socat

# Install MariaDB (MySQL)
dnf install -y mariadb-server

# Configure MariaDB to listen on all IPs
sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/my.cnf.d/mariadb-server.cnf || true

# Start and enable MariaDB
systemctl enable --now mariadb

# Set root password and secure installation
mysqladmin -u root password "$DATABASE_PASS"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"$DATABASE_PASS" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES;"
mysql -u root -p"$DATABASE_PASS" -e "CREATE DATABASE accounts;"
mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL ON accounts.* TO 'admin'@'%' IDENTIFIED BY 'admin123';"
mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES;"

# Import application database
cd /tmp/
wget https://raw.githubusercontent.com/devopshydclub/vprofile-repo/vp-rem/src/main/resources/db_backup.sql
mysql -u root -p"$DATABASE_PASS" accounts < /tmp/db_backup.sql

# Install Memcached
dnf install -y memcached
systemctl enable --now memcached
memcached -p 11211 -U 11111 -u memcached -d

# Install RabbitMQ
# 1. Add Erlang
dnf install -y https://github.com/rabbitmq/erlang-rpm/releases/download/v26.2.1/erlang-26.2.1-1.el9.x86_64.rpm

# 2. Add RabbitMQ repository
cat > /etc/yum.repos.d/rabbitmq.repo << EOF
[rabbitmq-server]
name=RabbitMQ Server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/9/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
EOF

dnf update -y
dnf install -y rabbitmq-server

# Enable and start RabbitMQ
systemctl enable --now rabbitmq-server

# Allow remote connections and create test user
echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config
rabbitmqctl add_user test test
rabbitmqctl set_user_tags test administrator
systemctl restart rabbitmq-server
