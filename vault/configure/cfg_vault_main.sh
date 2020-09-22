#!/usr/bin/env bash

##Variables
# AWS_REGION
# KMS_KEY

sudo chown -R vault /etc/vault.d

cat <<EOF >/etc/vault.d/vault.hcl
disable_mlock = true
ui = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
EOF

# Get and configure the local IP
local_ip=$(ip add | grep "inet " | grep -v '127.0.0.1' | awk '{ print $2 }' | awk -F'/' '{ print $1 }' | tail -n1)
if [ ! -z "$local_ip" ]
then
  echo Configuring Vault HA node address as $local_ip
  cat <<EOF >/etc/vault.d/addr.hcl
cluster_addr = "https://${local_ip}:8201"
api_addr = "http://${local_ip}:8200"
EOF
fi

if [ ! -z "$AWS_REGION" ] && [ ! -z "$KMS_KEY" ]
then
  echo Configuring Vault AWS KMS seal settings
  cat <<EOF >/etc/vault.d/awskms.hcl
seal "awskms" {
  region     = "${AWS_REGION}"
  kms_key_id = "${KMS_KEY}"
}

EOF
fi

echo Configuring Vault ENV vars
cat <<EOF | sudo tee /etc/profile.d/vault.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
EOF

sudo systemctl enable vault
