#!/usr/bin/env bash

## Variables
# $NODE_NAME
# $RETRYIPS
# $SERVER
# $ACCESS_KEY_ID
# $SECRET_ACCESS_KEY
# $CLUSTER

# Set up basic consul settings
if [ ! -z "$NODE_NAME" ]
then
  NODE_NAME=$(cat /etc/hostname)
fi
sudo cat <<EOF >/etc/consul.d/basic_config.json
{
  "node_name": "${NODE_NAME}",
  "data_dir": "/opt/consul",
  "log_level": "DEBUG",
  "enable_debug": true
}
EOF

if [ "$SERVER" == "true" ]; then
  # setup server settings
  sudo cat <<EOF >/etc/consul.d/server.json
{
  "server": true,
  "bootstrap_expect": ${BOOTSTRAP}
}
EOF
else
  # setup client settings
  sudo cat <<EOF >/etc/consul.d/client.json
{
  "server": false
}
EOF
fi

# Populate other node's IPs to retry_join
if [ ! -z "$RETRYIPS"]; then
  sudo cat <<EOF >/etc/consul.d/retry_join.json
{
  "retry_join": ${RETRYIPS}
}
EOF
fi

# Use cloud join to find other nodes
if [ ! -z "$ACCESS_KEY_ID" ] && [ ! -z "$SECRET_ACCESS_KEY" ] && [ ! -z "$CLUSTER" ]
then
  sudo cat <<EOF >/etc/consul.d/cloud_join.hcl
retry_join = ["provider=aws tag_key=CLUSTER tag_value=${CLUSTER} access_key_id=${ACCESS_KEY_ID} secret_access_key=${SECRET_ACCESS_KEY}"]    
EOF
fi

# make sure everything is writeable by consul
sudo chown -R consul /etc/consul.d

# enable and start consul
sudo systemctl enable consul
sudo systemctl start consul

sleep 3s
