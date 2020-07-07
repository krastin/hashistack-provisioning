#!/usr/bin/env bash

##Variables
# AWS_REGION
# KMS_KEY
# VAULT_LICENSE
# CONSUL_TOKEN

sudo chown -R vault /etc/vault.d

cat <<EOF >/etc/vault.d/vault.hcl
disable_mlock = true
ui = true

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault"
  #token   = "${CONSUL_TOKEN}
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
EOF

# If consul token was not empty, remove the comment as to use it
if [ ! -z "$CONSUL_TOKEN" ]; then
  sed -i 's/#token/token/' /etc/vault.d/vault.hcl
fi

# Get and configure the local IP
local_ip=$(ip add | grep "inet " | grep -v '127.0.0.1' | awk '{ print $2 }' | awk -F'/' '{ print $1 }')
if [ ! -z "$local_ip" ]
then
  echo Configuring Vault HA node address as $local_ip
  cat <<EOF >>/etc/vault.d/vault.hcl
cluster_addr = "https://${local_ip}:8201"
api_addr = "http://${local_ip}:8200"
EOF
fi

if [ ! -z "$AWS_REGION" ] && [ ! -z "$KMS_KEY" ]
then
  echo Configuring Vault AWS KMS seal settings
  cat <<EOF >>/etc/vault.d/vault.hcl
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
sudo systemctl start vault

sleep 5s

# wait up to a minute until Vault is listening on its port
for i in $(seq 1 6)
do 
  sleep 10 # wait 10 seconds
  is_leader=$(netstat -ltpn | grep 0.0.0.0:8200 | grep -c LISTEN)
  if [ $is_leader != "1" ]; then
    break
  fi
done

echo "Checking if Vault is initialized:"
vault_initialized=$(VAULT_ADDR=http://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault status | grep Initialized | awk '{ print $NF }')
if [ "$vault_initialized" == "false" ]
then
  echo Vault is not initialized: init now...
  VAULT_ADDR=http://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator init -recovery-shares=1 -recovery-threshold=1 > ~/recovery_key.txt || {
    echo Error initializing Vault!
  }
  if [ ! -z "$VAULT_LICENSE" ]; then
    sleep 10s
    vault_token=$(cat ~/recovery_key.txt | grep 'Initial Root Token: ' | awk '{ print $NF }')
    VAULT_ADDR=http://127.0.0.1:8200 VAULT_SKIP_VERIFY=true VAULT_TOKEN=$vault_token vault write sys/license text=${VAULT_LICENSE} || echo Failed to write license - probably another node did that already
  fi
elif [ "$vault_initialized" == "true" ]
then
  echo Vault is already initialized: doing nothing...
else
  echo Error: could not contact Vault to check for initialization!
fi