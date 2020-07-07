#!/usr/bin/env bash

PRODUCT=consul

# get last OSS version if CONSUL_VERSION not set
if [ ! "$CONSUL_VERSION" ] ; then
  CONSUL_VERSION=`curl -sL https://releases.hashicorp.com/${PRODUCT}/index.json | jq -r '.versions[].version' | sort -V | egrep -v 'ent|beta|rc|alpha' | tail -1`
fi

# Working directory
cd /tmp

which ${PRODUCT} || {
  wget https://releases.hashicorp.com/${PRODUCT}/${CONSUL_VERSION}/${PRODUCT}_${CONSUL_VERSION}_linux_amd64.zip
  unzip ${PRODUCT}_${CONSUL_VERSION}_linux_amd64.zip
  sudo mv ${PRODUCT} /usr/local/bin
  rm ${PRODUCT}_${CONSUL_VERSION}_linux_amd64.zip
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
#ConditionFileNotEmpty=/etc/consul.d/consul.hcl

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
