#!/bin/bash

# Become the root user
#sudo -s

# Update package lists
echo "Refreshing cache"
apt update
# Setup MySQL

## Install MySQL server
echo "Installing MySQL Server"
apt install -y mysql-server

## Set MySQL root password
echo "Setting the MySQL root password"
MYSQL_ROOT_PASSWORD="BalticMysqlAdmin1#"

## Configure debconf to run in non-interactive mode
export DEBIAN_FRONTEND=noninteractive

## Set the root password without user interaction
debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

## Secure MySQL installation
echo "Securing MySQL"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS test;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

# Install Zabbix repository configuration package
#sudo apt install -y wget
echo "Adding the Zabbix Repo"
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu22.04_all.deb
dpkg -i zabbix-release_7.0-2+ubuntu22.04_all.deb
apt update

# Install Zabbix server, frontend, agent
echo "Installing Zabbix"
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Create Zabbix database
echo "Creating the Zabbix database and user"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE zabbix character set utf8 collate utf8_bin;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER zabbix@localhost IDENTIFIED BY 'Zabbixpswd1#';"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON zabbix.* TO zabbix@localhost WITH GRANT OPTION;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Import initial schema and data
## Set Zabbix MySQL password
echo "Importing the Zabbix schema this will take a couple of mins."
ZABBIX_MYSQL_PASSWORD="Zabbixpswd1#"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p$ZABBIX_MYSQL_PASSWORD zabbix
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Configure Zabbix server
echo "Configuting the Zabbis server"
sed -i 's/# DBPassword=/DBPassword=Zabbixpswd1#/g' /etc/zabbix/zabbix_server.conf

# Restart Zabbix server and agent
systemctl restart zabbix-server zabbix-agent apache2

# Enable services to start on boot
systemctl enable zabbix-server zabbix-agent apache2
echo "Zabbix installed"

# Exit root user
echo "Exiting root user"
exit