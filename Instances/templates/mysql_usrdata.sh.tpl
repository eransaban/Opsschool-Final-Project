#!/usr/bin/env bash
set -e

### set consul version
CONSUL_VERSION="1.6.2"
### set Node Exporter Version
PROMETHEUS_DIR="/opt/prometheus"
NODE_EXPORTER_VERSION="0.18.1"

echo "Grabbing IPs..."
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Installing dependencies..."
apt-get -qq update &>/dev/null
apt-get -yqq install unzip dnsmasq &>/dev/null

echo "Configuring dnsmasq..."
cat << EODMCF >/etc/dnsmasq.d/10-consul
# Enable forward lookup of the 'consul' domain:
server=/consul/127.0.0.1#8600
EODMCF
echo "Change Systemd-Resolved to Allow Ping and host"
cat << EODMCF >>/etc/systemd/resolved.conf
# Enable Systemd-Resolved find local domains:
DNS=127.0.0.1
Domains=~consul
EODMCF

systemctl restart dnsmasq
systemctl restart systemd-resolved

echo "Fetching Consul..."
cd /tmp
curl -sLo consul.zip https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

echo "Installing Consul..."
unzip consul.zip >/dev/null
chmod +x consul
mv consul /usr/local/bin/consul

# Setup Consul
mkdir -p /opt/consul
mkdir -p /etc/consul.d
mkdir -p /run/consul
tee /etc/consul.d/config.json > /dev/null <<EOF
{
  "advertise_addr": "$PRIVATE_IP",
  "data_dir": "/opt/consul",
  "datacenter": "saban",
  "encrypt": "uDBV4e+LbFW3019YKPxIrg==",
  "disable_remote_exec": true,
  "disable_update_check": true,
  "leave_on_terminate": true,
  "retry_join": ["provider=aws tag_key=consul_server tag_value=true"],
  "enable_script_checks": true,
  "server": false
  }
EOF

# Create user & grant ownership of folders
useradd consul
chown -R consul:consul /opt/consul /etc/consul.d /run/consul


# Configure consul service
tee /etc/systemd/system/consul.service > /dev/null <<"EOF"
[Unit]
Description=Consul service discovery agent
Requires=network-online.target
After=network.target

[Service]
User=consul
Group=consul
PIDFile=/run/consul/consul.pid
Restart=on-failure
Environment=GOMAXPROCS=2
#ExecStartPre=[ -f "/run/consul/consul.pid" ] && /usr/bin/rm -f /run/consul/consul.pid
ExecStart=/usr/local/bin/consul agent -pid-file=/run/consul/consul.pid -config-dir=/etc/consul.d
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGINT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF


#configure service and health check 
echo '{"service":
  {"name": "mysql",
    "tags": ["mysql"],
    "port": 3306,
    "checks": [
      {
        "id": "tcp",
        "name": "TCP on port 3306",
        "tcp": "localhost:3306",
        "interval": "10s",
        "timeout": "1s"
      }
    ]
    }
}' > /etc/consul.d/mysql.json



systemctl daemon-reload
systemctl enable consul.service
systemctl start consul.service

### Install Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz -O /tmp/node_exporter.tgz
mkdir -p ${PROMETHEUS_DIR}
tar zxf /tmp/node_exporter.tgz -C ${PROMETHEUS_DIR}

# Configure node exporter service
tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus node exporter
Requires=network-online.target
After=network.target

[Service]
ExecStart=${PROMETHEUS_DIR}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter
KillSignal=SIGINT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter.service
systemctl start node_exporter.service

#install Beats
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.6.2-amd64.deb
sudo dpkg -i filebeat-7.6.2-amd64.deb


rm -f /etc/filebeat/filebeat.yml

cd /home/ubuntu
wget https://raw.githubusercontent.com/eransaban/docker-elk/master/filebeat/filebeat.yml
mv ./filebeat.yml /etc/filebeat/filebeat.yml -f

#install Mysql 
sudo apt-get update
sudo apt-get install mysql-server -y
sudo apt-get install default-libmysqlclient-dev -y
sudo sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo mysql -e "CREATE DATABASE prac;"
sudo mysql -e "SET PASSWORD FOR root@localhost = PASSWORD('${sqlpassword}');FLUSH PRIVILEGES;"
#sudo mysql -e "GRANT ALL PRIVILEGES ON root.*	TO 'sqluser'@'localhost' IDENTIFIED BY '${sqlpassword}' WITH GRANT OPTION;"
sudo mysql -e "USE prac;  CREATE TABLE info (
 time_added TIMESTAMP DEFAULT NOW() , 
 name VARCHAR(30) , email VARCHAR(50) , 
 suggestion VARCHAR(500));"
 sudo mysql -e "CREATE USER '${sqluser}'@'localhost' IDENTIFIED BY '${sqlpassword}';
