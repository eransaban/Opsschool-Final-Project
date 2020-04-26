#!/usr/bin/env bash
set -e

promcol_version="2.16.0"
prometheus_conf_dir="/etc/prometheus"
prometheus_dir="/opt/prometheus"

### Install Prometheus Collector
wget https://github.com/prometheus/prometheus/releases/download/v${promcol_version}/prometheus-${promcol_version}.linux-amd64.tar.gz -O /tmp/promcoll.tgz
mkdir -p ${prometheus_dir}
tar zxf /tmp/promcoll.tgz -C ${prometheus_dir}

# Create promcol configuration
mkdir -p ${prometheus_conf_dir}
wget https://raw.githubusercontent.com/eransaban/protest/master/prometheus.yml
sudo mv prometheus.yml ${prometheus_conf_dir}/prometheus.yml

# Configure promcol service
tee /etc/systemd/system/promcol.service > /dev/null <<EOF
[Unit]
Description=Prometheus Collector
Requires=network-online.target
After=network.target

[Service]
ExecStart=${prometheus_dir}/prometheus-${promcol_version}.linux-amd64/prometheus --config.file=${prometheus_conf_dir}/prometheus.yml
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGINT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promcol.service
systemctl start promcol.service

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

### add promcol service to consul
tee /etc/consul.d/promcol-9090.json > /dev/null <<"EOF"
{
  "service": {
    "id": "promcol-9090",
    "name": "promcol",
    "tags": ["promcol"],
    "port": 9090,
    "checks": [
      {
        "id": "tcp",
        "name": "TCP on port 9090",
        "tcp": "localhost:9090",
        "interval": "10s",
        "timeout": "1s"
      }
    ]
  }
}
EOF

### add promcol service to consul
tee /etc/consul.d/grafana-3000.json > /dev/null <<"EOF"
{
  "service": {
    "id": "grafana-3000",
    "name": "grafana",
    "tags": ["grafana"],
    "port": 3000,
    "checks": [
      {
        "id": "tcp",
        "name": "TCP on port 3000",
        "tcp": "localhost:3000",
        "interval": "10s",
        "timeout": "1s"
      }
    ]
  }
}
EOF




systemctl daemon-reload
systemctl enable consul.service
systemctl start consul.service

#install Grafna
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/enterprise/deb stable main"

sudo apt-get update -y
sudo apt-get install grafana-enterprise -y

#Pull GRanafa Dashboard & Datasources

wget https://raw.githubusercontent.com/eransaban/opsschool-monitoring/master/compose/grafana/provisioning/datasource.yml
sudo mv ./datasource.yml /etc/grafana/provisioning/datasources/datasource.yml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/k8sprom.yaml
sudo mv ./k8sprom.yaml /etc/grafana/provisioning/datasources/k8sprom.yaml

mkdir /var/grafana_dash
wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/jenkins-dashboard.json
sudo mv ./jenkins-dashboard.json /var/grafana_dash/jenkins-dashboard.json

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/jenkins-dash.yml
sudo mv ./jenkins-dash.yml /etc/grafana/provisioning/dashboards/jenkins-dash.yml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/node-exporter.json
sudo mv ./node-exporter.json /var/grafana_dash/node-exporter.json

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/node_exporter.yml
sudo mv ./node_exporter.yml /etc/grafana/provisioning/dashboards/node_exporter.yml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/node_exporter_svc_names.json
sudo mv ./node_exporter_svc_names.json /var/grafana_dash/node_exporter_svc_names.json

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/node_exporter_names.yml
sudo mv ./node_exporter_names.yml /etc/grafana/provisioning/dashboards/node_exporter_names.yml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/mysql.json
sudo mv ./mysql.json /var/grafana_dash/mysql.json

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/mysql.yaml
sudo mv ./mysql.yaml /etc/grafana/provisioning/dashboards/mysql.yaml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/kubernetes_cluster.json
sudo mv ./kubernetes_cluster.json /var/grafana_dash/kubernetes_cluster.json

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/k8s.yaml
sudo mv ./k8s.yaml /etc/grafana/provisioning/dashboards/k8s.yaml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/PrometheusBlackbox.json
sudo mv ./PrometheusBlackbox.json /var/grafana_dash/PrometheusBlackbox.json

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/blackbox.yaml
sudo mv ./blackbox.yaml /etc/grafana/provisioning/dashboards/blackbox.yaml

wget https://raw.githubusercontent.com/eransaban/protest/master/Grafana%20Dashboard/notify.yaml
sudo mv ./notify.yaml /etc/grafana/provisioning/notifiers/notify.yaml

sudo systemctl daemon-reload
sudo systemctl enable grafana-server.service
sudo systemctl start grafana-server


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

#Install Black Box Exporter
#Create user
useradd --no-create-home --shell /bin/false blackbox_exporter

# Download blackbox
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.14.0/blackbox_exporter-0.14.0.linux-amd64.tar.gz
tar -xvf blackbox_exporter-0.14.0.linux-amd64.tar.gz
cp blackbox_exporter-0.14.0.linux-amd64/blackbox_exporter /usr/local/bin/blackbox_exporter
chown blackbox_exporter:blackbox_exporter /usr/local/bin/blackbox_exporter
rm -rf blackbox_exporter-0.14.0.linux-amd64*
mkdir /etc/blackbox_exporter

#Create Configuration File 
tee /etc/blackbox_exporter/blackbox.yml > /dev/null <<EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: []
      method: GET
EOF
chown blackbox_exporter:blackbox_exporter /etc/blackbox_exporter/blackbox.yml

#Create The Black Box Service
tee /etc/systemd/system/blackbox_exporter.service > /dev/null <<EOF
[Unit]
Description=Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox_exporter
Group=blackbox_exporter
Type=simple
ExecStart=/usr/local/bin/blackbox_exporter --config.file /etc/blackbox_exporter/blackbox.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start blackbox_exporter
systemctl enable blackbox_exporter


#install Beats
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.6.2-amd64.deb
sudo dpkg -i filebeat-7.6.2-amd64.deb


rm -f /etc/filebeat/filebeat.yml

cd /home/ubuntu
wget https://raw.githubusercontent.com/eransaban/docker-elk/master/filebeat/filebeat.yml
mv ./filebeat.yml /etc/filebeat/filebeat.yml -f

systemctl start filebeat
systemctl enable filebeat


sudo systemctl restart grafana-server
consul reload
