#!/usr/bin/env bash

##Variables
# VAULT_LICENSE
#

# TODO - this procedure for use when using Consul backend - need to add Raft backend too

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
  # this line is for both AWS KMS and regular unseal
  VAULT_ADDR=http://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator init -recovery-shares=1 -recovery-threshold=1 -key-shares=1 -key-threshold=1 > ~/recovery_key.txt || {
    echo Error initializing Vault!
  }
  # unsealing from ~/recovery_key.txt if NOT using AWS KMS
  is_unsealed=$(vault status | grep -c -e 'Sealed \+false')
  if [ $is_unsealed != "1" ]; then
    echo Unsealing now
    unseal_key=$(grep 'Key 1:' ~/recovery_key.txt | awk '{print $NF}')
    VAULT_ADDR=http://127.0.0.1:8200 VAULT_SKIP_VERIFY=true vault operator unseal $unseal_key
  fi
  is_enterprise=$(vault version | grep -c ent)
  if [ ! -z "$VAULT_LICENSE" ] && [ ! -z "$is_enterprise" ]; then
    sleep 10s
    vault_token=$(cat ~/recovery_key.txt | grep 'Initial Root Token: ' | awk '{ print $NF }')
    VAULT_ADDR=http://127.0.0.1:8200 VAULT_SKIP_VERIFY=true VAULT_TOKEN=$vault_token vault write sys/license text=${VAULT_LICENSE} || echo Failed to write license
  fi
elif [ "$vault_initialized" == "true" ]
then
  echo Vault is already initialized: doing nothing...
else
  echo Error: could not contact Vault to check for initialization!
fi