#!/usr/bin/env bash

# Variables:
# VAULT_VERSION

# get last OSS version if VAULT_VERSION not set
if [ ! "$VAULT_VERSION" ] ; then
  VAULT_VERSION=`curl -sL https://releases.hashicorp.com/vault/index.json | jq -r '.versions[].version' | sort -V | egrep -v 'ent|beta|rc|alpha' | tail -1`
fi

# Working directory
cd /tmp

which vault || {
  wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
  unzip vault_${VAULT_VERSION}_linux_amd64.zip
  sudo mv vault /usr/local/bin
  rm vault_${VAULT_VERSION}_linux_amd64.zip
}

# Set up config directory
sudo mkdir -p /etc/vault.d/
sudo chown -R vault /etc/vault.d

# Set up data directory
sudo mkdir -p /opt/vault
sudo chown -R vault /opt/vault

# Set up systemd vault service
cat <<EOF > vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo mv vault.service /etc/systemd/system/vault.service
systemctl daemon-reload