GRANT ALL PRIVILEGES ON *.* TO '${sqluser}'@'localhost' WITH GRANT OPTION;
CREATE USER 'eks'@'%' IDENTIFIED BY '${sqlpassword}';
GRANT ALL PRIVILEGES ON *.* TO '${sqluser}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;"
 sudo mysql -e "CREATE USER 'slave'@'localhost' IDENTIFIED BY '${sqlpassword}';
GRANT ALL PRIVILEGES ON *.* TO 'slave'@'localhost' WITH GRANT OPTION;
CREATE USER 'slave'@'%' IDENTIFIED BY '${sqlpassword}';
GRANT ALL PRIVILEGES ON *.* TO 'slave'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;"
systemctl restart node_exporter.service


#Give Exporter Permission
sudo mysql -e "CREATE USER 'exporter'@'localhost' IDENTIFIED BY '${sqlpassword}' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';FLUSH PRIVILEGES;"

#install Mysql Exporter
#VER=0.12.1
wget https://github.com/prometheus/mysqld_exporter/releases/download/v${VER}/mysqld_exporter-${VER}.linux-amd64.tar.gz
tar xvf mysqld_exporter-${VER}.linux-amd64.tar.gz
sudo mv  mysqld_exporter-${VER}.linux-amd64/mysqld_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/mysqld_exporter
rm -rf mysqld_exporter-${VER}.linux-amd64
rm mysqld_exporter-${VER}.linux-amd64.tar.gz

#Set Exporter permssion
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus

#Create database credentials file
tee /etc/.mysqld_exporter.cnf > /dev/null <<EOF

[client]
user=exporter
EOF
echo password=${sqlpassword} | tee -a /etc/.mysqld_exporter.cnf

sudo chown root:prometheus /etc/.mysqld_exporter.cnf

#create service
tee /etc/systemd/system/mysql_exporter.service  > /dev/null <<EOF
[Unit]
Description=Prometheus MySQL Exporter
After=network.target
User=prometheus
Group=prometheus

[Service]
Type=simple
Restart=always
ExecStart=/usr/local/bin/mysqld_exporter \
--config.my-cnf /etc/.mysqld_exporter.cnf \
--collect.global_status \
--collect.info_schema.innodb_metrics \
--collect.auto_increment.columns \
--collect.info_schema.processlist \
--collect.binlog_size \
--collect.info_schema.tablestats \
--collect.global_variables \
--collect.info_schema.query_response_time \
--collect.info_schema.userstats \
--collect.info_schema.tables \
--collect.perf_schema.tablelocks \
--collect.perf_schema.file_events \
--collect.perf_schema.eventswaits \
--collect.perf_schema.indexiowaits \
--collect.perf_schema.tableiowaits \
--collect.slave_status \
--web.listen-address=0.0.0.0:9104

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mysql_exporter
sudo systemctl start mysql_exporter

#start replication proccess
#instal s3cmd
sudo apt install awscli -y

#Uncommecnt lines in cnf
sudo sed -i '/^#.*server-id/s/^#//' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^#.*log_bin/s/^#//' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^#.*binlog_do_db/s/^#//' /etc/mysql/mysql.conf.d/mysqld.cnf
#change DBname
sudo sed -i '/binlog_do_db/s/include_database_name/prac/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
sleep 5
#create permission for slave and start lock 
sudo mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'slave'@'%' IDENTIFIED BY '${sqlpassword}';FLUSH PRIVILEGES;"
sudo mysql -e "USE prac;FLUSH TABLES WITH READ LOCK;"
sudo mysql -e "SHOW MASTER STATUS;" > /tmp/masterstatus.txt
tmux new-session -d -s dump 'mysqldump -ueks -p'${sqlpassword}' --opt prac > /tmp/prac.sql'
sleep 20
sudo mysql -e "USE prac;UNLOCK TABLES;"
#export data
sudo cat /tmp/masterstatus.txt |tail -n 1| cut -f 2 > /tmp/repcount.txt
sudo mkdir /tmp/replica
hostname --ip-address | sudo tee -a /tmp/replica/ip.txt
sudo mv /tmp/repcount.txt /tmp/replica/repcount.txt
sudo mv /tmp/prac*.sql /tmp/replica/
aws s3 cp /tmp/replica s3://saban-sql-backup/replication --recursive

consul reload