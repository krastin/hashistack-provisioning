#!/usr/bin/env bash

PRODUCT=consul

# Working directory
cd /usr/local/bin

# get last OSS version if VERSION not set
if [ ! "$VERSION" ] ; then
  VERSION=`curl -sL https://releases.hashicorp.com/${PRODUCT}/index.json | jq -r '.versions[].version' | sort -V | egrep -v 'ent|beta|rc|alpha' | tail -1`
fi

if [[ $(uname -m) -eq "aarch64" ]]; then
  ARCH="arm64"
else
  ARCH="amd64"
fi

which ${PRODUCT} || {
  wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_${ARCH}.zip
  unzip ${PRODUCT}_${VERSION}_linux_${ARCH}.zip
  rm ${PRODUCT}_${VERSION}_linux_${ARCH}.zip
}

# Set up consul user
useradd -m consul 
echo "%consul ALL=NOPASSWD:ALL" > /etc/sudoers.d/consul
chmod 0440 /etc/sudoers.d/consul
usermod -a -G sudo consul

# Set up config directory
sudo mkdir -p /etc/consul.d/
sudo chown -R consul /etc/consul.d

# Set up data directory
sudo mkdir -p /opt/consul
sudo chown -R consul /opt/consul

# Set up systemd consul service
cat <<EOF > /etc/systemd/system/consul.service
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

# Set up basic consul settings
cat <<EOF > /etc/consul.d/basic_config.json
{
  "data_dir": "/opt/consul",
  "log_level": "DEBUG",
  "enable_debug": true
}
EOF
