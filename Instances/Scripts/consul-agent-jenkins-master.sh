#!/usr/bin/env bash
set -e

#sleep 30
sudo apt-get update -y
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
mkdir -p /home/ubuntu/jenkins_home
sudo chown -R 1000:1000 /home/ubuntu/jenkins_home

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
#apt-get -qq install apache2

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
  {"name": "jenkins-webserver",
    "tags": ["jenkins-webserver"],
    "port": 8080,
    "check": {
      "args": ["curl", "localhost:8080"],
      "interval": "10s"
    }
  }
}' > /etc/consul.d/webserver.json



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

systemctl start filebeat
systemctl enable filebeat

consul reload