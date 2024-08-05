#!/bin/bash

# Update package lists
echo "Refreshing cache"
sudo apt update
# Setup MySQL

## Install MySQL server
echo "Installing MySQL Server"
sudo apt install -y mysql-server

## Set MySQL root password
echo "Setting the MySQL root password"
MYSQL_ROOT_PASSWORD="BalticMysqlAdmin1#"

## Configure debconf to run in non-interactive mode
export DEBIAN_FRONTEND=noninteractive

## Set the root password without user interaction
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

## Secure MySQL installation
echo "Securing MySQL"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS test;"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

# Install Zabbix repository configuration package
#sudo apt install -y wget
echo "Adding the Zabbix Repo"
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_7.0-2+ubuntu22.04_all.deb
sudo apt update

# Install Zabbix server, frontend, agent
echo "Installing Zabbix"
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Create Zabbix database
echo "Creating the Zabbix database and user"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE zabbix character set utf8 collate utf8_bin;"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER zabbix@localhost IDENTIFIED BY 'Zabbixpswd1#';"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON zabbix.* TO zabbix@localhost WITH GRANT OPTION;"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Import initial schema and data
## Set Zabbix MySQL password
echo "Importing the Zabbix schema"
ZABBIX_MYSQL_PASSWORD="Zabbixpswd1#"
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p$ZABBIX_MYSQL_PASSWORD zabbix
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Configure Zabbix server
echo "Configuting the Zabbis server"
sudo sed -i 's/# DBPassword=/DBPassword=Zabbixpswd1#/g' /etc/zabbix/zabbix_server.conf

# Restart Zabbix server and agent
sudo systemctl restart zabbix-server zabbix-agent apache2

# Enable services to start on boot
sudo systemctl enable zabbix-server zabbix-agent apache2
echo "Zabbix installed"
