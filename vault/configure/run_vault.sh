#!/usr/bin/env bash

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