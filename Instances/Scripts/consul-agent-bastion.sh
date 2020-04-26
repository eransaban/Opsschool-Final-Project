#!/usr/bin/env bash
set -e

### set Node Exporter Version
PROMETHEUS_DIR="/opt/prometheus"
NODE_EXPORTER_VERSION="0.18.1"


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

systemctl daemon-reload
systemctl enable consul.service
systemctl start consul.service

apt-get update -y
apt install nginx -y
systemctl start nginx
systemctl enable nginx


#Create SSL 
mkdir -p /root/certs
openssl req -x509 -newkey rsa:4096 -nodes -keyout /root/certs/saban.co.il.key -out /root/certs/saban.co.il.crt -subj "/C=IL/ST=Israel/L=Ashkelon/O=Saban/OU=DEVOPS/CN=saban.co.il"

#install Consul Template
wget https://releases.hashicorp.com/consul-template/0.20.0/consul-template_0.20.0_linux_amd64.zip
unzip consul-template_0.20.0_linux_amd64.zip
sudo cp ./consul-template /usr/local/bin

#Create Consul Tempalte

mkdir -p /var/consul-template-file
sudo tee /var/consul-template-file/consul-template-config.hcl > /dev/null <<EOF
consul {
address = "localhost:8500"
retry {
enabled = true
attempts = 12
backoff = "250ms"
}
}
template {
source      = "/etc/nginx/conf.d/load-balancer.conf.ctmpl"
destination = "/etc/nginx/conf.d/load-balancer.conf"
perms = 0600
command = "service nginx reload"
}
EOF

#Create Consul Input file
sudo tee /etc/nginx/conf.d/load-balancer.conf.ctmpl > /dev/null <<EOF
upstream jenkins {
{{ range service "jenkins-webserver" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}
}

server {
   listen 8080 ssl;
   server_name         saban.co.il;
   ssl_certificate     /root/certs/saban.co.il.crt;
   ssl_certificate_key /root/certs/saban.co.il.key;


   location / {
      proxy_pass http://jenkins;
   }
}

upstream consul {
{{ range service "consul" }}
  server {{ .Address }}:8500;
{{ end }}
}

server {
   listen 8888 ssl;
   server_name         saban.co.il;
   ssl_certificate     /root/certs/saban.co.il.crt;
   ssl_certificate_key /root/certs/saban.co.il.key;

   location / {
      proxy_pass http://consul;
   }
}

upstream elk {
{{ range service "elk" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}
}

server {
   listen 5601 ssl;
   server_name         saban.co.il;
   ssl_certificate     /root/certs/saban.co.il.crt;
   ssl_certificate_key /root/certs/saban.co.il.key;

   location / {
      proxy_pass http://elk;
   }
}

upstream grafana {
{{ range service "grafana" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}
}

server {
   listen 3000 ssl;
   server_name         saban.co.il;
   ssl_certificate     /root/certs/saban.co.il.crt;
   ssl_certificate_key /root/certs/saban.co.il.key;

   location / {
      proxy_pass http://grafana;
   }
}

upstream promcol {
{{ range service "promcol" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}
}

server {
   listen 9090 ssl;
   server_name         saban.co.il;
   ssl_certificate     /root/certs/saban.co.il.crt;
   ssl_certificate_key /root/certs/saban.co.il.key;

   location / {
      proxy_pass http://promcol;
   }
}
EOF

service nginx reload
#tmux new-session -d -s consul_template 'consul-template -config=/var/consul-template-file/consul-template-config.hcl;'

# Configure Consule Template Service
tee /etc/systemd/system/consul_template.service > /dev/null <<EOF
[Unit]
Description=Consul Template
Requires=network-online.target nginx.service
After=network.target nginx.service

[Service]
Restart=always
RestartSec=30
ExecStart=/usr/local/bin/consul-template -config=/var/consul-template-file
KillSignal=SIGINT
TimeoutStopSec=5


[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
sudo systemctl enable consul_template.service
sudo systemctl start consul_template.service


#install Beats
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.6.2-amd64.deb
sudo dpkg -i filebeat-7.6.2-amd64.deb


rm -f /etc/filebeat/filebeat.yml

cd /home/ubuntu
wget https://raw.githubusercontent.com/eransaban/docker-elk/master/filebeat/filebeat.yml
mv ./filebeat.yml /etc/filebeat/filebeat.yml -f

systemctl start filebeat
systemctl enable filebeat

sleep 30
sudo systemctl start consul_template.service
consul reload