#!/bin/bash
DESC="Zabbix network monitor"

DBTYPE="MySQL"
MYSQLINSTALLED="mysql-server"
MYSQL_ROOT_PASSWORD="BalticMysqlAdmin1#"
ZABBIXLINSTALLED="zabbix-server"
ZABBIX_MYSQL_PASSWORD="Zabbixpswd1#"

INSTALL_PARAM=$1

# root permission check
check_root_perms() {
    [ $(id -ru) != 0 ] && { echo "You must be root to install the ${DESC}. Exit." 1>&2; exit 1; }
}

# user confirm
user_confirm() {
    if [ "$INSTALL_PARAM" == "-y" -o "$INSTALL_PARAM" == "-Y" ]; then
        return 0
    fi

    while true
    do
        echo -n "${DESC} will be installed with [${DBTYPE}] (y/n): "
        read input
        confirm=`echo $input | tr '[a-z]' '[A-Z]'`

        if [ "$confirm" == "Y" -o "$confirm" == "YES" ]; then
             return 0
        elif [ "$confirm" == "N" -o "$confirm" == "NO" ]; then
             return 1
        fi
    done
}

#root permissions check
check_root_perms

if ! user_confirm ; then
    exit
fi

echo "========================="
echo "Installing MySQL Server CE....."

# Update package lists
sudo apt update

# Setup MySQL

## Install MySQL server
sudo apt install -y mysql-server

echo "========================="

if ! dpkg -s "$MYSQLINSTALLED" >/dev/null 2>&1; then
    echo "MySQL install failed. Unable to continue"
    exit
else
    echo "Setting up and securing MySQL Server..."

    ## Configure debconf to run in non-interactive mode
    export DEBIAN_FRONTEND=noninteractive

    ## Set the root password without user interaction
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
    sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

    ## Secure MySQL installation
    sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='';"
    sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE IF EXISTS test;"
    sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
fi

# Install Zabbix repository configuration package
echo "========================="
echo "Installing Zabbix....."

#sudo apt install -y wget
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
sudo apt update

# Install Zabbix server, frontend, agent
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent zabbix-sql-scripts

# Create Zabbix database
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE zabbix character set utf8 collate utf8_bin;"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'Zabbixpswd1#';"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost' WITH GRANT OPTION;"
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Import initial schema and data
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p$ZABBIX_MYSQL_PASSWORD zabbix
sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Configure Zabbix server
sudo sed -i 's/# DBPassword=/DBPassword=Zabbixpswd1#/g' /etc/zabbix/zabbix_server.conf

# Restart Zabbix server and agent
sudo systemctl restart zabbix-server zabbix-agent apache2

if ! dpkg -s "$ZABBIXLINSTALLED" >/dev/null 2>&1; then
    echo "Zabbix install failed. Unable to continue"
    exit
else
    # Enable services to start on boot
    sudo systemctl enable zabbix-server zabbix-agent apache2
    echo "${DESC} installation succeeded and will start at system boot"
    exit
fi