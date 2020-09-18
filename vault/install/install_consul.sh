#!/usr/bin/env bash

# Variables:
# VAULT_VERSION

# get last OSS version if CONSUL_VERSION not set
if [ ! "$CONSUL_VERSION" ] ; then
  CONSUL_VERSION=`curl -sL https://releases.hashicorp.com/consul/index.json | jq -r '.versions[].version' | sort -V | egrep -v 'ent|beta|rc|alpha' | tail -1`
fi

# Working directory
cd /tmp

which consul || {
  wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
  unzip consul_${CONSUL_VERSION}_linux_amd64.zip
  sudo mv consul /usr/local/bin
  rm consul_${CONSUL_VERSION}_linux_amd64.zip
}

# Set up config directory
sudo mkdir -p /etc/consul.d/
sudo chown -R consul /etc/consul.d

# Set up data directory
sudo mkdir -p /opt/consul
sudo chown -R consul /opt/consul

# Set up systemd consul service
cat <<EOF > consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/consul.d/

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo mv consul.service /etc/systemd/system/consul.service
systemctl daemon-reload
